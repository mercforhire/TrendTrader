//
//  PlacedOrderResponse.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-01-07.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation

struct PlacedOrderResponse: Codable {
    var orderId: String
    var orderStatus: String
    var localOrderId: String?
    var parentOrderId: String?
    
    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case orderStatus = "order_status"
        case localOrderId = "local_order_id"
        case parentOrderId = "parent_order_id"
    }
}
