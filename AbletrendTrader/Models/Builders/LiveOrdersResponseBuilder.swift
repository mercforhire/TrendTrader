//
//  LiveOrdersResponseBuilder.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-29.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class LiveOrdersResponseBuilder {
    func buildAccountsFrom(_ jsonData : Data) -> LiveOrdersResponse? {
        let decoder: JSONDecoder = JSONDecoder()
        do {
            let liveOrdersResponse: LiveOrdersResponse? = try decoder.decode(LiveOrdersResponse?.self, from: jsonData)
            return liveOrdersResponse
        }
        catch(let error) {
            print("LiveOrdersResponseBuilder:")
            print(error)
            print(String(data: jsonData, encoding: .utf8))
        }
        return nil
    }
}
