//
//  Question.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-30.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct Question: Codable {
    var identifier: String
    var message: [String]
    
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case message = "message"
    }
}
