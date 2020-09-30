//
//  TradingSettings.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-05-16.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation

struct TradingSettings: Codable {
    var buffer: Double
    var riskMultiplier: Double
    
    var maxRiskBase: Double
    var maxRisk: Double {
        return maxRiskBase * riskMultiplier
    }
    
    var minStopBase: Double
    var minStop: Double {
        return minStopBase
    }
    
    // the max allowed distance from support to low of a series of green bar(s) followed by a blue bar
    var sweetSpotBase: Double
    var sweetSpot: Double {
        return sweetSpotBase
    }
    
    // the min profit the trade must in to use the 2 green bars exit rule
    var greenExitBase: Double
    var greenExit: Double {
        return greenExitBase * riskMultiplier
    }
    
    // if the current profit(based on the currenty set stop) is higher than, we assume it's a big move and won't exit based on the 2 green bar rules
    var skipGreenExitBase: Double
    var skipGreenExit: Double {
        return skipGreenExitBase * riskMultiplier
    }
    
    // if the previous trade profit is higher than this and got stopped out, we allow to enter on any pullback if no opposite signal on any timeframe is found from last trade to now
    var enterOnAnyPullbackBase: Double
    var enterOnAnyPullback: Double {
        return enterOnAnyPullbackBase * riskMultiplier
    }
    
    var takeProfitBarLengthBase: Double
    var takeProfitBarLength: Double {
        return takeProfitBarLengthBase * riskMultiplier
    }
    
    // stop trading when P/L goes under this number
    var maxDailyLossBase: Double
    var maxDailyLoss: Double {
        return maxDailyLossBase * riskMultiplier
    }
    
    var maxDistanceToSRBase: Double
    var maxDistanceToSR: Double {
        return maxDistanceToSRBase * riskMultiplier
    }
    
    var profitAvoidSameDirectionBase: Double
    var profitAvoidSameDirection: Double {
        return profitAvoidSameDirectionBase * riskMultiplier
    }
    
    var oppositeLosingTradesToHalt: Int
    
    var losingConsecutiveTradesToHalt: Int
    
    var losingTradesToHalt: Int
    
    var profitToHaltBase: Double
    var profitToHalt: Double {
        return profitToHaltBase * riskMultiplier
    }
    
    var tradingStart: Date
    var tradingEnd: Date
    
    var lunchStart: Date
    var lunchEnd: Date
    
    var clearTime: Date
    
    var flatTime: Date
    
    var fomcTime: Date
    
    var positionSize: Int
    
    var byPassTradingTimeRestrictions: Bool
    
    var noEntryDuringLunch: Bool
    
    var simulateTimePassage: Bool
    
    var avoidTakingSameTrade: Bool
    
    var avoidTakingSameLosingTrade: Bool
    
    var waitForFinalizedSignals: Bool
    
    var fomcDay: Bool
    
    var drawdownLimit: Double
    
