//
//  NTOrderResponse.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-01-16.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation

struct NTOrderResponse {
    var status: NTOrderStatus
    var size: Int
    var price: Double
    var time: Date
    
    var description: String {
        return "\(status): \(time), \(size) X \(price.currency())"
    }
}
