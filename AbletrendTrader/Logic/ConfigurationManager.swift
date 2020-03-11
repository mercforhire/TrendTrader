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
    
    var riskMultiplier: Double
    var maxRisk: Double
    var minStop: Double
    
    // the max allowed distance from support to low of a series of green bar(s) followed by a blue bar
    var sweetSpotMinDistance: Double
    
    // the min profit the trade must in to use the 2 green bars exit rule
    var greenBarsExit: Double
    
    // if the current profit(based on the currenty set stop) is higher than, we assume it's a big move and won't exit based on the 2 green bar rules
    var skipGreenBarsExit: Double
    
    // if the previous trade profit is higher than this and got stopped out, we allow to enter on any pullback if no opposite signal on any timeframe is found from last trade to now
    var enterOnPullback: Double
    var takeProfitBarLength: Double
    var maxHighRiskEntryAllowed: Int
    var highRiskStart: Date
    var highRiskEnd: Date
    var tradingStart: Date
    var tradingEnd: Date
    var lunchStart: Date
    var lunchEnd: Date
    var clearTime: Date
    var flatTime: Date
    var positionSize: Int
    
    // stop trading when P/L goes under this number
    var maxDailyLoss: Double
    
    var byPassTradingTimeRestrictions : Bool
    var noEntryDuringLunch : Bool
    var simulateTimePassage : Bool
    

    
    var ntCommission: Double?
    var ntTicker: String?
    var ntName: String?
    var ntAccountLongName: String?
    var ntBasePath: String?
    var ntIncomingPath: String?
    var ntOutgoingPath: String?
    var ntAccountName: String?
    
    init() {
        let defaultSettings: NSDictionary = NSDictionary(contentsOfFile: Bundle.main.path(forResource: DefaultSettingsPlistFileName, ofType: "plist")!)!
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
        
        self.ntCommission = defaults.object(forKey: "nt_commission") as? Double
        
        self.ntTicker = defaults.object(forKey: "nt_ticker") as? String
        
        self.ntName = defaults.object(forKey: "nt_name") as? String
        
        self.ntAccountLongName = defaults.object(forKey: "nt_account_name") as? String
        
        self.ntBasePath = defaults.object(forKey: "nt_base_path") as? String
        
        self.ntIncomingPath = defaults.object(forKey: "nt_incoming_path") as? String
        
        self.ntOutgoingPath = defaults.object(forKey: "nt_outgoing_path") as? String
        
        self.ntAccountName = defaults.object(forKey: "nt_account_name") as? String
    }
}
