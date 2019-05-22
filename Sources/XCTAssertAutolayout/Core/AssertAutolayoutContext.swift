//
//  AssertAutolayoutContext.swift
//  XCTAssertAutolayout
//
//  Created by tarunon on 2019/05/22.
//

import Foundation
import UIKit

@_silgen_name("UIViewAlertForUnsatisfiableConstraints")
func originalUIViewAlertForUnsatisfiableConstraints(_ constraint: NSLayoutConstraint, _ allConstraints: NSArray)
let UIViewAlertForUnsatisfiableConstraints = "UIViewAlertForUnsatisfiableConstraints"

var _catchAutolayoutError: ((NSLayoutConstraint, NSArray) -> ())?

func hookedUIViewAlertForUnsatisfiableConstraints(_ constraint: NSLayoutConstraint, _ allConstraints: NSArray) {
    _catchAutolayoutError?(constraint, allConstraints)
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
        _catchAutolayoutError = { _, allConstraints in
            self.errorViews += allConstraints
                .compactMap { $0 as? NSLayoutConstraint }
                .flatMap { [$0.firstItem, $0.secondItem] }
                .compactMap { $0 as? UIView }
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
        let root = Node(viewClass: type(of: viewController), children: [node], hasAmbiguousLayout: false)
        _assert("\(root.numberOfAmbiguous()) view has ambiguous layout\n" + root.assertMessages().description)
    }
}

