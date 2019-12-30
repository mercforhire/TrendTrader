//
//  IBTrade.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-28.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct IBTrade: Codable {
    var executionId: String
    var symbol: String
    var side: String
    var tradeTime: String
    var tradeTime_r: Int
    var size: String
    var price: String
    var comission: Int
    var netAmount: Int
    var account: String
    var secType: String
    var conidex: String
    var position: String
    
    enum CodingKeys: String, CodingKey {
        case executionId = "execution_id"
        case symbol = "symbol"
        case side = "side"
        case tradeTime = "trade_time"
        case tradeTime_r = "trade_time_r"
        case size = "size"
        case price = "price"
        case comission = "comission"
        case netAmount = "net_amount"
        case account = "account"
        case secType = "sec_type"
        case conidex = "conidex"
        case position = "position"
    }
}
