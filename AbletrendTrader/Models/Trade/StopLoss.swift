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
            return "Prev S/R"
        case .twoGreenBars:
            return "Green bars"
        case .currentBar:
            return "Cur S/R"
        }
    }
}

struct StopLoss {
    var stop: Double
    var source: StopLossSource
}
