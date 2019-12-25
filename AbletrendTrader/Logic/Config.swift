//
//  Config.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-24.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class Config {
    static var MaxRisk: Double = 10.0 // in Points
    
    static var MinBarStop: Double  = 5.0
    
    static var SweetSpotMinDistance: Double  = 2.0
    // the max allowed distance from support to low of a series of green bar(s) followed by a blue bar
    
    static var MinProfitToUseTwoGreenBarsExit: Double = 5.0
       // the min profit the trade must in to use the 2 green bars exit rule
       
    static var ProfitRequiredAbandonTwoGreenBarsExit: Double = 20.0
    // if the current profit(based on the currenty set stop) is higher than, we assume it's a big move and won't exit based on the 2 green bar rules
   
    static var ProfitRequiredToReenterTradeonPullback: Double = 20.0
    // if the previous trade profit is higher than this and got stopped out, we allow to enter on any pullback if no opposite signal on any timeframe is found from last trade to now
    
    static var HighRiskEntryStartTime: (Int, Int) = (9, 30) // Hour/Minute
    static var HighRiskEntryEndTime: (Int, Int) = (10, 0) // Hour/Minute
    
    static var TradingSessionStartTime: (Int, Int) = (9, 20)
    static var TradingSessionEndTime: (Int, Int) = (16, 15)
    
    static var ClearPositionTime: (Int, Int) = (16, 0)
    static var FlatPositionsTime: (Int, Int) = (16, 10)
    
    static var MaxDailyLoss: Double = 50.0 // stop trading when P/L goes under this number
}
