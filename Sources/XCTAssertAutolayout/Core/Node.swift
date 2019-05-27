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
    
    func numberOfAmbiguous() -> Int {
        return children.map { $0.numberOfAmbiguous() }.reduce(ambiguousLayout.isEmpty ? 0 : 1) { $0 + $1 }
    }
    
    func generateDescriptionTree() -> [String] {
        let head = "\(viewClass)\(ambiguousLayout)"
        if children.isEmpty { return [head] }
        return [head] +
            children.dropLast().flatMap { node -> [String] in
                let bodies = node.generateDescriptionTree()
                return ["┣" + bodies.first!] + bodies.dropFirst().map { "┃" + $0 }
            } +
            children.last.map { node -> [String] in
                let bodies = node.generateDescriptionTree()
                return ["┗" + bodies.first!] + bodies.dropFirst().map { "  " + $0 }
            }!
    }
    
    func assertMessages() -> String {
        return generateDescriptionTree().joined(separator: "\n")
    }
}
