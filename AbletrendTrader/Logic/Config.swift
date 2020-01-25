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
    
//    let dataServerURL: String = "http://192.168.1.103/"
    let dataServerURL: String = "http://192.168.43.190/"
    let fileName1: String = "1m.txt" // filename for local sandbox folder
    let fileName2: String = "2m.txt" // filename for local sandbox folder
    let fileName3: String = "3m.txt" // filename for local sandbox folder
    
    let maxRisk: Double = 10.0
    let minBarStop: Double = 5.0
    let sweetSpotMinDistance: Double  = 1.5 // the max allowed distance from support to low of a series of green bar(s) followed by a blue bar
    let greenBarsExit: Double = 5.0 // the min profit the trade must in to use the 2 green bars exit rule
    let skipGreenBarsExit: Double = 25.0 // if the current profit(based on the currenty set stop) is higher than, we assume it's a big move and won't exit based on the 2 green bar rules
    let enterOnPullback: Double = 20.0 // if the previous trade profit is higher than this and got stopped out, we allow to enter on any pullback if no opposite signal on any timeframe is found from last trade to now
    
    let highRiskStart: (Int, Int) = (9, 30) // Hour/Minute
    let highRiskEnd: (Int, Int) = (9, 59) // Hour/Minute
    
    let tradingStart: (Int, Int) = (9, 30) // Hour/Minute
    let tradingEnd: (Int, Int) = (15, 55) // Hour/Minute
    
    let lunchStart: (Int, Int) = (11, 59) // Hour/Minute
    let lunchEnd: (Int, Int) = (13, 29) // Hour/Minute
    
    let clearTime: (Int, Int) = (15, 59) // Hour/Minute
    let flatTime: (Int, Int) = (16, 5) // Hour/Minute
    
    let tickerPointValue = 20.0
    let positionSize: Int = 1
    let maxDailyLoss = -50.0 // stop trading when P/L goes under this number
    
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
    
    // DEMO SETTINGS:
    let liveTradingMode: LiveTradingMode = .ninjaTrader
    var byPassTradingTimeRestrictions = false // DEFAULT: false
    var noEntryDuringLunch = true
    let simulateTimePassage = true // DEFAULT: true
}
