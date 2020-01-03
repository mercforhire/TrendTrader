//
//  IBTrade.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-28.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct IBTrade: Codable {
    var symbol: String
    var side: String
    var tradeTime_r: Double
    var size: Int
    var price: String
    var commission: String
    var netAmount: Double
    var account: String
    var secType: String
    var conidex: String
    var orderRef: String
    var position: Int
    
    enum CodingKeys: String, CodingKey {
        case symbol = "symbol"
        case side = "side"
        case tradeTime_r = "trade_time_r"
        case size = "size"
        case price = "price"
        case commission = "commission"
        case netAmount = "net_amount"
        case account = "account"
        case secType = "sec_type"
        case conidex = "conidex"
        case orderRef = "order_ref"
        case position = "position"
    }
    
    var tradeTime: Date {
        return Date(timeIntervalSince1970: tradeTime_r / 1000)
    }
    
    var direction: TradeDirection {
        return side == "B" ? .long : .short
    }
}
