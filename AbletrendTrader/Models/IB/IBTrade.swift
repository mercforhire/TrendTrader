//
//  IBTrade.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-28.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct IBTrade {
    var executionId: String
    var symbol: String
    var side: String
    var orderDescription: String
    var tradeTime: String
    var tradeTime_r: Int
    var size: String
    var price: String
    var submitter: String
    var exchange: String
    var comission: Int
    var netAmount: Int
    var account: String
    var secType: String
    var conidex: String
    var position: String
    var clearingId: String
    var clearingName: String
    var orderRef: String
}
