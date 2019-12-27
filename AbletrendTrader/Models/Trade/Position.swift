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
    var entryPrice: Double
    var stopLoss: StopLoss
    var entry: PriceBar
    var currentBar: PriceBar
    
    var securedProfit: Double {
        switch direction {
        case .long:
            return stopLoss.stop - entryPrice
        default:
            return entryPrice - stopLoss.stop
        }
    }
}
