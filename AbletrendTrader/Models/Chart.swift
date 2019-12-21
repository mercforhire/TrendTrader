//
//  Chart.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-20.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct Chart {
    var ticker: String
    var timeKeys: [String]
    var priceBars: [String : PriceBar] // Key is an identifier generated from time of the bar
}
