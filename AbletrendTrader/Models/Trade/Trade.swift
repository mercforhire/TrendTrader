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
    var entry: PriceBar
    var exit: PriceBar
    
    var profit: Double? {
        switch direction {
        case .long:
            return exitPrice - entryPrice
        default:
            return entryPrice - exitPrice
        }
    }
    
    func summary() -> String {
        var summary: String = ""
        
        switch direction {
        case .long:
            summary = String(format: "Initial buy at %@ - %.2f", entry.identifier, entryPrice)
        default:
            summary = String(format: "Initial short at %@ - %.2f", entry.identifier, entryPrice)
        }
        
        return summary + String(format: " closed at %@ - %.2f with P/L %.2f reason %@", exit.identifier, exitPrice, profit ?? 0, exitMethod.reason())
    }
}
