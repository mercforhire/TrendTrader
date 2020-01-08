//
//  Position.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-22.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct Position {
    var direction: TradeDirection
    var size: Int
    var entryTime: Date
    var idealEntryPrice: Double
    var actualEntryPrice: Double?
    var stopLoss: StopLoss?
    
    var securedProfit: Double? {
        guard let stopLoss = stopLoss, let actualEntryPrice = actualEntryPrice else { return nil }
        
        switch direction {
        case .long:
            return stopLoss.stop - actualEntryPrice
        default:
            return actualEntryPrice - stopLoss.stop
        }
    }
}
