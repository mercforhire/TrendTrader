//
//  Date+Extensions.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-20.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

extension Date {
    static let DefaultTimeZone: TimeZone = TimeZone(abbreviation: "EST")!
    
    func minute(_ zeroIndex: Bool = false, timeZone: TimeZone? = DefaultTimeZone) -> Int {
        var calendar = Calendar.current
        if let timezone = timeZone {
            calendar.timeZone = timezone
        }
        return calendar.component(.minute, from: self) - (zeroIndex ? 1 : 0)
    }
    
    func hour(_ zeroIndex: Bool = false, timeZone: TimeZone? = DefaultTimeZone) -> Int {
        var calendar = Calendar.current
        if let timezone = timeZone {
            calendar.timeZone = timezone
        }
        return calendar.component(.hour, from: self) - (zeroIndex ? 1 : 0)
    }
    
    func day(_ zeroIndex: Bool = false, timeZone: TimeZone? = DefaultTimeZone) -> Int {
        var calendar = Calendar.current
        if let timezone = timeZone {
            calendar.timeZone = timezone
        }
        return calendar.component(.day, from: self) - (zeroIndex ? 1 : 0)
    }
    
    func month(_ zeroIndex: Bool = false, timeZone: TimeZone? = DefaultTimeZone) -> Int {
        var calendar = Calendar.current
        if let timezone = timeZone {
            calendar.timeZone = timezone
        }
        return calendar.component(.month, from: self) - (zeroIndex ? 1 : 0)
    }
    
    func year(timeZone: TimeZone? = DefaultTimeZone) -> Int {
        var calendar = Calendar.current
        if let timezone = timeZone {
            calendar.timeZone = timezone
        }
        return calendar.component(.year, from: self)
    }
    
    func generateDateIdentifier() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .iso8601)
        dateFormatter.timeZone = Date.DefaultTimeZone
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let response = dateFormatter.string(from: self)
        return response
    }
}
