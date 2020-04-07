//
//  NTSettings.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-04-07.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation

struct NTSettings: Codable {
    var positionSize: Int = 1
    var commission: Double = 2.04
    var ticker: String = "NQ 06-20"
    var pointValue: Double = 20.0
    var exchange: String = "Globex"
    var accLongName: String = "NinjaTrader Continuum (Demo)"
    var accName: String = "Sim101"
    var basePath: String = "/Users/lchen/Downloads/NinjaTrader/"
    var incomingPath: String = "/Users/lchen/Downloads/NinjaTrader/incoming"
    var outgoingPath: String = "/Users/lchen/Downloads/NinjaTrader/outgoing"
}
