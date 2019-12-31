//
//  IBPosition.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-30.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct IBPosition: Codable {
    var acctId: String
    var conid: Int
    var assetClass: String
    var position: Int
    var mktPrice: Double
    var mktValue: Double
    var currency: String
    var avgCost: Double
    var avgPrice: Double
    var realizedPnl: Double
    var unrealizedPnl: Double
}
