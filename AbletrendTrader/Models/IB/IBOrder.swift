//
//  IBOrder.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-28.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct IBOrder {
    var acct: String
    var conid: Int
    var orderDesc: String
    var description1: String
    var ticker: String
    var secType: String
    var listingExchange: String
    var remainingQuantity: String
    var filledQuantity: String
    var companyName: String
    var status: String
    var origOrderType: String
    var side: String
    var price: Int
    var orderId: Int
    var parentId: Int
    var orderRef: String
}
