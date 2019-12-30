//
//  IBTradesBuilder.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-29.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class IBTradesBuilder {
    func buildIBTradesFrom(_ jsonData : Data) -> [IBTrade]? {
        let decoder: JSONDecoder = JSONDecoder()
        let trades: [IBTrade]? = try? decoder.decode([IBTrade]?.self, from: jsonData)
        return trades
    }
}
