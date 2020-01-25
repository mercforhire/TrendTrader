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
    var coloredBars: [PriceBar] // cannot be empty
    
    var start: String {
        return greenBars.first?.identifier ?? coloredBars.first!.identifier
    }
    
    var end: String {
        return coloredBars.last!.identifier
    }
    
    func getHighestPoint() -> Double? {
        var allBars: [PriceBar] = []
        allBars.append(contentsOf: greenBars)
        allBars.append(contentsOf: coloredBars)
        let highestBar: PriceBar? = allBars.max { a, b in a.candleStick.high < b.candleStick.high }
        return highestBar?.candleStick.high
    }
    
    func getLowestPoint() -> Double? {
        var allBars: [PriceBar] = []
        allBars.append(contentsOf: greenBars)
        allBars.append(contentsOf: coloredBars)
        let lowestBar: PriceBar? = allBars.max { a, b in a.candleStick.low > b.candleStick.low }
        return lowestBar?.candleStick.low
    }
}
