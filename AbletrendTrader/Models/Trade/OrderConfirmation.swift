//
//  OrderConfirmation.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-01-09.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation

struct OrderConfirmation {
    var price: Double
    var time: Date
    var orderId: String?
    var orderRef: String
    var stopOrderId: String?
    var commission: Double
    
    var description: String {
        return "\(orderId): \(time), \(price.currency())"
    }
}