    init() {
        let defaultSettings: NSDictionary = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "DefaultSettings", ofType: "plist")!)!
        
        self.buffer = defaultSettings["buffer"] as! Double
         
        self.riskMultiplier = defaultSettings["risk_multiplier"] as! Double
         
        self.maxRiskBase = defaultSettings["max_risk"] as! Double
         
        self.minStopBase = defaultSettings["min_stop"] as! Double
         
        self.sweetSpotBase = defaultSettings["sweet_spot_min_distance"] as! Double
         
        self.greenExitBase = defaultSettings["green_bars_exit"] as! Double
         
        self.skipGreenExitBase = defaultSettings["skip_green_bars_exit"] as! Double
         
        self.enterOnAnyPullbackBase = defaultSettings["enter_on_pullback"] as! Double
         
        self.takeProfitBarLengthBase = defaultSettings["take_profit_bar_length"] as! Double
         
        self.profitToHaltBase = defaultSettings["profit_to_halt"] as! Double
         
        self.tradingStart = (defaultSettings["trading_start"] as! Date).stripYearMonthAndDay()
         
        self.tradingEnd = (defaultSettings["trading_end"] as! Date).stripYearMonthAndDay()
         
        self.lunchStart = (defaultSettings["lunch_start"] as! Date).stripYearMonthAndDay()
         
        self.lunchEnd =  (defaultSettings["lunch_end"] as! Date).stripYearMonthAndDay()
         
        self.clearTime = (defaultSettings["clear_time"] as! Date).stripYearMonthAndDay()
         
        self.flatTime = (defaultSettings["flat_time"] as! Date).stripYearMonthAndDay()
         
        self.fomcTime = (defaultSettings["fomc_time"] as! Date).stripYearMonthAndDay()
         
        self.fomcDay = false
         
        self.positionSize = defaultSettings["position_size"] as! Int
         
        self.maxDailyLossBase = defaultSettings["max_daily_loss"] as! Double
         
        self.byPassTradingTimeRestrictions = defaultSettings["bypass_trading_time_restrictions"] as! Bool
         
        self.noEntryDuringLunch = defaultSettings["no_entry_during_lunch"] as! Bool
         
        self.waitForFinalizedSignals = true
        
        self.simulateTimePassage = false
         
        self.avoidTakingSameTrade = true
         
        self.avoidTakingSameLosingTrade = false
         
        self.maxDistanceToSRBase = defaultSettings["max_distance_to_SR"] as! Double
         
        self.profitAvoidSameDirectionBase = defaultSettings["profit_avoid_same_direction_base"] as! Double
         
        self.oppositeLosingTradesToHalt = defaultSettings["opposite_losing_trades_to_halt"] as! Int
        
        self.losingConsecutiveTradesToHalt = defaultSettings["losing_trades_to_halt"] as! Int
        
        self.losingTradesToHalt = defaultSettings["losing_trades_to_halt"] as! Int
        
        self.drawdownLimit = defaultSettings["drawdown_limit"] as! Double
    }
    
    mutating func setRiskMultiplier(newValue: Double) throws {
        if newValue >= 1, newValue <= 10 {
            riskMultiplier = newValue
            return
        }
        
        throw ConfigError.riskMultiplierError
    }
    
    mutating func setMaxRisk(newValue: Double) throws {
        if newValue >= 2, newValue <= 50 {
            maxRiskBase = newValue
            return
        }
        
        throw ConfigError.maxRiskError
    }
    
    mutating func setMinStop(newValue: Double) throws {
        if newValue >= 2, newValue <= 10 {
            minStopBase = newValue
            return
        }
        
        throw ConfigError.minStopError
    }
    
    mutating func setSweetSpotMinDistance(newValue: Double) throws {
        if newValue >= 0.5, newValue <= 10 {
            sweetSpotBase = newValue
            return
        }
        
        throw ConfigError.sweetSpotMinDistanceError
    }
    
    mutating func setGreenBarsExit(newValue: Double) throws {
        if newValue >= 3 {
            greenExitBase = newValue
            return
        }
        
        throw ConfigError.greenBarsExitError
    }
    
    mutating func setSkipGreenBarsExit(newValue: Double) throws {
        if newValue > greenExitBase || newValue == 0 {
            skipGreenExitBase = newValue
            return
        }
        
        throw ConfigError.skipGreenBarsExitError
    }
    
    mutating func setEnterOnPullback(newValue: Double) throws {
        if newValue >= 10 {
            enterOnAnyPullbackBase = newValue
            return
        }
        
        throw ConfigError.enterOnPullbackError
    }
    
    mutating func setTakeProfitBarLength(newValue: Double) throws {
        if newValue >= 4 {
            takeProfitBarLengthBase = newValue
            return
        }
        
        throw ConfigError.takeProfitBarLengthError
    }
    
    mutating func setProfitToHalt(newValue: Double) throws {
        if newValue >= 20 || newValue == 0 {
            profitToHaltBase = newValue
            return
        }
        
        throw ConfigError.profitToHaltError
    }
    
    mutating func setOppositeLosingTradesToHalt(newValue: Int) throws {
        if newValue >= 3 || newValue == 0 {
            oppositeLosingTradesToHalt = newValue
            return
        }
        
        throw ConfigError.numOfLosingTradesError
    }
    
    mutating func setLosingTradesToHalt(newValue: Int) throws {
        if newValue >= 3 || newValue == 0 {
            losingTradesToHalt = newValue
            return
        }
        
        throw ConfigError.numOfLosingTradesError
    }
    
    mutating func setLosingConsecutiveTradesToHalt(newValue: Int) throws {
        if newValue >= 3 || newValue == 0 {
            losingConsecutiveTradesToHalt = newValue
            return
        }
        
        throw ConfigError.numOfLosingTradesError
    }
    
    mutating func setTradingStart(newValue: Date) throws {
        let newValue = newValue.stripYearMonthAndDay()
        if newValue < clearTime.stripYearMonthAndDay() {
            tradingStart = newValue
            return
        }
        
        throw ConfigError.tradingStartError
    }
    
    mutating func setTradingEnd(newValue: Date) throws {
        let newValue = newValue.stripYearMonthAndDay()
        if newValue > tradingStart.stripYearMonthAndDay(),
            newValue < clearTime.stripYearMonthAndDay() {
            tradingEnd = newValue
            return
        }
        
        throw ConfigError.tradingStartError
    }
    
    mutating func setLunchStart(newValue: Date) throws {
        let newValue = newValue.stripYearMonthAndDay()
        if newValue < lunchEnd.stripYearMonthAndDay() {
            lunchStart = newValue
            return
        }
        
        throw ConfigError.lunchStartError
    }
    
    mutating func setLunchEnd(newValue: Date) throws {
        let newValue = newValue.stripYearMonthAndDay()
        if newValue > lunchStart.stripYearMonthAndDay() {
            lunchEnd = newValue
            return
        }
        
        throw ConfigError.lunchStartError
    }
    
    mutating func setClearTime(newValue: Date) throws {
        let newValue = newValue.stripYearMonthAndDay()
        if newValue < flatTime, newValue > tradingStart {
            clearTime = newValue
            return
        }
        
        throw ConfigError.clearTimeError
    }
    
    mutating func setFlatTime(newValue: Date) throws {
        let newValue = newValue.stripYearMonthAndDay()
        if newValue > clearTime, newValue > tradingStart {
            flatTime = newValue
            return
        }
        
        throw ConfigError.flatTimeError
    }
    
    mutating func setFomcTime(newValue: Date) throws {
        let newValue = newValue.stripYearMonthAndDay()
        if newValue > tradingStart, newValue < tradingEnd {
            fomcTime = newValue
            return
        }
        
        throw ConfigError.fomcTimeError
    }
    
    mutating func setFomcDay(newValue: Bool) {
        fomcDay = newValue
    }
    
    mutating func setPositionSize(newValue: Int) throws {
        if newValue > 0 {
            positionSize = newValue
            return
        }
        
        throw ConfigError.positionSizeError
    }
    
    mutating func setMaxDailyLoss(newValue: Double) throws {
        if newValue <= -20 {
            maxDailyLossBase = newValue
            return
        }
        
        throw ConfigError.maxDailyLossError
    }
    
    mutating func setMaxDistanceToSR(newValue: Double) throws {
        if newValue >= 3.0 || newValue == 0.0 {
            maxDistanceToSRBase = newValue
            return
        }
        
        throw ConfigError.maxDistanceToSRError
    }
    
    mutating func setProfitAvoidSameDirection(newValue: Double) throws {
        if newValue >= 4.0 || newValue == 0.0 {
            profitAvoidSameDirectionBase = newValue
            return
        }
        
        throw ConfigError.profitAvoidSameDirectionError
    }
    
    mutating func setAvoidTakingSameTrade(newValue: Bool) {
        avoidTakingSameTrade = newValue
    }
    
    mutating func setAvoidTakingSameLosingTrade(newValue: Bool) {
        avoidTakingSameLosingTrade = newValue
    }
    
    mutating func setByPassTradingTimeRestrictions(newValue: Bool) {
        byPassTradingTimeRestrictions = newValue
    }
    
    mutating func setNoEntryDuringLunch(newValue: Bool) {
        noEntryDuringLunch = newValue
    }
    
    mutating func setSimulateTimePassage(newValue: Bool) {
        simulateTimePassage = newValue
    }
    
    mutating func setWaitForFinalizedSignals(newValue: Bool) {
        waitForFinalizedSignals = newValue
    }
    
    mutating func setBuffer(newValue: Double) throws {
        if newValue > 0 {
            buffer = newValue
            return
        }
        
        throw ConfigError.bufferError
    }
    
    mutating func setDrawdownLimit(newValue: Double) throws {
        if newValue >= 500 || newValue == 0 {
            drawdownLimit = newValue
            return
        }
        
        throw ConfigError.drawdownLimitError
    }
    
    func tradingTimeInterval(date: Date) -> DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components1 = DateComponents(year: date.year(),
                                         month: date.month(),
                                         day: date.day(),
                                         hour: tradingStart.hour(),
                                         minute: tradingStart.minute())
        let startDate: Date = calendar.date(from: components1)!
        let components2 = DateComponents(year: date.year(),
                                         month: date.month(),
                                         day: date.day(),
                                         hour: tradingEnd.hour(),
                                         minute: tradingEnd.minute())
        let endDate: Date = calendar.date(from: components2)!
        return DateInterval(start: startDate, end: endDate)
    }
    
    func lunchInterval(date: Date) -> DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components1 = DateComponents(year: date.year(),
                                         month: date.month(),
                                         day: date.day(),
                                         hour: lunchStart.hour(),
                                         minute:lunchStart.minute())
        let startDate: Date = calendar.date(from: components1)!
        let components2 = DateComponents(year: date.year(),
                                         month: date.month(),
                                         day: date.day(),
                                         hour: lunchEnd.hour(),
                                         minute: lunchEnd.minute())
        let endDate: Date = calendar.date(from: components2)!
        return DateInterval(start: startDate, end: endDate)
    }
    
    func fomcInterval(date: Date) -> DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components1 = DateComponents(year: date.year(),
                                         month: date.month(),
                                         day: date.day(),
                                         hour: fomcTime.hour(),
                                         minute: fomcTime.minute() - 30)
        let startDate: Date = calendar.date(from: components1)!
        let components2 = DateComponents(year: date.year(),
                                         month: date.month(),
                                         day: date.day(),
                                         hour: fomcTime.hour(),
                                         minute: fomcTime.minute() + 30)
        let endDate: Date = calendar.date(from: components2)!
        return DateInterval(start: startDate, end: endDate)
    }
    
    func clearPositionTime(date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components = DateComponents(year: date.year(),
                                        month: date.month(),
                                        day: date.day(),
                                        hour: clearTime.hour(),
                                        minute: clearTime.minute())
        let date: Date = calendar.date(from: components)!
        return date
    }
    

    func flatPositionsTime(date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components = DateComponents(year: date.year(),
                                        month: date.month(),
                                        day: date.day(),
                                        hour: flatTime.hour(),
                                        minute: flatTime.minute())
        let date: Date = calendar.date(from: components)!
        return date
    }
}
