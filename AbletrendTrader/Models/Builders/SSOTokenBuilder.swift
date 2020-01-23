//
//  SSOTokenBuilder.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-29.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class SSOTokenBuilder {
    func buildSSOTokenFrom(_ jsonData : Data) -> SSOToken? {
        let decoder: JSONDecoder = JSONDecoder()
        do {
            let ssoToken: SSOToken? = try decoder.decode(SSOToken.self, from: jsonData)
            return ssoToken
        }
        catch {
        }
        return nil
    }
}
