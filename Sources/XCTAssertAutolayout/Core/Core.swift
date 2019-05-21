//
//  Core.swift
//  XCTAssertNoAmbiguousLayout
//
//  Created by tarunon on 2019/04/28.
//  Copyright © 2019 tarunon. All rights reserved.
//

import UIKit

struct Node {
    var viewClass: AnyClass
    var children: [Node]
    var hasAmbiguousLayout: Bool
    
    struct AssertMessage: CustomStringConvertible {
        var head: String
        var body: [AssertMessage]
        
        var descriptions: [String] {
            if body.isEmpty {
                return [head]
            }
            let headDesc = [head]
            let bodyDesc = body.dropLast().flatMap { assertMessage -> [String] in
                let descs = assertMessage.descriptions
                let headDesc = descs.first.map { "┣" + $0 }
                let bodyDesc = descs.dropFirst().map { "┃" + $0 }
                return [headDesc!] + bodyDesc
            }
            let bodyLastDesc = body.last.map { assertMessage -> [String] in
                let descs = assertMessage.descriptions
                let headDesc = descs.first.map { "┗" + $0 }
                let bodyDesc = descs.dropFirst().map { "  " + $0 }
                return [headDesc!] + bodyDesc
            }
            return headDesc + bodyDesc + bodyLastDesc!
        }
        
        var description: String {
            return descriptions.joined(separator: "\n")
        }
    }
    
    func numberOfAmbiguous() -> Int {
        return children.map { $0.numberOfAmbiguous() }.reduce(hasAmbiguousLayout ? 1 : 0) { $0 + $1 }
    }
    
    func assertMessages() -> AssertMessage {
        let head = "\(viewClass) \(hasAmbiguousLayout ? "[✘]" : "")"
        return AssertMessage(head: head, body: children.map { $0.assertMessages() })
    }
}

@_silgen_name("UIViewAlertForUnsatisfiableConstraints")
func originalUIViewAlertForUnsatisfiableConstraints(_ constraint: NSLayoutConstraint, _ allConstraints: NSArray)
let UIViewAlertForUnsatisfiableConstraints = "UIViewAlertForUnsatisfiableConstraints"

var _catchAutolayoutError: ((NSLayoutConstraint) -> ())?

func hookedUIViewAlertForUnsatisfiableConstraints(_ constraint: NSLayoutConstraint, _ allConstraints: NSArray) {
    _catchAutolayoutError?(constraint)
    CFunctionInjector.reset(UIViewAlertForUnsatisfiableConstraints)
    originalUIViewAlertForUnsatisfiableConstraints(constraint, allConstraints)
    withUnsafePointer(to: hookedUIViewAlertForUnsatisfiableConstraints) { (pointer) in
        CFunctionInjector.inject(UIViewAlertForUnsatisfiableConstraints, pointer)
    }
}

class AssertAutolayoutContext {
    private let _assert: (String) -> ()
    private var ambiguousCount = 0
    private var assertMessages = [String]()
    private var errorViews: [UIView] = []
    
    init(assert: @escaping (String, StaticString, UInt) -> (), file: StaticString, line: UInt) {
        _assert = { assert($0, file, line) }
        _catchAutolayoutError = { constraint in
            self.errorViews += [constraint.firstItem, constraint.secondItem].compactMap { $0 as? UIView }
        }
        withUnsafePointer(to: hookedUIViewAlertForUnsatisfiableConstraints) { (pointer) in
            CFunctionInjector.inject(UIViewAlertForUnsatisfiableConstraints, pointer)
        }
    }
    
    func finalize() {
        _catchAutolayoutError = nil
        CFunctionInjector.reset(UIViewAlertForUnsatisfiableConstraints)
    }
    
    private func getViewController(_ responder: UIResponder) -> UIViewController? {
        return (responder as? UIViewController) ?? responder.next.flatMap(getViewController)
    }
    
    private func viewHasAmbiguous(_ view: UIView) -> Bool {
        return errorViews.contains(view)
    }
    
    private func traverse(_ view: UIView, currentViewController: UIViewController) -> Node? {
        let nodes = view.subviews
            .compactMap { view -> Node? in
                let nextViewController = getViewController(view)
                if let nextViewController = nextViewController, currentViewController !== nextViewController {
                    if let node = traverse(view, currentViewController: nextViewController) {
                        return Node(viewClass: type(of: nextViewController), children: [node], hasAmbiguousLayout: false)
                    }
                    return nil
                } else {
                    return traverse(view, currentViewController: currentViewController)
                }
            }
        if viewHasAmbiguous(view) {
            return Node(viewClass: type(of: view), children: nodes, hasAmbiguousLayout: true)
        } else if !nodes.isEmpty {
            return Node(viewClass: type(of: view), children: nodes, hasAmbiguousLayout: false)
        }
        return nil
    }
    
    func assert(viewController: UIViewController) {
        guard let node = traverse(viewController.view, currentViewController: viewController) else {
            return
        }
        _assert("\(node.numberOfAmbiguous()) view has ambiguous layout\n" + node.assertMessages().description)
    }
}

func assertNoAmbiguousLayout(_ viewController: @autoclosure () -> UIViewController, assert: @escaping (String, StaticString, UInt) -> (), file: StaticString, line: UInt) {
    
    let origin = UIApplication.shared.keyWindow
    let window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = UIViewController()
    window.makeKeyAndVisible()
    let viewController = viewController()
    
    let context = AssertAutolayoutContext(assert: assert, file: file, line: line)
    
    var running = true
    window.rootViewController?.present(viewController, animated: false, completion: {
        context.assert(viewController: viewController)
        window.rootViewController?.dismiss(animated: true, completion: {
            running = false
        })
    })
    while running {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    }
    
    window.resignKey()
    origin?.makeKeyAndVisible()
    
    context.finalize()
}
