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
    var timeKeys: [String] = []
    var priceBars: [String : PriceBar] = [:] // Key is an identifier generated from time of the bar
    
    var startBar: PriceBar? {
        guard let firstKey = timeKeys.first, let firstBar = priceBars[firstKey] else { return nil }
        
        return firstBar
    }
    
    var startDate: Date? {
        return startBar?.candleStick.time
    }
    
    var secondLastBar: PriceBar? {
        guard timeKeys.count > 1 else { return nil }
        
        let secondLastBarKey = timeKeys[timeKeys.count - 2]
        let secondLastBar = priceBars[secondLastBarKey]
        return secondLastBar
    }
    
    var lastBar: PriceBar? {
        guard let lastBarKey = timeKeys.last, let lastBar = priceBars[lastBarKey] else { return nil }
        
        return lastBar
    }
    
    var lastTimeStamp: String? {
        return timeKeys.last
    }
    
    func checkAllSameDirection(direction: TradeDirection, fromKey: String, toKey: String) -> Bool {
        guard let fromKeyIndex = timeKeys.firstIndex(of: fromKey),
            let toKeyIndex = timeKeys.firstIndex(of: toKey),
            fromKeyIndex <= toKeyIndex else { return false }
        
        for i in fromKeyIndex...toKeyIndex {
            let key = timeKeys[i]
            guard let bar = priceBars[key] else { continue }
            
            for signal in bar.signals {
                if let signalDirection = signal.direction, signalDirection != direction {
                    return false
                }
            }
        }
        
        return true
    }
}
