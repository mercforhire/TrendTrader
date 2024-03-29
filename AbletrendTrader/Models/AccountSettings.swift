//
//  AccountSettings.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-04-07.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation

struct AccountSettings: Codable, Equatable {
    var server1MinURL: String = "http://192.168.0.121:80/"
    var server2MinURL: String = "http://192.168.0.121:80/"
    var server3MinURL: String = "http://192.168.0.121:80/"
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
    var state: AccountState = AccountState()
    
    static func == (lhs: AccountSettings, rhs: AccountSettings) -> Bool {
        return
            lhs.server1MinURL == rhs.server1MinURL &&
            lhs.server2MinURL == rhs.server2MinURL &&
            lhs.server3MinURL == rhs.server3MinURL &&
            lhs.positionSize == rhs.positionSize &&
            lhs.commission == rhs.commission &&
            lhs.ticker == rhs.ticker &&
            lhs.pointValue == rhs.pointValue &&
            lhs.exchange == rhs.exchange &&
            lhs.accLongName == rhs.accLongName &&
            lhs.accName == rhs.accName &&
            lhs.basePath == rhs.basePath &&
            lhs.incomingPath == rhs.incomingPath &&
            lhs.outgoingPath == rhs.outgoingPath
    }
}
