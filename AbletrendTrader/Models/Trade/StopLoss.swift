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
}

struct StopLoss {
    var stop: Double
    var source: StopLossSource
}
