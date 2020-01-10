//
//  IBOrder.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-28.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct LiveOrder: Codable {
    var acct: String
    var conid: Int
    var orderDesc: String
    var ticker: String
    var remainingQuantity: Int
    var filledQuantity: Int
    var lastExecutionTime_r: Double
    var orderType: String
    var side: String
    var auxPrice: String?
    var orderId: Int
    var order_ref: String
    var status: String
    
    var direction: TradeDirection {        
        return side == "BUY" ? .long : .short
    }
    
    var lastExecutionTime: Date {
        return Date(timeIntervalSince1970: lastExecutionTime_r / 1000)
    }
}
