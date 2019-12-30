//
//  PlacedOrderResponseBuilder.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-29.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class PlacedOrderResponseBuilder {
    func buildAccountsFrom(_ jsonData : Data) -> PlacedOrderResponse? {
        let decoder: JSONDecoder = JSONDecoder()
        let orderResponse: PlacedOrderResponse? = try? decoder.decode(PlacedOrderResponse?.self, from: jsonData)
        return orderResponse
    }
}
