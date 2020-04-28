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
    
    func weekDay(_ zeroIndex: Bool = false, timeZone: TimeZone? = DefaultTimeZone) -> Int {
        var calendar = Calendar.current
        if let timezone = timeZone {
            calendar.timeZone = timezone
        }
        return calendar.component(.weekday, from: self) - (zeroIndex ? 1 : 0)
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
    
    func generateDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .iso8601)
        dateFormatter.timeZone = Date.DefaultTimeZone
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let response = dateFormatter.string(from: self)
        return response
    }
    
    func generateDateIdentifier() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .iso8601)
        dateFormatter.timeZone = Date.DefaultTimeZone
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let response = dateFormatter.string(from: self)
        return response
    }
    
    private func generateDateAndTimeIdentifier() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .iso8601)
        dateFormatter.timeZone = Date.DefaultTimeZone
        dateFormatter.dateFormat = "yyMMddHHmm"
        let response = dateFormatter.string(from: self)
        return response
    }
    
    func generateOrderIdentifier(prefix: String, linkedToTradeRef: String? = nil) -> String {
        if let linkedToTradeRef = linkedToTradeRef {
            return prefix + "-" + generateDateAndTimeIdentifier() + "-" + linkedToTradeRef
        }
        return prefix + "-" + generateDateAndTimeIdentifier()
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
    
    func isInSameSecond(date: Date, timeZone: TimeZone = Date.DefaultTimeZone) -> Bool {
        var calender = Calendar.current
        calender.timeZone = timeZone
        return calender.isDate(self, equalTo: date, toGranularity: .second)
    }
    
    static func getNewDateFromTime(hour: Int, min: Int) -> Date {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components1 = DateComponents(year: now.year(),
                                         month: now.month(),
                                         day: now.day(),
                                         hour: hour,
                                         minute: min)
        let startDate: Date = calendar.date(from: components1)!
        return startDate
    }
    
    func stripYearMonthAndDay() -> Date {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components = DateComponents(year: now.year(),
                                         month: now.month(),
                                         day: now.day(),
                                         hour: self.hour(),
                                         minute: self.minute())
        let strippedDate: Date = calendar.date(from: components)!
        return strippedDate
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
    
    func startOfDay() -> Date {
        var calendar = Calendar.current
        calendar.timeZone = Date.DefaultTimeZone
        return calendar.startOfDay(for: self)
    }
    
    func getPastOrFutureDate(days: Int, months: Int, years: Int) -> Date {
        var components = DateComponents()
        components.day = days
        components.month = months
        components.year = years
        let offsetDate = Calendar.current.date(byAdding: components, to: self)!
        return offsetDate
    }
    
    static func highRiskEntryInteval(date: Date) -> DateInterval {
        let config = ConfigurationManager.shared
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components1 = DateComponents(year: date.year(),
                                         month: date.month(),
                                         day: date.day(),
                                         hour: config.highRiskStart.hour(),
                                         minute: config.highRiskStart.minute())
        let startDate: Date = calendar.date(from: components1)!
        let components2 = DateComponents(year: date.year(),
                                         month: date.month(),
                                         day: date.day(),
                                         hour: config.highRiskEnd.hour(),
                                         minute: config.highRiskEnd.minute())
        let endDate: Date = calendar.date(from: components2)!
        return DateInterval(start: startDate, end: endDate)
    }
    
    static func tradingTimeInterval(date: Date) -> DateInterval {
        let config = ConfigurationManager.shared
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components1 = DateComponents(year: date.year(),
                                         month: date.month(),
                                         day: date.day(),
                                         hour: config.tradingStart.hour(),
                                         minute: config.tradingStart.minute())
        let startDate: Date = calendar.date(from: components1)!
        let components2 = DateComponents(year: date.year(),
                                         month: date.month(),
                                         day: date.day(),
                                         hour: config.tradingEnd.hour(),
                                         minute: config.tradingEnd.minute())
        let endDate: Date = calendar.date(from: components2)!
        return DateInterval(start: startDate, end: endDate)
    }
    
    static func lunchInterval(date: Date) -> DateInterval {
        let config = ConfigurationManager.shared
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components1 = DateComponents(year: date.year(),
                                         month: date.month(),
                                         day: date.day(),
                                         hour: config.lunchStart.hour(),
                                         minute: config.lunchStart.minute())
        let startDate: Date = calendar.date(from: components1)!
        let components2 = DateComponents(year: date.year(),
                                         month: date.month(),
                                         day: date.day(),
                                         hour: config.lunchEnd.hour(),
                                         minute: config.lunchEnd.minute())
        let endDate: Date = calendar.date(from: components2)!
        return DateInterval(start: startDate, end: endDate)
    }
    
    static func clearPositionTime(date: Date) -> Date {
        let config = ConfigurationManager.shared
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components = DateComponents(year: date.year(),
                                        month: date.month(),
                                        day: date.day(),
                                        hour: config.clearTime.hour(),
                                        minute: config.clearTime.minute())
        let date: Date = calendar.date(from: components)!
        return date
    }
    

    static func flatPositionsTime(date: Date) -> Date {
        let config = ConfigurationManager.shared
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components = DateComponents(year: date.year(),
                                        month: date.month(),
                                        day: date.day(),
                                        hour: config.flatTime.hour(),
                                        minute: config.flatTime.minute())
        let date: Date = calendar.date(from: components)!
        return date
    }
}
