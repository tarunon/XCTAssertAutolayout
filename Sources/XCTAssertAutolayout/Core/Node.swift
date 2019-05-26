//
//  Node.swift
//  XCTAssertAutolayout
//
//  Created by tarunon on 2019/05/22.
//

import Foundation

struct Node {
    var viewClass: AnyClass
    var children: [Node]
    var ambiguousLayout: AmbiguousLayout
    
    struct AssertMessage: CustomStringConvertible {
        var head: String
        var body: [AssertMessage]
        
        var descriptions: [String] {
            if body.isEmpty {
                return [head]
            }
            let headDesc = [head]
            let bodyDesc = body.dropLast().flatMap { assertMessage -> [String] in
                let descs = assertMessage.descriptions
                let headDesc = descs.first.map { "┣" + $0 }
                let bodyDesc = descs.dropFirst().map { "┃" + $0 }
                return [headDesc!] + bodyDesc
            }
            let bodyLastDesc = body.last.map { assertMessage -> [String] in
                let descs = assertMessage.descriptions
                let headDesc = descs.first.map { "┗" + $0 }
                let bodyDesc = descs.dropFirst().map { "  " + $0 }
                return [headDesc!] + bodyDesc
            }
            return headDesc + bodyDesc + bodyLastDesc!
        }
        
        var description: String {
            return descriptions.joined(separator: "\n")
        }
    }
    
    func numberOfAmbiguous() -> Int {
        return children.map { $0.numberOfAmbiguous() }.reduce(ambiguousLayout.isEmpty ? 0 : 1) { $0 + $1 }
    }
    
    func assertMessages() -> AssertMessage {
        let head = "\(viewClass)\(ambiguousLayout)"
        return AssertMessage(head: head, body: children.map { $0.assertMessages() })
    }
}
