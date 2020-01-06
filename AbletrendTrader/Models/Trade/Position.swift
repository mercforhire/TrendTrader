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
    var entryTime: Date?
    var entryPrice: Double
    var stopLoss: StopLoss?
    
    var securedProfit: Double? {
        guard let stopLoss = stopLoss else { return nil }
        
        switch direction {
        case .long:
            return stopLoss.stop - entryPrice
        default:
            return entryPrice - stopLoss.stop
        }
    }
}
