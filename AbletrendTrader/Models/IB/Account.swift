//
//  Account.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-28.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct Account: Codable {
    var identifier: String // id
    var accountId: String
    var accountTitle: String
    var currency: String
    var type: String
    
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case accountId = "accountId"
        case accountTitle = "accountTitle"
        case currency = "currency"
        case type = "type"
    }
}
