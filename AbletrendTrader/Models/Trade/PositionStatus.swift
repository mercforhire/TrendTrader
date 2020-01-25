//
//  PositionStatus.swift
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
        if position == 0 {
            return "No position"
        }
        return "Position: \(position), \(price)"
    }
}
