//
//  PlacedOrderResponse.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-28.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct PlacedOrderResponse: Codable {
    var identifier: String
    var message: [String]
}
