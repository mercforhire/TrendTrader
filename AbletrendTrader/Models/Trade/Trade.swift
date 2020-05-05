//
//  Trade.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-21.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct Trade: Codable {
    var direction: TradeDirection
    var simulated: Bool
    var size: Int
    var pointValue: Double
    var entryTime: Date
    var idealEntryPrice: Double
    var actualEntryPrice: Double
    var entryOrderRef: String?
    
    var exitTime: Date
    var idealExitPrice: Double
    var actualExitPrice: Double
    var exitOrderRef: String?
    var commission: Double
    var exitMethod: ExitMethod
    
    var idealProfit: Double {
        switch direction {
        case .long:
            return idealExitPrice - idealEntryPrice
        default:
            return idealEntryPrice - idealExitPrice
        }
    }
    
    var actualProfit: Double {
        switch direction {
        case .long:
            return (actualExitPrice - actualEntryPrice) * Double(size)
        default:
            return (actualEntryPrice - actualExitPrice) * Double(size)
        }
    }
    
    var actualProfitDollar: Double {
        switch direction {
        case .long:
            return (actualExitPrice - actualEntryPrice) * pointValue * Double(size) - commission
        default:
            return (actualEntryPrice - actualExitPrice) * pointValue * Double(size) - commission
        }
    }
}
