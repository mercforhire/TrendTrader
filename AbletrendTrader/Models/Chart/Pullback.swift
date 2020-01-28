//
//  SweetSpot.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-21.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

// A "Pullback" is
// A: one or more green bars followed by a blue bar
// B: one or more green bars followed by a red bar

struct Pullback {
    var direction: TradeDirection
    var greenBars: [PriceBar] // can be empty
    var coloredBar: PriceBar
    
    var start: String {
        return greenBars.first?.identifier ?? coloredBar.identifier
    }
    
    var end: String {
        return coloredBar.identifier
    }
    
    func getHighestPoint() -> Double? {
        var allBars: [PriceBar] = []
        allBars.append(contentsOf: greenBars)
        allBars.append(coloredBar)
        let highestBar: PriceBar? = allBars.max { a, b in a.candleStick.high < b.candleStick.high }
        return highestBar?.candleStick.high
    }
    
    func getLowestPoint() -> Double? {
        var allBars: [PriceBar] = []
        allBars.append(contentsOf: greenBars)
        allBars.append(coloredBar)
        let lowestBar: PriceBar? = allBars.max { a, b in a.candleStick.low > b.candleStick.low }
        return lowestBar?.candleStick.low
    }
}
