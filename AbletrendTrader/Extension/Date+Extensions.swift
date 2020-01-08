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
    
    func second(_ zeroIndex: Bool = false, timeZone: TimeZone? = DefaultTimeZone) -> Int {
        var calendar = Calendar.current
        if let timezone = timeZone {
            calendar.timeZone = timezone
        }
        return calendar.component(.second, from: self) - (zeroIndex ? 1 : 0)
    }
    
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
    
    func generateDateAndTimeIdentifier() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .iso8601)
        dateFormatter.timeZone = Date.DefaultTimeZone
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let response = dateFormatter.string(from: self)
        return response
    }
    
    func isInSameDay(date: Date, timeZone: TimeZone = Date.DefaultTimeZone) -> Bool {
        var calender = Calendar.current
        calender.timeZone = timeZone
        return calender.isDate(self, equalTo: date, toGranularity: .day)
    }
    
    func isInSameMinute(date: Date, timeZone: TimeZone = Date.DefaultTimeZone) -> Bool {
        var calender = Calendar.current
        calender.timeZone = timeZone
        return calender.isDate(self, equalTo: date, toGranularity: .minute)
    }
    
    func getNewDateFromTime(hour: Int, min: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components1 = DateComponents(year: self.year(),
                                         month: self.month(),
                                         day: self.day(),
                                         hour: hour,
                                         minute: min)
        let startDate: Date = calendar.date(from: components1)!
        return startDate
    }
    
    func hourMinuteSecond() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .iso8601)
        dateFormatter.timeZone = Date.DefaultTimeZone
        dateFormatter.dateFormat = "HH:mm:ss"
        let response = dateFormatter.string(from: self)
        return response
    }
    
    func hourMinute() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .iso8601)
        dateFormatter.timeZone = Date.DefaultTimeZone
        dateFormatter.dateFormat = "HH:mm"
        let response = dateFormatter.string(from: self)
        return response
    }
    
    func getOffByMinutes(minutes: Int) -> Date {
        var components = DateComponents()
        components.minute = minutes
        let offsetDate = Calendar.current.date(byAdding: components, to: self)!
        return offsetDate
    }
}
