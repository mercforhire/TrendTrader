//
//  LiveOrdersResponse.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-29.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct LiveOrdersResponse: Codable {
    var orders: [LiveOrder]?
    var notifications: [String]?
}
