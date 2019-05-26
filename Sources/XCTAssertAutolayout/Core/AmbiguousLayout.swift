//
//  AmbiguousLayout.swift
//  CXCTAssertAutolayout
//
//  Created by tarunon on 2019/05/27.
//

import Foundation
import UIKit

struct AmbiguousLayout: OptionSet {
    var rawValue: Int
    
    static var top = AmbiguousLayout(rawValue: 1 << 0)
    static var left = AmbiguousLayout(rawValue: 1 << 1)
    static var right = AmbiguousLayout(rawValue: 1 << 2)
    static var bottom = AmbiguousLayout(rawValue: 1 << 3)
    static var leading = AmbiguousLayout(rawValue: 1 << 4)
    static var trailing = AmbiguousLayout(rawValue: 1 << 5)
    static var firstBaseline = AmbiguousLayout(rawValue: 1 << 6)
    static var lastBaseline = AmbiguousLayout(rawValue: 1 << 7)
    static var width = AmbiguousLayout(rawValue: 1 << 8)
    static var height = AmbiguousLayout(rawValue: 1 << 9)
    static var centerX = AmbiguousLayout(rawValue: 1 << 10)
    static var centerY = AmbiguousLayout(rawValue: 1 << 11)
}

extension AmbiguousLayout: CustomStringConvertible {
    var description: String {
        if isEmpty { return "" }
        let anchors: [(anchor: AmbiguousLayout, label: String)] = [
            (.top, "top"),
            (.left, "left"),
            (.right, "right"),
            (.bottom, "bottom"),
            (.leading, "leading"),
            (.trailing, "trailing"),
            (.firstBaseline, "firstBaseline"),
            (.lastBaseline, "lastBaseline"),
            (.width, "width"),
            (.height, "height"),
            (.centerX, "centerX"),
            (.centerY, "centerY")
        ]
        return " [✘] (" + anchors.filter { self.contains($0.anchor) }.map { $0.label }.joined(separator: ", ") + ")"
    }
}

extension AmbiguousLayout {
    init(_ nsattribute: NSLayoutConstraint.Attribute) {
        switch nsattribute {
        case .top, .topMargin: self = .top
        case .left, .leftMargin: self = .left
        case .right, .rightMargin: self = .right
        case .bottom, .bottomMargin: self = .bottom
        case .leading, .leadingMargin: self = .leading
        case .trailing, .trailingMargin: self = .trailing
        case .firstBaseline: self = .firstBaseline
        case .lastBaseline: self = .lastBaseline
        case .width: self = .width
        case .height: self = .height
        case .centerX, .centerXWithinMargins: self = .centerX
        case .centerY, .centerYWithinMargins: self = .centerY
        case .notAnAttribute: self = .init()
        @unknown default: self = .init()
        }
    }
}
