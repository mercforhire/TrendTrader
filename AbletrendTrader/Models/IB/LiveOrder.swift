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
    var companyName: String
    var lastExecutionTime_r: Double
    var orderType: String
    var side: String
    var price: Double?
    var orderId: Int
    var status: String
}
