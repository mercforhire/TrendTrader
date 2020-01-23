//
//  AuthStatusBuilder.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-29.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class AuthStatusBuilder {
    func buildAuthStatusFrom(_ jsonData : Data) -> AuthStatus? {
        let decoder: JSONDecoder = JSONDecoder()
        do {
            let status: AuthStatus? = try decoder.decode(AuthStatus.self, from: jsonData)
            return status
        }
        catch {
        }
        return nil
    }
}
