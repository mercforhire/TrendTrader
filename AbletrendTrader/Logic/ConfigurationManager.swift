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
    
    private(set) var riskMultiplier: Double
    private(set) var maxRisk: Double
    private(set) var minStop: Double
    private(set) var sweetSpotMinDistance: Double // the max allowed distance from support to low of a series of green bar(s) followed by a blue bar
    private(set) var greenBarsExit: Double // the min profit the trade must in to use the 2 green bars exit rule
    private(set) var skipGreenBarsExit: Double // if the current profit(based on the currenty set stop) is higher than, we assume it's a big move and won't exit based on the 2 green bar rules
    private(set) var enterOnPullback: Double // if the previous trade profit is higher than this and got stopped out, we allow to enter on any pullback if no opposite signal on any timeframe is found from last trade to now
    private(set) var takeProfitBarLength: Double
    private(set) var maxHighRiskEntryAllowed: Int
    private(set) var highRiskStart: Date
    private(set) var highRiskEnd: Date
    private(set) var tradingStart: Date
    private(set) var tradingEnd: Date
    private(set) var lunchStart: Date
    private(set) var lunchEnd: Date
    private(set) var clearTime: Date
    private(set) var flatTime: Date
    private(set) var positionSize: Int
    private(set) var maxDailyLoss: Double // stop trading when P/L goes under this number
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
    
    init() {
        let defaultSettings: NSDictionary = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "DefaultSettings", ofType: "plist")!)!
        
        let riskMultiplier = defaults.object(forKey: "risk_multiplier") as? Double ?? defaultSettings["risk_multiplier"] as! Double
        
        self.riskMultiplier = riskMultiplier
        
        self.maxRisk = (defaults.object(forKey: "max_risk") as? Double ?? defaultSettings["max_risk"] as! Double) * riskMultiplier
        
        self.minStop = (defaults.object(forKey: "min_stop") as? Double ?? defaultSettings["min_stop"] as! Double) * riskMultiplier
        
        self.sweetSpotMinDistance = (defaults.object(forKey: "sweet_spot_min_distance") as? Double ?? defaultSettings["sweet_spot_min_distance"] as! Double) * riskMultiplier
        
        self.greenBarsExit = (defaults.object(forKey: "green_bars_exit") as? Double ?? defaultSettings["green_bars_exit"] as! Double) * riskMultiplier
        
        self.skipGreenBarsExit = (defaults.object(forKey: "skip_green_bars_exit") as? Double ?? defaultSettings["skip_green_bars_exit"] as! Double) * riskMultiplier
        
        self.enterOnPullback = (defaults.object(forKey: "enter_on_pullback") as? Double ?? defaultSettings["enter_on_pullback"] as! Double) * riskMultiplier
        
        self.takeProfitBarLength = (defaults.object(forKey: "take_profit_bar_length") as? Double ?? defaultSettings["take_profit_bar_length"] as! Double) * riskMultiplier
        
        self.maxHighRiskEntryAllowed = defaults.object(forKey: "max_high_risk_entry_allowed") as? Int ?? defaultSettings["max_high_risk_entry_allowed"] as! Int
        
        self.highRiskStart = defaults.object(forKey: "high_risk_start") as? Date ?? defaultSettings["high_risk_start"] as! Date
        
        self.highRiskEnd = defaults.object(forKey: "high_risk_end") as? Date ?? defaultSettings[ "high_risk_end"] as! Date
        
        self.tradingStart = defaults.object(forKey: "trading_start") as? Date ?? defaultSettings["trading_start"] as! Date
        
        self.tradingEnd = defaults.object(forKey: "trading_end") as? Date ?? defaultSettings["trading_end"] as! Date
        
        self.lunchStart = defaults.object(forKey: "lunch_start") as? Date ?? defaultSettings["lunch_start"] as! Date
        
        self.lunchEnd = defaults.object(forKey: "lunch_end") as? Date ?? defaultSettings["lunch_end"] as! Date
        
        self.clearTime = defaults.object(forKey: "clear_time") as? Date ?? defaultSettings["clear_time"] as! Date
        
        self.flatTime = defaults.object(forKey: "flat_time") as? Date ?? defaultSettings["flat_time"] as! Date
        
        self.positionSize = defaults.object(forKey: "position_size") as? Int ?? defaultSettings["position_size"] as! Int
        
        self.maxDailyLoss = (defaults.object(forKey: "max_daily_loss") as? Double ?? defaultSettings["max_daily_loss"] as! Double) * riskMultiplier
        
        self.byPassTradingTimeRestrictions = defaults.object(forKey: "bypass_trading_time_restrictions") as? Bool ?? defaultSettings["bypass_trading_time_restrictions"] as! Bool
        
        self.noEntryDuringLunch = defaults.object(forKey: "no_entry_during_lunch") as? Bool ?? defaultSettings["no_entry_during_lunch"] as! Bool
       
        self.simulateTimePassage = defaults.object(forKey: "simulate_time_passage") as? Bool ?? defaultSettings["simulate_time_passage"] as! Bool
        
        self.tickerValue = defaults.object(forKey: "ticker_value") as? Double ?? defaultSettings["ticker_value"] as! Double
        
        self.ntCommission = defaults.object(forKey: "nt_commission") as? Double ?? defaultSettings["nt_commission"] as! Double
        
        self.ntTicker = defaults.object(forKey: "nt_ticker") as? String
        
        self.ntExchange = defaults.object(forKey: "nt_exchange") as? String ?? defaultSettings["nt_exchange"] as! String
        
        self.ntAccountLongName = defaults.object(forKey: "nt_account_name") as? String
        
        self.ntAccountName = defaults.object(forKey: "nt_account_name") as? String
        
        self.ntBasePath = defaults.object(forKey: "nt_base_path") as? String
        
        self.ntIncomingPath = defaults.object(forKey: "nt_incoming_path") as? String
        
        self.ntOutgoingPath = defaults.object(forKey: "nt_outgoing_path") as? String
    }
    
    func setRiskMultiplier(newValue: Double) throws {
        if newValue >= 1, newValue <= 10 {
            riskMultiplier = newValue
            UserDefaults.standard.set(newValue, forKey: "risk_multiplier")
            UserDefaults.standard.synchronize()
            return
        }
        
        throw ConfigError.riskMultiplierError
    }
    
    func setMaxRisk(newValue: Double) throws {
        if newValue >= 2, newValue <= 20 {
            maxRisk = newValue
            UserDefaults.standard.set(newValue, forKey: "max_risk")
            UserDefaults.standard.synchronize()
        }
        
        throw ConfigError.maxRiskError
    }
    
    func setMinStop(newValue: Double) throws {
        if newValue >= 2, newValue <= 10 {
            minStop = newValue
            UserDefaults.standard.set(newValue, forKey: "min_stop")
            UserDefaults.standard.synchronize()
        }
        
        throw ConfigError.minStopError
    }
    
    func setSweetSpotMinDistance(newValue: Double) throws {
        if newValue >= 1, newValue <= 5 {
            sweetSpotMinDistance = newValue
            UserDefaults.standard.set(newValue, forKey: "sweet_spot_min_distance")
            UserDefaults.standard.synchronize()
        }
        
        throw ConfigError.sweetSpotMinDistanceError
    }
    
    func setGreenBarsExit(newValue: Double) throws {
        if newValue >= 5 {
            greenBarsExit = newValue
            UserDefaults.standard.set(newValue, forKey: "green_bars_exit")
            UserDefaults.standard.synchronize()
        }
        
        throw ConfigError.greenBarsExitError
    }
    
    func setSkipGreenBarsExit(newValue: Double) throws {
        if newValue > greenBarsExit {
            skipGreenBarsExit = newValue
            UserDefaults.standard.set(newValue, forKey: "skip_green_bars_exit")
            UserDefaults.standard.synchronize()
        }
        
        throw ConfigError.skipGreenBarsExitError
    }
    
    func setEnterOnPullback(newValue: Double) throws {
        if newValue >= 10 {
            enterOnPullback = newValue
            UserDefaults.standard.set(newValue, forKey: "enter_on_pullback")
            UserDefaults.standard.synchronize()
        }
        
        throw ConfigError.enterOnPullbackError
    }
    
    func setTakeProfitBarLength(newValue: Double) throws {
        if newValue >= 10 {
            takeProfitBarLength = newValue
            UserDefaults.standard.set(newValue, forKey: "take_profit_bar_length")
            UserDefaults.standard.synchronize()
        }
        
        throw ConfigError.takeProfitBarLengthError
    }
    
    func setMaxHighRiskEntryAllowed(newValue: Int) throws {
        if newValue >= 0 {
            maxHighRiskEntryAllowed = newValue
            UserDefaults.standard.set(newValue, forKey: "max_high_risk_entry_allowed")
            UserDefaults.standard.synchronize()
        }
        
        throw ConfigError.maxHighRiskEntryAllowedError
    }
    
    func setHighRiskStart(newValue: Date) throws {
        if newValue >= tradingStart, newValue < tradingEnd, newValue < highRiskEnd {
            highRiskStart = newValue
            UserDefaults.standard.set(newValue, forKey: "high_risk_start")
            UserDefaults.standard.synchronize()
        }
        
        throw ConfigError.highRiskStartError
    }
    
    func setHighRiskEnd(newValue: Date) throws {
        if newValue > highRiskStart, newValue < tradingEnd {
            highRiskEnd = newValue
            UserDefaults.standard.set(newValue, forKey: "high_risk_end")
            UserDefaults.standard.synchronize()
        }
        
        throw ConfigError.highRiskEndError
    }
    
    func setTradingStart(newValue: Date) throws {
        if newValue < tradingEnd {
            tradingStart = newValue
            UserDefaults.standard.set(newValue, forKey: "trading_start")
            UserDefaults.standard.synchronize()
        }
        
        throw ConfigError.tradingStartError
    }
    
    func setTradingEnd(newValue: Date) throws {
        tradingEnd = newValue
        UserDefaults.standard.set(newValue, forKey: "trading_end")
        UserDefaults.standard.synchronize()
    }
    
    func setLunchStart(newValue: Date) throws {
        lunchStart = newValue
        UserDefaults.standard.set(newValue, forKey: "lunch_start")
        UserDefaults.standard.synchronize()
    }
    
    func setLunchEnd(newValue: Date) throws {
        lunchEnd = newValue
        UserDefaults.standard.set(newValue, forKey: "lunch_end")
        UserDefaults.standard.synchronize()
    }
    
    func setClearTime(newValue: Date) throws {
        clearTime = newValue
        UserDefaults.standard.set(newValue, forKey: "clear_time")
        UserDefaults.standard.synchronize()
    }
    
    func setFlatTime(newValue: Date) throws {
        flatTime = newValue
        UserDefaults.standard.set(newValue, forKey: "flat_time")
        UserDefaults.standard.synchronize()
    }
    
    func setPositionSize(newValue: Int) throws {
        positionSize = newValue
        UserDefaults.standard.set(newValue, forKey: "position_size")
        UserDefaults.standard.synchronize()
    }
    
    func setMaxDailyLoss(newValue: Double) throws {
        maxDailyLoss = newValue
        UserDefaults.standard.set(newValue, forKey: "max_daily_loss")
        UserDefaults.standard.synchronize()
    }
    
    func setByPassTradingTimeRestrictions(newValue: Bool) throws {
        byPassTradingTimeRestrictions = newValue
        UserDefaults.standard.set(newValue, forKey: "bypass_trading_time_restrictions")
        UserDefaults.standard.synchronize()
    }
    
    func setNoEntryDuringLunch(newValue: Bool) throws {
        noEntryDuringLunch = newValue
        UserDefaults.standard.set(newValue, forKey: "no_entry_during_lunch")
        UserDefaults.standard.synchronize()
    }
    
    func setSimulateTimePassage(newValue: Bool) throws {
        simulateTimePassage = newValue
        UserDefaults.standard.set(newValue, forKey: "simulate_time_passage")
        UserDefaults.standard.synchronize()
    }
    
    func setNTCommission(newValue: Double) throws {
        ntCommission = newValue
        UserDefaults.standard.set(newValue, forKey: "nt_commission")
        UserDefaults.standard.synchronize()
    }
    
    func setNTTicker(newValue: String) throws {
        ntTicker = newValue
        UserDefaults.standard.set(newValue, forKey: "nt_ticker")
        UserDefaults.standard.synchronize()
    }
    
    func setNTExchange(newValue: String) throws {
        ntExchange = newValue
        UserDefaults.standard.set(newValue, forKey: "nt_name")
        UserDefaults.standard.synchronize()
    }
    
    func setNTAccountLongName(newValue: String) throws {
        ntAccountLongName = newValue
        UserDefaults.standard.set(newValue, forKey: "nt_account_name")
        UserDefaults.standard.synchronize()
    }
    
    func setNTBasePath(newValue: String) throws {
        ntBasePath = newValue
        UserDefaults.standard.set(newValue, forKey: "nt_base_path")
        UserDefaults.standard.synchronize()
    }
    
    func setNTIncomingPath(newValue: String) throws {
        ntIncomingPath = newValue
        UserDefaults.standard.set(newValue, forKey: "nt_incoming_path")
        UserDefaults.standard.synchronize()
    }
    
    func setNTOutgoingPath(newValue: String) throws {
        ntOutgoingPath = newValue
        UserDefaults.standard.set(newValue, forKey: "nt_outgoing_path")
        UserDefaults.standard.synchronize()
    }
    
    func setNTAccountName(newValue: String) throws {
        ntAccountName = newValue
        UserDefaults.standard.set(newValue, forKey: "nt_account_name")
        UserDefaults.standard.synchronize()
    }
    
    func setTickerValue(newValue: Double) throws {
        tickerValue = newValue
        UserDefaults.standard.set(newValue, forKey: "ticker_value")
        UserDefaults.standard.synchronize()
    }
}
