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
    
    private let DefaultSettingsPlistFileName : String = "DefaultSettings"
    private let NTCommissionKey : String = "nt_commission"
    private let SimulateTimePassageKey : String = "simulate_time_passage"
    private let NoEntryDuringLunchKey : String = "no_entry_during_lunch"
    private let BypassTradingTimeRestrictionsKey : String = "bypass_trading_time_restrictions"
    private let MaxDailyLossKey : String = "max_daily_loss"
    private let PositionSizeKey : String = "position_size"
    private let TickerValueKey : String = "ticker_value"
    private let ClearTimeKey : String = "clear_time"
    private let FlatTimeKey : String = "flat_time"
    private let LunchStartKey : String = "lunch_start"
    private let LunchEndKey : String = "lunch_end"
    private let TradingStartKey : String = "trading_start"
    private let TradingEndKey : String = "trading_end"
    private let MaxHighRiskEntryAllowedKey : String = "max_high_risk_entry_allowed"
    private let HighRiskStartKey : String = "high_risk_start"
    private let HighRiskEndKey : String = "high_risk_end"
    private let TakeProfitBarLengthKey : String = "take_profit_bar_length"
    private let EnterOnPullbackKey : String = "enter_on_pullback"
    private let SkipGreenBarsExitKey : String = "skip_green_bars_exit"
    private let GreenBarsExitKey : String = "green_bars_exit"
    private let SweetSpotMinDistanceKey : String = "sweet_spot_min_distance"
    private let MinStopKey : String = "min_stop"
    private let MaxRiskKey : String = "max_risk"
    private let RiskMultiplierKey : String = "risk_multiplier"
    
    private let defaultSettings : NSDictionary

    init()
    {
        defaultSettings = NSDictionary(contentsOfFile: Bundle.main.path(forResource: DefaultSettingsPlistFileName, ofType: "plist")!)!
    }
    
    let dataServerURL: String = "http://192.168.0.107/"
    
    var riskMultiplier: Double { defaultSettings[RiskMultiplierKey] as! Double }
    
    var maxRisk: Double { defaultSettings[MaxRiskKey] as! Double * riskMultiplier }
    
    var minStop: Double { defaultSettings[MinStopKey] as! Double * riskMultiplier }
    
    // the max allowed distance from support to low of a series of green bar(s) followed by a blue bar
    var sweetSpotMinDistance: Double { defaultSettings[SweetSpotMinDistanceKey] as! Double * riskMultiplier }
    
    // the min profit the trade must in to use the 2 green bars exit rule
    var greenBarsExit: Double { defaultSettings[GreenBarsExitKey] as! Double * riskMultiplier }
    
    // if the current profit(based on the currenty set stop) is higher than, we assume it's a big move and won't exit based on the 2 green bar rules
    var skipGreenBarsExit: Double { defaultSettings[SkipGreenBarsExitKey] as! Double * riskMultiplier }
    
    // if the previous trade profit is higher than this and got stopped out, we allow to enter on any pullback if no opposite signal on any timeframe is found from last trade to now
    var enterOnPullback: Double  { defaultSettings[EnterOnPullbackKey] as! Double * riskMultiplier }
    
    var takeProfitBarLength: Double { defaultSettings[TakeProfitBarLengthKey] as! Double * riskMultiplier }
    
    let highRiskStart: (Int, Int) = (9, 30) // Hour/Minute
    let highRiskEnd: (Int, Int) = (9, 55) // Hour/Minute
    
    var maxHighRiskEntryAllowed: Int { defaultSettings[MaxHighRiskEntryAllowedKey] as! Int }
    
    let tradingStart: (Int, Int) = (9, 30) // Hour/Minute
    let tradingEnd: (Int, Int) = (15, 55) // Hour/Minute
    
    let lunchStart: (Int, Int) = (12, 00) // Hour/Minute
    let lunchEnd: (Int, Int) = (13, 50) // Hour/Minute
    
    let clearTime: (Int, Int) = (15, 59) // Hour/Minute
    let flatTime: (Int, Int) = (16, 5) // Hour/Minute
    
    let tickerPointValue = 20.0
    let positionSize: Int = 1
    
    // stop trading when P/L goes under this number
    var maxDailyLoss: Double { defaultSettings[MaxHighRiskEntryAllowedKey] as! Double * riskMultiplier }
    
    let ticker = "NQ"
    let conId = 346577750
    
    let maxIBActionRetryTimes = 3
    let ibCommission = 2.05
    
    let ntCommission = 1.60
    let ntTicker = "NQ 03-20"
    let ntName = "Globex"
    let ntAccountLongName = "NinjaTrader Continuum (Demo)"
    var ntBasePath = "/Users/lchen/Downloads/NinjaTrader/"
    var ntIncomingPath = "/Users/lchen/Downloads/NinjaTrader/incoming"
    var ntOutgoingPath = "/Users/lchen/Downloads/NinjaTrader/outgoing"
    var ntAccountName = "Sim101"
    
    let liveTradingMode: LiveTradingMode = .ninjaTrader
    var byPassTradingTimeRestrictions = false // DEFAULT: false
    var noEntryDuringLunch = true // DEFAULT: true
    let simulateTimePassage = false // DEFAULT: true
}
