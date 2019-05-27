//
//  Assert.swift
//  XCTAssertNoAmbiguousLayout
//
//  Created by tarunon on 2019/04/28.
//  Copyright © 2019 tarunon. All rights reserved.
//

import UIKit

func assertAutolayout(_ viewController: @autoclosure () -> UIViewController, assert: @escaping (String, StaticString, UInt) -> (), file: StaticString, line: UInt) {
    
    guard let origin = UIApplication.shared.keyWindow else {
        assert("Should set Host Application at Test target.", file, line)
        return
    }
    let window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = UIViewController()
    window.makeKeyAndVisible()
    
    let context = AssertAutolayoutContextInternal(assert: assert, file: file, line: line)
    context.process { (context) in
        let viewController = viewController()
        window.rootViewController?.present(viewController, animated: false, completion: {
            context.assert(viewController: viewController, file: file, line: line)
            window.rootViewController?.dismiss(animated: true, completion: {
                context.completion()
            })
        })
    }
    
    window.resignKey()
    origin.makeKeyAndVisible()
    
    context.finalize()
}

func assertAutolayout(_ f: (AssertAutolayoutContext) -> (), assert: @escaping (String, StaticString, UInt) -> (), file: StaticString, line: UInt) {
    let context = AssertAutolayoutContextInternal(assert: assert, file: file, line: line)
    context.process(f)
    context.finalize()
}
