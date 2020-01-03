//
//  Config.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-24.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class Config {
    static let shared = Config()
    
    var dataServerURL: String = "http://192.168.0.121/"
    var fileName1: String = "1m.txt"
    var fileName2: String = "2m.txt"
    var fileName3: String = "3m.txt"
    
    var maxRisk: Double = 10.0
    var minBarStop: Double  = 5.0
    
    var sweetSpotMinDistance: Double  = 1.5 // the max allowed distance from support to low of a series of green bar(s) followed by a blue bar
    
    var greenBarsExit: Double = 5.0 // the min profit the trade must in to use the 2 green bars exit rule
    
    var skipGreenBarsExit: Double = 20.0 // if the current profit(based on the currenty set stop) is higher than, we assume it's a big move and won't exit based on the 2 green bar rules
    
    var enterOnPullback: Double = 20.0 // if the previous trade profit is higher than this and got stopped out, we allow to enter on any pullback if no opposite signal on any timeframe is found from last trade to now
    
    var highRiskStart: (Int, Int) = (9, 30) // Hour/Minute
    var highRiskEnd: (Int, Int) = (10, 0) // Hour/Minute
    
    var chartStart: (Int, Int) = (0, 0)
    var chartEnd: (Int, Int) = (23, 59)
    
    var tradingStart: (Int, Int) = (9, 20)
    var tradingEnd: (Int, Int) = (15, 55)
    
    var clearTime: (Int, Int) = (15, 59)
    var flatTime: (Int, Int) = (16, 5)
    
    var maxDailyLoss: Double = -50.0 // stop trading when P/L goes under this number
    
    var ticker = "NQ"
    var conId = 346577750
    var positionSize: Int = 1
    
    let byPassTradingTimeRestrictions = false
    
    // the time interval where it's allowed to enter trades that has a stop > 10, Default: 9:30 am to 10 am
    func timeIntervalForHighRiskEntry(chart: Chart) -> DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components1 = DateComponents(year: chart.absLastBarDate?.year(),
                                         month: chart.absLastBarDate?.month(),
                                         day: chart.absLastBarDate?.day(),
                                         hour: Config.shared.highRiskStart.0,
                                         minute: Config.shared.highRiskStart.1)
        let startDate: Date = calendar.date(from: components1)!
        let components2 = DateComponents(year: chart.absLastBarDate?.year(),
                                         month: chart.absLastBarDate?.month(),
                                         day: chart.absLastBarDate?.day(),
                                         hour: Config.shared.highRiskEnd.0,
                                         minute: Config.shared.highRiskEnd.1)
        let endDate: Date = calendar.date(from: components2)!
        return DateInterval(start: startDate, end: endDate)
    }
    
    // the time interval allowed to enter trades, default 9:20 am to 3:55 pm
    func tradingTimeInterval(chart: Chart) -> DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components1 = DateComponents(year: chart.absLastBarDate?.year(),
                                         month: chart.absLastBarDate?.month(),
                                         day: chart.absLastBarDate?.day(),
                                         hour: Config.shared.tradingStart.0,
                                         minute: Config.shared.tradingStart.1)
        let startDate: Date = calendar.date(from: components1)!
        let components2 = DateComponents(year: chart.absLastBarDate?.year(),
                                         month: chart.absLastBarDate?.month(),
                                         day: chart.absLastBarDate?.day(),
                                         hour: Config.shared.tradingEnd.0,
                                         minute: Config.shared.tradingEnd.1)
        let endDate: Date = calendar.date(from: components2)!
        return DateInterval(start: startDate, end: endDate)
    }
    
    // after this time, aim to sell at the close of any blue/red bar that's in favor of our ongoing trade
    func clearPositionTime(chart: Chart) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components = DateComponents(year: chart.absLastBarDate?.year(),
                                        month: chart.absLastBarDate?.month(),
                                        day: chart.absLastBarDate?.day(),
                                        hour: Config.shared.clearTime.0,
                                        minute: Config.shared.clearTime.1)
        let date: Date = calendar.date(from: components)!
        return date
    }
    
    // after this time, clear all positions immediately
    func flatPositionsTime(chart: Chart) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components = DateComponents(year: chart.absLastBarDate?.year(),
                                        month: chart.absLastBarDate?.month(),
                                        day: chart.absLastBarDate?.day(),
                                        hour: Config.shared.flatTime.0,
                                        minute: Config.shared.flatTime.1)
        let date: Date = calendar.date(from: components)!
        return date
    }
}
