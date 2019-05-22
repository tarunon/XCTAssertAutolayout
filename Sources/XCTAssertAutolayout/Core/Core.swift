//
//  Core.swift
//  XCTAssertNoAmbiguousLayout
//
//  Created by tarunon on 2019/04/28.
//  Copyright © 2019 tarunon. All rights reserved.
//

import UIKit

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
