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
    var entry: PriceBar
    var entryPrice: Double
    var currentBar: PriceBar
    var stopLoss: Double
    
    var securedProfit: Double {
        switch direction {
        case .long:
            return stopLoss - entryPrice
        default:
            return entryPrice - stopLoss
        }
    }
}
