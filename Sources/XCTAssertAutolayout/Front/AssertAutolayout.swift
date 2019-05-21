//
//  AssertNoAmbiguousLayout.swift
//  XCTAssertNoAmbiguousLayout
//
//  Created by tarunon on 2019/04/28.
//  Copyright © 2019 tarunon. All rights reserved.
//

import XCTest
import UIKit

public func XCTAssertAutolayout(_ viewController: @autoclosure () -> UIViewController, file: StaticString = #file, line: UInt = #line) {
    assertNoAmbiguousLayout(viewController(), assert: XCTFail, file: file, line: line)
}

