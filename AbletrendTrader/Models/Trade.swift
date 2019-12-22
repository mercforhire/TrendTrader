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
    var entry: PriceBar // enter at the close of the bar
    var entryPrice: Double
    var exit: PriceBar // exit during or at the close of this bar
    var exitPrice: Double
    
    var profit: Double? {
        switch direction {
        case .long:
            return exitPrice - entryPrice
        default:
            return entryPrice - exitPrice
        }
    }
}
