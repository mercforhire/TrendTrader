//
//  StopLoss.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-23.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

enum StopLossSource {
    case supportResistanceLevel
    case twoGreenBars
    case currentBar
    
    func reason() -> String {
        switch self {
        case .supportResistanceLevel:
            return "Support Resistance Level"
        case .twoGreenBars:
            return "Two Green Bars"
        case .currentBar:
            return "Current bar"
        }
    }
}

struct StopLoss {
    var stop: Double
    var source: StopLossSource
}
