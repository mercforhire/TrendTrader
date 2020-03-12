//
//  IBPositionsBuilder.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-31.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class IBPositionsBuilder {
    func buildIBPositionsResponseFrom(_ jsonData : Data) -> [IBPosition]? {
        let decoder: JSONDecoder = JSONDecoder()
        do {
            let ibPositions = try decoder.decode([IBPosition]?.self, from: jsonData)
            return ibPositions
        }
        catch {
        }
        return nil
    }
}
