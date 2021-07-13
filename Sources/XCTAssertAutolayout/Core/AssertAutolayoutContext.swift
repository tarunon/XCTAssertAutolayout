//
//  AssertAutolayoutContext.swift
//  XCTAssertAutolayout
//
//  Created by tarunon on 2019/05/22.
//

import Foundation
import UIKit
import CXCTAssertAutolayout

let UIViewAlertForUnsatisfiableConstraintsSymbol = "UIViewAlertForUnsatisfiableConstraints"

var _catchAutolayoutError: ((NSLayoutConstraint, [NSLayoutConstraint]) -> ())?
var hookedUIViewAlertForUnsatisfiableConstraintsPointer: UnsafeRawPointer!
var injector: CFunctionInjector?

// make c function pointer by convention attribute
let hookedUIViewAlertForUnsatisfiableConstraints: (@convention(c) (NSLayoutConstraint, [NSLayoutConstraint]) -> Void) = { (constraint: NSLayoutConstraint, allConstraints: [NSLayoutConstraint]) in
    _catchAutolayoutError?(constraint, allConstraints)
    try! injector?.reset()
    UIViewAlertForUnsatisfiableConstraints(constraint, allConstraints)
    try! injector?.inject(hookedUIViewAlertForUnsatisfiableConstraintsPointer)
}

public class AssertAutolayoutContext {
    let internalContext: AssertAutolayoutContextInternal
    
    init(internalContext: AssertAutolayoutContextInternal) {
        self.internalContext = internalContext
    }
    
    public func assert(viewController: UIViewController, file: StaticString = #file, line: UInt = #line) {
        guard let node = internalContext.traverse(viewController.view, currentViewController: viewController) else {
            return
        }
        let root = Node(viewClass: type(of: viewController), children: [node], ambiguousLayout: .init())
        internalContext._assert("\(root.numberOfAmbiguous()) view has ambiguous layout\n" + root.assertMessages(), file, line)
    }
    
    public func completion() {
        internalContext.completed = true
    }
    
    deinit {
        if !internalContext.completed {
            internalContext._assert("context.completion() must call", internalContext.file, internalContext.line)
        }
        internalContext.completed = true
    }
    
}

class AssertAutolayoutContextInternal {
    let _assert: (String, StaticString, UInt) -> ()
    let file: StaticString
    let line: UInt
    var errorConstraints: [NSLayoutConstraint] = []
    var completed = false
    
    init(assert: @escaping (String, StaticString, UInt) -> (), file: StaticString, line: UInt) {
        self._assert = assert
        self.file = file
        self.line = line
        _catchAutolayoutError = { _, allConstraints in
            self.errorConstraints += allConstraints
        }
        if injector == nil {
            do {
                injector = try CFunctionInjector(UIViewAlertForUnsatisfiableConstraintsSymbol)
            } catch {
                _assert("XCTAssertAutolayout should run in iPhoneSimulator, cannot run on real Devices. (\(error))", file, line)
            }
        }
        hookedUIViewAlertForUnsatisfiableConstraintsPointer = unsafeBitCast(hookedUIViewAlertForUnsatisfiableConstraints, to: UnsafeRawPointer.self)
        try! injector?.inject(hookedUIViewAlertForUnsatisfiableConstraintsPointer)
    }
    
    func finalize() {
        _catchAutolayoutError = nil
        try! injector?.reset()
    }
    
    private func getViewController(_ responder: UIResponder) -> UIViewController? {
        return (responder as? UIViewController) ?? responder.next.flatMap(getViewController)
    }
    
    private func ambiguousLayout(for view: UIView) -> AmbiguousLayout {
        return AmbiguousLayout(errorConstraints
            .map { constraint in
                var result = AmbiguousLayout()
                if constraint.firstItem === view {
                    result = [result, AmbiguousLayout(constraint.firstAttribute)]
                }
                if constraint.secondItem === view {
                    result = [result, AmbiguousLayout(constraint.secondAttribute)]
                }
                return result
        })
    }
    
    func traverse(_ view: UIView, currentViewController: UIViewController) -> Node? {
        let nodes = view.subviews
            .compactMap { view -> Node? in
                let nextViewController = getViewController(view)
                if let nextViewController = nextViewController, currentViewController !== nextViewController {
                    if let node = traverse(view, currentViewController: nextViewController) {
                        return Node(viewClass: type(of: nextViewController), children: [node], ambiguousLayout: .init())
                    }
                    return nil
                } else {
                    return traverse(view, currentViewController: currentViewController)
                }
        }
        let anchors = ambiguousLayout(for: view)
        if !anchors.isEmpty || !nodes.isEmpty {
            return Node(viewClass: type(of: view), children: nodes, ambiguousLayout: anchors)
        }
        return nil
    }
    
    func process(_ f: (AssertAutolayoutContext) -> ()) {
        f(AssertAutolayoutContext(internalContext: self))
        while !completed {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
    }
}
