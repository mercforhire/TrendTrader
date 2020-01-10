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
    var actualEntryPrice: Double
    var stopLoss: StopLoss?
    var entryOrderRef: String?
    
    var securedProfit: Double? {
        guard let stopLoss = stopLoss else { return nil }
        
        switch direction {
        case .long:
            return stopLoss.stop - idealEntryPrice
        default:
            return idealEntryPrice - stopLoss.stop
        }
    }
}
