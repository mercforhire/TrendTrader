//
//  DisplayNumberFormatter.swift
//  Phoenix
//
//  Created by Adam Borzecki on 11/13/18.
//  Copyright © 2018 Symbility Intersect. All rights reserved.
//

import Foundation

class DisplayNumberFormatter {
    static var formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        return formatter
    }()
    
    class func transform<NumberType: Numeric>(from: NumberType, style: NumberFormatter.Style = .currency, setOptions: (NumberFormatter) -> Void) -> String? {
        formatter.numberStyle = style
        formatter.currencySymbol = "$"
        setOptions(formatter)
        return (formatter.string(from: from as! NSNumber) ?? "").stripUppercaseLetters()
    }
}
