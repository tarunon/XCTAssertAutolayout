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
let injector: CFunctionInjector = try! CFunctionInjector(UIViewAlertForUnsatisfiableConstraintsSymbol)

// make c function pointer by convention attribute
let hookedUIViewAlertForUnsatisfiableConstraints: (@convention(c) (NSLayoutConstraint, [NSLayoutConstraint]) -> Void) = { (constraint: NSLayoutConstraint, allConstraints: [NSLayoutConstraint]) in
    _catchAutolayoutError?(constraint, allConstraints)
    injector.reset()
    UIViewAlertForUnsatisfiableConstraints(constraint, allConstraints)
    injector.inject(hookedUIViewAlertForUnsatisfiableConstraintsPointer)
}

class AssertAutolayoutContext {
    private let _assert: (String) -> ()
    private var errorConstraints: [NSLayoutConstraint] = []
    
    init(assert: @escaping (String, StaticString, UInt) -> (), file: StaticString, line: UInt) {
        _assert = { assert($0, file, line) }
        _catchAutolayoutError = { _, allConstraints in
            self.errorConstraints += allConstraints
        }
        
        hookedUIViewAlertForUnsatisfiableConstraintsPointer = unsafeBitCast(hookedUIViewAlertForUnsatisfiableConstraints, to: UnsafeRawPointer.self)
        injector.inject(hookedUIViewAlertForUnsatisfiableConstraintsPointer)
    }
    
    func finalize() {
        _catchAutolayoutError = nil
        injector.reset()
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
    
    private func traverse(_ view: UIView, currentViewController: UIViewController) -> Node? {
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
    
    func assert(viewController: UIViewController) {
        guard let node = traverse(viewController.view, currentViewController: viewController) else {
            return
        }
        let root = Node(viewClass: type(of: viewController), children: [node], ambiguousLayout: .init())
        _assert("\(root.numberOfAmbiguous()) view has ambiguous layout\n" + root.assertMessages().description)
    }
}

