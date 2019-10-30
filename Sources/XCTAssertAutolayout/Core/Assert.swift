//
//  Assert.swift
//  XCTAssertNoAmbiguousLayout
//
//  Created by tarunon on 2019/04/28.
//  Copyright © 2019 tarunon. All rights reserved.
//

import UIKit

func assertAutolayout(_ viewController: @autoclosure () -> UIViewController, assert: @escaping (String, StaticString, UInt) -> (), file: StaticString, line: UInt) {
    let internalContext = AssertAutolayoutContextInternal(assert: assert, file: file, line: line)
    let context = AssertAutolayoutContext(internalContext: internalContext)

    let targetViewController = viewController()
    let window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = targetViewController
    window.isHidden = false
    window.setNeedsLayout()
    window.layoutIfNeeded()

    context.assert(viewController: targetViewController, file: file, line: line)
    context.completion()
    internalContext.finalize()
}

func assertAutolayout(_ f: (AssertAutolayoutContext) -> (), assert: @escaping (String, StaticString, UInt) -> (), file: StaticString, line: UInt) {
    let context = AssertAutolayoutContextInternal(assert: assert, file: file, line: line)
    context.process(f)
    context.finalize()
}
