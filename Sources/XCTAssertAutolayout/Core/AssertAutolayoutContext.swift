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
    private var ambiguousCount = 0
    private var assertMessages = [String]()
    private var errorViews: [UIView] = []
    
    init(assert: @escaping (String, StaticString, UInt) -> (), file: StaticString, line: UInt) {
        _assert = { assert($0, file, line) }
        _catchAutolayoutError = { _, allConstraints in
            self.errorViews += allConstraints
                .flatMap { [$0.firstItem, $0.secondItem] }
                .compactMap { $0 as? UIView }
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

