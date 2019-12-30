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
    
    var MaxRisk: Double = 10.0
    
    var MinBarStop: Double  = 5.0
    
    var SweetSpotMinDistance: Double  = 2.0
    // the max allowed distance from support to low of a series of green bar(s) followed by a blue bar
    
    var GreenBarsExit: Double = 5.0
    // the min profit the trade must in to use the 2 green bars exit rule
       
    var SkipGreenBarsExit: Double = 20.0
    // if the current profit(based on the currenty set stop) is higher than, we assume it's a big move and won't exit based on the 2 green bar rules
   
    var EnterOnPullback: Double = 20.0
    // if the previous trade profit is higher than this and got stopped out, we allow to enter on any pullback if no opposite signal on any timeframe is found from last trade to now
    
    var HighRiskStart: (Int, Int) = (9, 30) // Hour/Minute
    var HighRiskEnd: (Int, Int) = (10, 0) // Hour/Minute
    
    var ChartStart: (Int, Int) = (0, 0)
    var ChartEnd: (Int, Int) = (23, 59)
    
    var TradingStart: (Int, Int) = (9, 20)
    var TradingEnd: (Int, Int) = (15, 55)
    
    var ClearTime: (Int, Int) = (15, 59)
    var FlatTime: (Int, Int) = (16, 5)
    
    var MaxDailyLoss: Double = -50.0 // stop trading when P/L goes under this number
    
    var Ticker = "NQ"
    var ConId = 11004958
    var PositionSize: Int = 1
    
    let ByPassTradingTimeRestrictions = true
}
