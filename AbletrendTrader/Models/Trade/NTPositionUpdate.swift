//
//  NTPositionUpdate.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-01-17.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation

struct PositionStatus {
    var position: Int
    var price: Double
    
    func status() -> String {
        return "Position Status: \(position), \(price)"
    }
    
    func toInitialPosition() -> Position? {
        if position == 0 { return nil }
        
        return Position(direction: position > 0 ? .long : .short,
                        size: abs(position),
                        entryTime: Date(),
                        idealEntryPrice: price,
                        actualEntryPrice: price,
                        stopLoss: nil,
                        entryOrderRef: nil,
                        commission: Config.shared.ntCommission)
    }
}
