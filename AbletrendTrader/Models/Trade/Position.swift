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
    
    var bars: [PriceBar]
    var stopLoss: StopLoss
    
    var entry: PriceBar {
        return bars.first!
    }
    var currentBar: PriceBar {
        return bars.last!
    }
    
    var securedProfit: Double {
        switch direction {
        case .long:
            return stopLoss.stop - entryPrice
        default:
            return entryPrice - stopLoss.stop
        }
    }
}
