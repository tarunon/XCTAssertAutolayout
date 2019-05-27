//
//  AssertNoAmbiguousLayout.swift
//  XCTAssertNoAmbiguousLayout
//
//  Created by tarunon on 2019/04/28.
//  Copyright © 2019 tarunon. All rights reserved.
//

import XCTest
import UIKit

/// Generates a failure if the viewController has ambiguous layout.
/// This function make UIWindow and launch viewController.
/// Required to set host application in test case.
///
/// - Parameters:
///   - viewController: The asssert target.
public func XCTAssertAutolayout(file: StaticString = #file, line: UInt = #line, _ viewController: @autoclosure () -> UIViewController) {
    assertNoAmbiguousLayout(viewController(), assert: XCTFail, file: file, line: line)
}

/// Generates a failure if the viewController has ambigous layout.
/// Support changing behavior in viewController after launching such as animation.
/// Should show viewController in screen own self.
///
/// - Parameters:
///   - f: The closure givven autolayout test context.
public func XCTAssertAutolayout(file: StaticString = #file, line: UInt = #line, _ f: (AssertAutolayoutContext) -> ()) {
    assertNoAmbiguousLayout(f, assert: XCTFail, file: file, line: line)
}
