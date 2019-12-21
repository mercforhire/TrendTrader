//
//  Signal.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-20.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

enum SignalColor {
    case green
    case blue
    case red
}

enum TradeDirection {
    case long
    case short
}

enum SignalInteval {
    case oneMin
    case twoMin
    case threeMin
}

struct Signal {
    var time: Date
    var color: SignalColor
    var stop: Double?
    var direction: TradeDirection?
    var inteval: SignalInteval
}
