//
//  OrderResponse.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-01-16.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation

struct OrderResponse {
    var status: NTOrderStatus
    var size: Int
    var price: Double
    var time: Date
    
    var description: String {
        return "\(status.rawValue): \(time.hourMinuteSecond()), \(size) x \(price)"
    }
}
