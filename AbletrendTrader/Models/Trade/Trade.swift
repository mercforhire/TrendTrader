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
    
    var entryTime: Date?
    var idealEntryPrice: Double
    var actualEntryPrice: Double
    var entryOrderRef: String?
    var entrySnapshot: Chart?
    
    var exitTime: Date
    var idealExitPrice: Double
    var actualExitPrice: Double
    var exitOrderRef: String?
    var exitSnapshot: Chart?
    var exitMethod: ExitMethod
    
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
