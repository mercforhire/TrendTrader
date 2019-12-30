//
//  AuthStatus.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-28.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct AuthStatus: Codable {
    var authenticated: Bool // authenticated
    var connected: Bool  // connected
    var message: String // message
    var fail: String // fail
}
