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
    
    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case orderStatus = "order_status"
    }
}
