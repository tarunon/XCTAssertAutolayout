import XCTest
import UIKit
@testable import XCTAssertAutolayout

final class XCTAssertAutolayoutTests: XCTestCase {
    func getAssertMessage(_ viewController: UIViewController) -> String? {
        var assertMessage: String?
        assertNoAmbiguousLayout(viewController, assert: { message, _, _ in
            assertMessage = message
        }, file: #file, line: #line)
        return assertMessage
    }
    
    func testAssertAutolayout() {
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
            getAssertMessage(ViewController()),
            """
2 view has ambiguous layout
ViewController
┗UIView
  ┣UIView [✘]
  ┗UIView [✘]
"""
        )
    
        class ViewController2: UIViewController {
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
            getAssertMessage(ViewController2()),
            nil
        )
    }

    static var allTests = [
        ("testAssertAutolayout", testAssertAutolayout),
    ]
}
