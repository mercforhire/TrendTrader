//
//  PlacedOrderResponseBuilder.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-01-07.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation

class PlacedOrderResponseBuilder {
    func buildPlacedOrderResponseFrom(_ jsonData : Data) -> [PlacedOrderResponse]? {
        let decoder: JSONDecoder = JSONDecoder()
        do {
            let placedOrderResponses = try decoder.decode([PlacedOrderResponse].self, from: jsonData)
            return placedOrderResponses
        }
        catch {
        }
        return nil
    }
}
