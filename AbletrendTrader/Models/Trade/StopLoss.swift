//
//  StopLoss.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-23.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct StopLoss {
    var stop: Double
    var source: StopLossSource
    var stopOrder: LiveOrder?
}
