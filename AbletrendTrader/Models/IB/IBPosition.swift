//
//  IBPosition.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-30.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct IBPosition: Codable {
    var acctId: String
    var conid: Int
    var assetClass: String
    var position: Int
    var currency: String
    var avgPrice: Double
    var realizedPnl: Double
    var unrealizedPnl: Double
    
    var direction: TradeDirection {
        return position > 0 ? .long : .short
    }
    
    func toPosition() -> Position {
        return Position(direction: direction, size: abs(position), entryTime: nil, idealEntryPrice: avgPrice, actualEntryPrice: avgPrice, stopLoss: nil)
    }
}
