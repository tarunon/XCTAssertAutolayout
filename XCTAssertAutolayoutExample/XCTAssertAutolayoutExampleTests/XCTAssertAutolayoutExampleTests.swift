//
//  XCTAssertAutolayoutExampleTests.swift
//  XCTAssertAutolayoutExampleTests
//
//  Created by tarunon on 2019/05/21.
//  Copyright © 2019 tarunon. All rights reserved.
//

import XCTest
import XCTAssertAutolayout
@testable import XCTAssertAutolayoutExample

class XCTAssertAutolayoutExampleTests: XCTestCase {
    
    func testExample() {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        XCTAssertAutolayout(storyboard.instantiateInitialViewController()!)
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
