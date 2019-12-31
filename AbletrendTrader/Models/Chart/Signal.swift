//
//  Signal.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-20.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct Signal {
    var time: Date
    var color: SignalColor
    var stop: Double?
    var direction: TradeDirection?
    var inteval: SignalInteval
}
