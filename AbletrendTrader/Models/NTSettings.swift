//
//  NTSettings.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-04-07.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation

struct NTSettings: Codable {
    var commission: Double
    var ticker: String
    var pointValue: Double
    var exchange: String
    var accLongName: String
    var accName: String
    var basePath: String
    var incomingPath: String
    var outgoingPath: String
}
