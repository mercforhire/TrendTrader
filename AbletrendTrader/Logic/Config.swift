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
    
    let dataServerURL: String = "http://192.168.1.104/"
    let fileName1: String = "1m.txt" // filename for local sandbox folder
    let fileName2: String = "2m.txt" // filename for local sandbox folder
    let fileName3: String = "3m.txt" // filename for local sandbox folder
    
    let defaultCommission = 2.05
    let maxRisk: Double = 10.0
    let minBarStop: Double = 5.0
    let sweetSpotMinDistance: Double  = 1.5 // the max allowed distance from support to low of a series of green bar(s) followed by a blue bar
    let greenBarsExit: Double = 10.0 // the min profit the trade must in to use the 2 green bars exit rule
    let skipGreenBarsExit: Double = 25.0 // if the current profit(based on the currenty set stop) is higher than, we assume it's a big move and won't exit based on the 2 green bar rules
    let enterOnPullback: Double = 20.0 // if the previous trade profit is higher than this and got stopped out, we allow to enter on any pullback if no opposite signal on any timeframe is found from last trade to now
    
    let highRiskStart: (Int, Int) = (9, 30) // Hour/Minute
    let highRiskEnd: (Int, Int) = (10, 0) // Hour/Minute
    
    let chartStart: (Int, Int) = (0, 0) // Hour/Minute
    let chartEnd: (Int, Int) = (23, 59) // Hour/Minute
    
    let tradingStart: (Int, Int) = (9, 20) // Hour/Minute
    let tradingEnd: (Int, Int) = (15, 55) // Hour/Minute
    
    let clearTime: (Int, Int) = (15, 59) // Hour/Minute
    let flatTime: (Int, Int) = (16, 5) // Hour/Minute
    
    let maxDailyLoss = -50.0 // stop trading when P/L goes under this number
    let ticker = "NQ"
    let tickerPointValue = 20.0
    let conId = 346577750
    let positionSize: Int = 1
    let maxActionRetryTimes = 3
    
    let ntCommission = 1.60
    let ntTicker = "NQ 03-20"
    let ntName = "Globex"
    let ntAccountLongName = "NinjaTrader Continuum (Demo)"
    var ntIncomingPath = "/Users/lchen/Downloads/NinjaTrader/incoming"
    var ntOutgoingPath = "/Users/lchen/Downloads/NinjaTrader/outgoing"
    var ntAccountName = "Sim101"
    
    // DEMO SETTINGS:
    let liveTradingMode: LiveTradingMode = .ninjaTrader
    let byPassTradingTimeRestrictions = false // DEFAULT: false
    let simulateTimePassage = false // DEFAULT: true
    
    // the time interval where it's allowed to enter trades that has a stop > 10, Default: 9:30 am to 10 am
    func timeIntervalForHighRiskEntry(date: Date) -> DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components1 = DateComponents(year: date.year(),
                                         month: date.month(),
                                         day: date.day(),
                                         hour: Config.shared.highRiskStart.0,
                                         minute: Config.shared.highRiskStart.1)
        let startDate: Date = calendar.date(from: components1)!
        let components2 = DateComponents(year: date.year(),
                                         month: date.month(),
                                         day: date.day(),
                                         hour: Config.shared.highRiskEnd.0,
                                         minute: Config.shared.highRiskEnd.1)
        let endDate: Date = calendar.date(from: components2)!
        return DateInterval(start: startDate, end: endDate)
    }
    
    // the time interval allowed to enter trades, default 9:20 am to 3:55 pm
    func tradingTimeInterval(date: Date) -> DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components1 = DateComponents(year: date.year(),
                                         month: date.month(),
                                         day: date.day(),
                                         hour: Config.shared.tradingStart.0,
                                         minute: Config.shared.tradingStart.1)
        let startDate: Date = calendar.date(from: components1)!
        let components2 = DateComponents(year: date.year(),
                                         month: date.month(),
                                         day: date.day(),
                                         hour: Config.shared.tradingEnd.0,
                                         minute: Config.shared.tradingEnd.1)
        let endDate: Date = calendar.date(from: components2)!
        return DateInterval(start: startDate, end: endDate)
    }
    
    // after this time, aim to sell at the close of any blue/red bar that's in favor of our ongoing trade
    func clearPositionTime(date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components = DateComponents(year: date.year(),
                                        month: date.month(),
                                        day: date.day(),
                                        hour: Config.shared.clearTime.0,
                                        minute: Config.shared.clearTime.1)
        let date: Date = calendar.date(from: components)!
        return date
    }
    
    // after this time, clear all positions immediately
    func flatPositionsTime(date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components = DateComponents(year: date.year(),
                                        month: date.month(),
                                        day: date.day(),
                                        hour: Config.shared.flatTime.0,
                                        minute: Config.shared.flatTime.1)
        let date: Date = calendar.date(from: components)!
        return date
    }
}
