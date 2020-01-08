//
//  Trade.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-21.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct Trade {
    var direction: TradeDirection
    var entryPrice: Double // enter at the close of the bar
    var exitPrice: Double
    var exitMethod: ExitMethod
    var entryTime: Date?
    var exitTime: Date
    
    var profit: Double? {
        switch direction {
        case .long:
            return exitPrice - entryPrice
        default:
            return entryPrice - exitPrice
        }
    }
}
