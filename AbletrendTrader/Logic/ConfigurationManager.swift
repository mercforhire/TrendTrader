//
//  ConfigurationManager.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-24.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class ConfigurationManager {
    static let shared = ConfigurationManager()
    private let defaults : UserDefaults = UserDefaults.standard
    private let IPRegex = #"http:\/\/\d{0,3}.\d{0,3}.\d{0,3}.\d{0,3}\/"#
    
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
        return sweetSpotBase * riskMultiplier
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
    
    private(set) var highRiskStart: Date
    private(set) var highRiskEnd: Date
    private(set) var tradingStart: Date
    private(set) var tradingEnd: Date
    private(set) var lunchStart: Date
    private(set) var lunchEnd: Date
    private(set) var clearTime: Date
    private(set) var flatTime: Date
    
    private(set) var maxHighRiskEntryAllowed: Int
    private(set) var positionSize: Int
    
    private(set) var byPassTradingTimeRestrictions : Bool
    private(set) var noEntryDuringLunch : Bool
    private(set) var simulateTimePassage : Bool
    private(set) var tickerValue: Double
    
    private(set) var ntCommission: Double
    private(set) var ntTicker: String?
    private(set) var ntExchange: String
    private(set) var ntAccountLongName: String?
    private(set) var ntAccountName: String?
    private(set) var ntBasePath: String?
    private(set) var ntIncomingPath: String?
    private(set) var ntOutgoingPath: String?
    
    private(set) var server1MinURL: String
    private(set) var server2MinURL: String
    private(set) var server3MinURL: String
    
    init() {
        let defaultSettings: NSDictionary = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "DefaultSettings", ofType: "plist")!)!
        
        let riskMultiplier = defaults.object(forKey: "risk_multiplier") as? Double ?? defaultSettings["risk_multiplier"] as! Double
        
        self.riskMultiplier = riskMultiplier
        
        self.maxRiskBase = defaults.object(forKey: "max_risk") as? Double ?? defaultSettings["max_risk"] as! Double
        
        self.minStopBase = defaults.object(forKey: "min_stop") as? Double ?? defaultSettings["min_stop"] as! Double
        
        self.sweetSpotBase = defaults.object(forKey: "sweet_spot_min_distance") as? Double ?? defaultSettings["sweet_spot_min_distance"] as! Double
        
        self.greenExitBase = defaults.object(forKey: "green_bars_exit") as? Double ?? defaultSettings["green_bars_exit"] as! Double
        
        self.skipGreenExitBase = defaults.object(forKey: "skip_green_bars_exit") as? Double ?? defaultSettings["skip_green_bars_exit"] as! Double
        
        self.enterOnAnyPullbackBase = defaults.object(forKey: "enter_on_pullback") as? Double ?? defaultSettings["enter_on_pullback"] as! Double
        
        self.takeProfitBarLengthBase = defaults.object(forKey: "take_profit_bar_length") as? Double ?? defaultSettings["take_profit_bar_length"] as! Double
        
        self.maxHighRiskEntryAllowed = defaults.object(forKey: "max_high_risk_entry_allowed") as? Int ?? defaultSettings["max_high_risk_entry_allowed"] as! Int
        
        self.highRiskStart = (defaults.object(forKey: "high_risk_start") as? Date ?? defaultSettings["high_risk_start"] as! Date).stripYearMonthAndDay()
        
        self.highRiskEnd = (defaults.object(forKey: "high_risk_end") as? Date ?? defaultSettings[ "high_risk_end"] as! Date).stripYearMonthAndDay()
        
        self.tradingStart = (defaults.object(forKey: "trading_start") as? Date ?? defaultSettings["trading_start"] as! Date).stripYearMonthAndDay()
        
        self.tradingEnd = (defaults.object(forKey: "trading_end") as? Date ?? defaultSettings["trading_end"] as! Date).stripYearMonthAndDay()
        
        self.lunchStart = (defaults.object(forKey: "lunch_start") as? Date ?? defaultSettings["lunch_start"] as! Date).stripYearMonthAndDay()
        
        self.lunchEnd = (defaults.object(forKey: "lunch_end") as? Date ?? defaultSettings["lunch_end"] as! Date).stripYearMonthAndDay()
        
        self.clearTime = (defaults.object(forKey: "clear_time") as? Date ?? defaultSettings["clear_time"] as! Date).stripYearMonthAndDay()
        
        self.flatTime = (defaults.object(forKey: "flat_time") as? Date ?? defaultSettings["flat_time"] as! Date).stripYearMonthAndDay()
        
        self.positionSize = defaults.object(forKey: "position_size") as? Int ?? defaultSettings["position_size"] as! Int
        
        self.maxDailyLossBase = defaults.object(forKey: "max_daily_loss") as? Double ?? defaultSettings["max_daily_loss"] as! Double
        
        self.byPassTradingTimeRestrictions = defaults.object(forKey: "bypass_trading_time_restrictions") as? Bool ?? defaultSettings["bypass_trading_time_restrictions"] as! Bool
        
        self.noEntryDuringLunch = defaults.object(forKey: "no_entry_during_lunch") as? Bool ?? defaultSettings["no_entry_during_lunch"] as! Bool
       
        self.simulateTimePassage = defaults.object(forKey: "simulate_time_passage") as? Bool ?? defaultSettings["simulate_time_passage"] as! Bool
        
        self.tickerValue = defaults.object(forKey: "ticker_value") as? Double ?? defaultSettings["ticker_value"] as! Double
        
        self.ntCommission = defaults.object(forKey: "nt_commission") as? Double ?? defaultSettings["nt_commission"] as! Double
        
        self.ntTicker = defaults.object(forKey: "nt_ticker") as? String
        
        self.ntExchange = defaults.object(forKey: "nt_exchange") as? String ?? defaultSettings["nt_exchange"] as! String
        
        self.ntAccountLongName = defaults.object(forKey: "nt_account_long_name") as? String
        
        self.ntAccountName = defaults.object(forKey: "nt_account_name") as? String
        
        self.ntBasePath = defaults.object(forKey: "nt_base_path") as? String
        
        self.ntIncomingPath = defaults.object(forKey: "nt_incoming_path") as? String
        
        self.ntOutgoingPath = defaults.object(forKey: "nt_outgoing_path") as? String
        
        self.server1MinURL = defaults.object(forKey: "server_1min_url") as? String ?? defaultSettings["default_ip"] as! String
        
        self.server2MinURL = defaults.object(forKey: "server_2min_url") as? String ?? defaultSettings["default_ip"] as! String
        
        self.server3MinURL = defaults.object(forKey: "server_3min_url") as? String ?? defaultSettings["default_ip"] as! String
    }
    
    func setServer1MinURL(newValue: String) throws {
        if newValue.range(of: IPRegex, options: .regularExpression) != nil {
            server1MinURL = newValue
            saveToDefaults(newValue: newValue, key: "server_1min_url")
            return
        }
        
        throw ConfigError.serverURLError
    }
    
    func setServer2MinURL(newValue: String) throws {
        if newValue.range(of: IPRegex, options: .regularExpression) != nil {
            server2MinURL = newValue
            saveToDefaults(newValue: newValue, key: "server_2min_url")
            return
        }
        
        throw ConfigError.serverURLError
    }
    
    func setServer3MinURL(newValue: String) throws {
        if newValue.range(of: IPRegex, options: .regularExpression) != nil {
            server3MinURL = newValue
            saveToDefaults(newValue: newValue, key: "server_3min_url")
            return
        }
        
        throw ConfigError.serverURLError
    }
    
    func setRiskMultiplier(newValue: Double) throws {
        if newValue >= 1, newValue <= 10 {
            riskMultiplier = newValue
            saveToDefaults(newValue: newValue, key: "risk_multiplier")
            return
        }
        
        throw ConfigError.riskMultiplierError
    }
    
    func setMaxRisk(newValue: Double) throws {
        if newValue >= 2, newValue <= 50 {
            maxRiskBase = newValue
            saveToDefaults(newValue: newValue, key: "max_risk")
            return
        }
        
        throw ConfigError.maxRiskError
    }
    
    func setMinStop(newValue: Double) throws {
        if newValue >= 2, newValue <= 10 {
            minStopBase = newValue
            saveToDefaults(newValue: newValue, key: "min_stop")
            return
        }
        
        throw ConfigError.minStopError
    }
    
    func setSweetSpotMinDistance(newValue: Double) throws {
        if newValue >= 1, newValue <= 5 {
            sweetSpotBase = newValue
            saveToDefaults(newValue: newValue, key: "sweet_spot_min_distance")
            return
        }
        
        throw ConfigError.sweetSpotMinDistanceError
    }
    
    func setGreenBarsExit(newValue: Double) throws {
        if newValue >= 5 {
            greenExitBase = newValue
            saveToDefaults(newValue: newValue, key: "green_bars_exit")
            return
        }
        
        throw ConfigError.greenBarsExitError
    }
    
    func setSkipGreenBarsExit(newValue: Double) throws {
        if newValue > greenExitBase {
            skipGreenExitBase = newValue
            saveToDefaults(newValue: newValue, key: "skip_green_bars_exit")
            return
        }
        
        throw ConfigError.skipGreenBarsExitError
    }
    
    func setEnterOnPullback(newValue: Double) throws {
        if newValue >= 10 {
            enterOnAnyPullbackBase = newValue
            saveToDefaults(newValue: newValue, key: "enter_on_pullback")
            return
        }
        
        throw ConfigError.enterOnPullbackError
    }
    
    func setTakeProfitBarLength(newValue: Double) throws {
        if newValue >= 10 {
            takeProfitBarLengthBase = newValue
            saveToDefaults(newValue: newValue, key: "take_profit_bar_length")
            return
        }
        
        throw ConfigError.takeProfitBarLengthError
    }
    
    func setMaxHighRiskEntryAllowed(newValue: Int) throws {
        if newValue >= 0 {
            maxHighRiskEntryAllowed = newValue
            saveToDefaults(newValue: newValue, key: "max_high_risk_entry_allowed")
            return
        }
        
        throw ConfigError.maxHighRiskEntryAllowedError
    }
    
    func setHighRiskStart(newValue: Date) throws {
        let newValue = newValue.stripYearMonthAndDay()
        if newValue >= tradingStart.stripYearMonthAndDay(),
            newValue < tradingEnd.stripYearMonthAndDay(),
            newValue < highRiskEnd.stripYearMonthAndDay() {
            highRiskStart = newValue
            saveToDefaults(newValue: newValue, key: "high_risk_start")
            return
        }
        
        throw ConfigError.highRiskStartError
    }
    
    func setHighRiskEnd(newValue: Date) throws {
        let newValue = newValue.stripYearMonthAndDay()
        if newValue > highRiskStart.stripYearMonthAndDay(), newValue < tradingEnd.stripYearMonthAndDay() {
            highRiskEnd = newValue
            saveToDefaults(newValue: newValue, key: "high_risk_end")
            return
        }
        
        throw ConfigError.highRiskEndError
    }
    
    func setTradingStart(newValue: Date) throws {
        let newValue = newValue.stripYearMonthAndDay()
        if newValue < tradingEnd.stripYearMonthAndDay() {
            tradingStart = newValue
            saveToDefaults(newValue: newValue, key: "trading_start")
            return
        }
        
        throw ConfigError.tradingStartError
    }
    
    func setTradingEnd(newValue: Date) throws {
        let newValue = newValue.stripYearMonthAndDay()
        if newValue > tradingStart.stripYearMonthAndDay() {
            tradingEnd = newValue
            saveToDefaults(newValue: newValue, key: "trading_end")
            return
        }
        
        throw ConfigError.tradingEndError
    }
    
    func setLunchStart(newValue: Date) throws {
        let newValue = newValue.stripYearMonthAndDay()
        if newValue < lunchEnd.stripYearMonthAndDay() {
            lunchStart = newValue
            saveToDefaults(newValue: newValue, key: "lunch_start")
            return
        }
        
        throw ConfigError.lunchStartError
    }
    
    func setLunchEnd(newValue: Date) throws {
        let newValue = newValue.stripYearMonthAndDay()
        if newValue > lunchStart.stripYearMonthAndDay() {
            lunchEnd = newValue
            saveToDefaults(newValue: newValue, key: "lunch_end")
            return
        }
        
        throw ConfigError.lunchStartError
    }
    
    func setClearTime(newValue: Date) throws {
        let newValue = newValue.stripYearMonthAndDay()
        if newValue < flatTime, newValue > tradingStart {
            clearTime = newValue
            saveToDefaults(newValue: newValue, key: "clear_time")
            return
        }
        
        throw ConfigError.clearTimeError
    }
    
    func setFlatTime(newValue: Date) throws {
        let newValue = newValue.stripYearMonthAndDay()
        if newValue > clearTime, newValue > tradingStart {
            flatTime = newValue
            saveToDefaults(newValue: newValue, key: "flat_time")
            return
        }
        
        throw ConfigError.flatTimeError
    }
    
    func setPositionSize(newValue: Int) throws {
        if newValue > 0 {
            positionSize = newValue
            saveToDefaults(newValue: newValue, key: "position_size")
            return
        }
        
        throw ConfigError.positionSizeError
    }
    
    func setMaxDailyLoss(newValue: Double) throws {
        if newValue <= -20 {
            maxDailyLossBase = newValue
            saveToDefaults(newValue: newValue, key: "max_daily_loss")
            return
        }
        
        throw ConfigError.maxDailyLossError
    }
    
    func setByPassTradingTimeRestrictions(newValue: Bool) {
        byPassTradingTimeRestrictions = newValue
        saveToDefaults(newValue: newValue, key: "bypass_trading_time_restrictions")
    }
    
    func setNoEntryDuringLunch(newValue: Bool) {
        noEntryDuringLunch = newValue
        saveToDefaults(newValue: newValue, key: "no_entry_during_lunch")
    }
    
    func setSimulateTimePassage(newValue: Bool) {
        simulateTimePassage = newValue
        saveToDefaults(newValue: newValue, key: "simulate_time_passage")
    }
    
    func setNTCommission(newValue: Double) throws {
        if newValue >= 0 {
            ntCommission = newValue
            saveToDefaults(newValue: newValue, key: "nt_commission")
            return
        }
        
        throw ConfigError.ntCommissionError
    }
    
    func setNTTicker(newValue: String) throws {
        if newValue.count > 0 {
            ntTicker = newValue
            saveToDefaults(newValue: newValue, key: "nt_ticker")
            return
        }
        
        throw ConfigError.ntTickerError
    }
    
    func setNTExchange(newValue: String) throws {
        if newValue.count > 0 {
            ntExchange = newValue
            saveToDefaults(newValue: newValue, key: "nt_exchange")
            return
        }
        
        throw ConfigError.ntExchangeError
    }
    
    func setNTAccountLongName(newValue: String) throws {
        if newValue.count > 0 {
            ntAccountLongName = newValue
            saveToDefaults(newValue: newValue, key: "nt_account_long_name")
            return
        }
        
        throw ConfigError.ntAccountLongNameError
    }
    
    func setNTBasePath(newValue: String) throws {
        if newValue.count > 0 {
            ntBasePath = newValue
            saveToDefaults(newValue: newValue, key: "nt_base_path")
            return
        }
        
        throw ConfigError.ntBasePathError
    }
    
    func setNTIncomingPath(newValue: String) throws {
        if newValue.count > 0 {
            ntIncomingPath = newValue
            saveToDefaults(newValue: newValue, key: "nt_incoming_path")
            return
        }
        
        throw ConfigError.ntIncomingPathError
    }
    
    func setNTOutgoingPath(newValue: String) throws {
        if newValue.count > 0 {
            ntOutgoingPath = newValue
            saveToDefaults(newValue: newValue, key: "nt_outgoing_path")
            return
        }
        
        throw ConfigError.ntOutgoingPathError
    }
    
    func setNTAccountName(newValue: String) throws {
        if newValue.count > 0 {
            ntAccountName = newValue
            saveToDefaults(newValue: newValue, key: "nt_account_name")
            return
        }
        
        throw ConfigError.ntAccountNameError
    }
    
    func setTickerValue(newValue: Double) throws {
        if newValue >= 1 {
            tickerValue = newValue
            saveToDefaults(newValue: newValue, key: "ticker_value")
            return
        }
        
        throw ConfigError.tickerValueError
    }
    
    private func saveToDefaults(newValue: Any, key: String) {
        UserDefaults.standard.set(newValue, forKey: key)
        UserDefaults.standard.synchronize()
        print("Saved value:", newValue, "to key", key)
    }
}
