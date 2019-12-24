//
//  Session.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-23.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

// Stores all the information of a trading session
// The Trader will use the saved info here to decide the next trade

struct Session {
    var startTime: Date
    var cutOffTime: Date
    var trades: [Trade] = []
    var currentPosition: Position?
    
    func getTotalPAndL() -> Double {
        var pAndL: Double = 0
        
        for trade in trades {
            pAndL = pAndL + (trade.profit ?? 0)
        }
        
        return pAndL
    }
}
