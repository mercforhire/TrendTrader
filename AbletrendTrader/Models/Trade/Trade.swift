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
    var idealEntryPrice: Double
    var actualEntryPrice: Double
    var idealExitPrice: Double
    var actualExitPrice: Double
    var exitMethod: ExitMethod
    var entryTime: Date?
    var exitTime: Date
    var entrySnapshot: Chart?
    var exitSnapshot: Chart?
    
    var idealProfit: Double? {
        switch direction {
        case .long:
            return idealExitPrice - idealEntryPrice
        default:
            return idealEntryPrice - idealExitPrice
        }
    }
    
    var actualProfit: Double? {
        switch direction {
        case .long:
            return actualExitPrice - actualEntryPrice
        default:
            return actualEntryPrice - actualExitPrice
        }
    }
}
