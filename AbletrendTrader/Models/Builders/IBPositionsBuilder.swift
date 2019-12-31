//
//  IBPositionsBuilder.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-31.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class IBPositionsBuilder {
    func buildErrorResponseFrom(_ jsonData : Data) -> [IBPosition]? {
        let decoder: JSONDecoder = JSONDecoder()
        do {
            let ibPositions = try decoder.decode([IBPosition]?.self, from: jsonData)
            return ibPositions
        }
        catch(let error) {
            print(error)
        }
        return nil
    }
}
