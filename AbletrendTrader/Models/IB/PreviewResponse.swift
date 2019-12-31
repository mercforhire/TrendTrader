//
//  PreviewResponse.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-31.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct Amount: Codable {
    var amount: String
    var commission: String
    var total: String
}

struct Change: Codable {
    var current: String
    var change: String
    var after: String
}

struct PreviewResponse: Codable {
    var amount: Amount
    var equity: Change
    var initial: Change
    var maintenance: Change
    var warn: String?
    var error: String?
}
