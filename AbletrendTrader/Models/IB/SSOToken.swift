//
//  SSOToken.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-28.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct SSOToken: Codable {
    var userId: Int
    var userName: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "USER_ID"
        case userName = "USER_NAME"
    }
}
