//
//  Double+Extensions.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-26.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

extension Double {
    func round(nearest: Double) -> Double {
        let n = 1 / nearest
        let numberToRound = self * n
        return numberToRound.rounded() / n
    }

    func flooring(toNearest: Double) -> Double {
        return floor(self / toNearest) * toNearest
    }
    
    func ceiling(toNearest: Double) -> Double {
        return ceil(self / toNearest) * toNearest
    }
    
    func roundBasedOnDirection(direction: TradeDirection) -> Double {
        if direction == .long {
            return flooring(toNearest: 0.5)
        } else {
            return ceiling(toNearest: 0.5)
        }
    }
}
