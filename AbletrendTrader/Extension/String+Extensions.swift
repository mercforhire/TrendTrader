//
//  String+Extensions.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-19.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

extension String {

    //right is the first encountered string after left
    func between(_ left: String, _ right: String) -> String? {
        guard
            let leftRange = range(of: left), let rightRange = range(of: right, options: .backwards)
            , leftRange.upperBound <= rightRange.lowerBound
            else { return nil }

        let sub = self[leftRange.upperBound...]
        let closestToLeftRange = sub.range(of: right)!
        return String(sub[..<closestToLeftRange.lowerBound])
    }

    var length: Int {
        get {
            return self.count
        }
    }

    func substring(to : Int) -> String {
        let toIndex = self.index(self.startIndex, offsetBy: to)
        return String(self[...toIndex])
    }

    func substring(from : Int) -> String {
        let fromIndex = self.index(self.startIndex, offsetBy: from)
        return String(self[fromIndex...])
    }

    func substring(_ r: Range<Int>) -> String {
        let fromIndex = self.index(self.startIndex, offsetBy: r.lowerBound)
        let toIndex = self.index(self.startIndex, offsetBy: r.upperBound)
        let indexRange = Range<String.Index>(uncheckedBounds: (lower: fromIndex, upper: toIndex))
        return String(self[indexRange])
    }

    func character(_ at: Int) -> Character {
        return self[self.index(self.startIndex, offsetBy: at)]
    }
}

extension String {
    subscript(value: NSRange) -> Substring {
        return self[value.lowerBound..<value.upperBound]
    }
    
    subscript(input: Int) -> Character {
        return self[index(startIndex, offsetBy: input)]
    }
    
    subscript(value: CountableClosedRange<Int>) -> Substring {
        return self[index(at: value.lowerBound)...index(at: value.upperBound)]
    }
    
    subscript(value: CountableRange<Int>) -> Substring {
        return self[index(at: value.lowerBound)..<index(at: value.upperBound)]
    }
    
    subscript(value: PartialRangeUpTo<Int>) -> Substring {
        return self[..<index(at: value.upperBound)]
    }
    
    subscript(value: PartialRangeThrough<Int>) -> Substring {
        return self[...index(at: value.upperBound)]
    }
    
    subscript(value: PartialRangeFrom<Int>) -> Substring {
        return self[index(at: value.lowerBound)...]
    }
    
    func index(at offset: Int) -> String.Index {
        return index(startIndex, offsetBy: offset)
    }
}

extension String {
    private static let noCharacter = ""
    
    public func trim() -> String {
        return trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    public var isAlphanumeric: Bool {
        return !self.isEmpty && self.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil
    }
    
    public var isNumeric: Bool {
        return !self.isEmpty && self.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
    }
    
    public func removeAllWhitespace() -> String {
        return self.components(separatedBy: CharacterSet.whitespaces).joined(separator: String.noCharacter)
    }
    
    public var isNotApplicable: Bool {
        let compareString = self.lowercased()
        let compareArray = ["not applicable",
                            "na",
                            "not allowed",
                            "not aplicable",
                            "not appliable",
                            "n\\a",
                            "n.a",
                            "na",
                            "n.a.",
                            "n/a"]
        return compareArray.contains(compareString.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    public func toBool() -> Bool? {
        switch self {
        case "True", "true", "yes", "1":
            return true
        case "False", "false", "no", "0":
            return false
        default:
            return nil
        }
    }
    
    public var double: Double? {
        return NumberFormatter().number(from: self) as? Double
    }
    
    public var float: Float? {
        return NumberFormatter().number(from: self) as? Float
    }
    
    public var float32: Float32? {
        return NumberFormatter().number(from: self) as? Float32
    }
    
    public var float64: Float64? {
        return NumberFormatter().number(from: self) as? Float64
    }
    
    public var int: Int? {
        return Int(self)
    }
    
    public var int16: Int16? {
        return Int16(self)
    }
    
    public var int32: Int32? {
        return Int32(self)
    }
    
    public var int64: Int64? {
        return Int64(self)
    }
    
    public var int8: Int8? {
        return Int8(self)
    }
    
    public var url: URL? {
        return URL(string: self)
    }
    
    public var doubleFromCurrency: Double? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.number(from: self) as? Double
    }
    
    // Extract numbers from string
    public var numbers: String {
        let set = CharacterSet.decimalDigits.inverted
        let numbers = self.components(separatedBy: set)
        return numbers.joined()
    }
    
    public var removeNumbers: String {
        let set = CharacterSet.decimalDigits
        let notNumbers = self.components(separatedBy: set)
        return notNumbers.joined()
    }
    
    // Trim to a set length
    public func trimToLength(length: Int, addDotsToEnd: Bool = false) -> String {
        if self.count <= length || (addDotsToEnd && self.count <= 3) {
            return self
        }
        
        if addDotsToEnd {
            let substring = self[..<(length - 3)]
            return String(substring) + "..."
        } else {
            let substring = self[..<length]
            return String(substring)
        }
    }
    
    public func stripUppercaseLetters() -> String {
        let unsafeChars = CharacterSet.uppercaseLetters
        let cleanChars = components(separatedBy: unsafeChars).joined()
        return cleanChars
    }
}
