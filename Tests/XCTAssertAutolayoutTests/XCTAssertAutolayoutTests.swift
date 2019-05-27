import XCTest
import UIKit
@testable import XCTAssertAutolayout

final class XCTAssertAutolayoutTests: XCTestCase {
    func getAssertMessages(_ viewController: UIViewController) -> [String] {
        var assertMessages = [String]()
        assertAutolayout(viewController, assert: { message, _, _ in
            assertMessages.append(message)
        }, file: #file, line: #line)
        return assertMessages
    }
    
    func getAssertMessages(_ f: (AssertAutolayoutContext) -> ()) -> [String] {
        var assertMessages = [String]()
        assertAutolayout(f, assert: { (message, _, _) in
            assertMessages.append(message)
        }, file: #file, line: #line)
        return assertMessages
    }
    
    func testHasAmbiguousLayout() {
        class ViewController: UIViewController {
            override func viewDidLoad() {
                super.viewDidLoad()
                let view1 = UIView()
                let view2 = UIView()
                view1.translatesAutoresizingMaskIntoConstraints = false
                view2.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(view1)
                view.addSubview(view2)
                NSLayoutConstraint.activate(
                    [
                        view1.topAnchor.constraint(equalTo: view.topAnchor),
                        view1.leftAnchor.constraint(equalTo: view.leftAnchor),
                        view1.heightAnchor.constraint(equalToConstant: 44.0),
                        view2.topAnchor.constraint(equalTo: view.topAnchor),
                        view2.leftAnchor.constraint(equalTo: view.leftAnchor),
                        view2.heightAnchor.constraint(equalToConstant: 44.0),
                        view1.widthAnchor.constraint(equalToConstant: 200.0),
                        view1.widthAnchor.constraint(equalTo: view2.widthAnchor), // A
                        view1.widthAnchor.constraint(equalTo: view2.widthAnchor, multiplier: 2.0), // B
                    ]
                )
            }
        }
        
        XCTAssertEqual(
            getAssertMessages(ViewController()),
            [
                """
2 view has ambiguous layout
ViewController
┗UIView
  ┣UIView [✘] (width)
  ┗UIView [✘] (width)
"""
            ]
        )
    }
    
    func testHasNoAmbiguousLayout() {
        class ViewController: UIViewController {
            override func viewDidLoad() {
                super.viewDidLoad()
                let view1 = UIView()
                let view2 = UIView()
                view1.translatesAutoresizingMaskIntoConstraints = false
                view2.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(view1)
                view.addSubview(view2)
                NSLayoutConstraint.activate(
                    [
                        view1.topAnchor.constraint(equalTo: view.topAnchor),
                        view1.leftAnchor.constraint(equalTo: view.leftAnchor),
                        view1.heightAnchor.constraint(equalToConstant: 44.0),
                        view2.topAnchor.constraint(equalTo: view.topAnchor),
                        view2.leftAnchor.constraint(equalTo: view.leftAnchor),
                        view2.heightAnchor.constraint(equalToConstant: 44.0),
                        view1.widthAnchor.constraint(equalToConstant: 200.0),
                        view1.widthAnchor.constraint(equalTo: view2.widthAnchor),
                    ]
                )
            }
        }
        
        XCTAssertEqual(
            getAssertMessages(ViewController()),
            []
        )
    }
    
    func testAmbigousLayoutWithAnimation() {
        class ViewController: UIViewController {
            let view1 = UIView()
            let view2 = UIView()
            
            override func viewDidLoad() {
                super.viewDidLoad()
                view1.translatesAutoresizingMaskIntoConstraints = false
                view2.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(view1)
                view.addSubview(view2)
                NSLayoutConstraint.activate(
                    [
                        view1.topAnchor.constraint(equalTo: view.topAnchor),
                        view1.leftAnchor.constraint(equalTo: view.leftAnchor),
                        view1.heightAnchor.constraint(equalToConstant: 44.0),
                        view2.topAnchor.constraint(equalTo: view.topAnchor),
                        view2.leftAnchor.constraint(equalTo: view.leftAnchor),
                        view2.heightAnchor.constraint(equalToConstant: 44.0),
                        view1.widthAnchor.constraint(equalToConstant: 200.0),
                        view1.widthAnchor.constraint(equalTo: view2.widthAnchor),
                    ]
                )
            }
            
            func makeAmbigousWithAnimation(completion: @escaping () -> ()) {
                NSLayoutConstraint.activate(
                    [
                        view1.widthAnchor.constraint(equalTo: view2.widthAnchor), // A
                        view1.widthAnchor.constraint(equalTo: view2.widthAnchor, multiplier: 2.0), // B
                    ]
                )
                
                UIView.animate(
                    withDuration: 0.35,
                    animations: {
                        self.view.layoutIfNeeded()
                    },
                    completion: { _ in
                        completion()
                })
            }
        }
        
        do {
            XCTAssertEqual(
                getAssertMessages { context in
                    let viewController = ViewController()
                    context.assert(viewController: viewController)
                },
                [
                    "context.completion() must call"
                ]
            )
        }
        
        do {
            XCTAssertEqual(
                getAssertMessages { context in
                    let viewController = ViewController()
                    UIApplication.shared.keyWindow?.rootViewController = viewController
                    viewController.makeAmbigousWithAnimation {
                        context.assert(viewController: viewController)
                        context.completion()
                    }
                },
                [
                    """
2 view has ambiguous layout
ViewController
┗UIView
  ┣UIView [✘] (width)
  ┗UIView [✘] (width)
"""
                ]
            )
        }
    }

    static var allTests = [
        ("testHasAmbiguousLayout", testHasAmbiguousLayout),
        ("testHasNoAmbiguousLayout", testHasNoAmbiguousLayout),
    ]
}
