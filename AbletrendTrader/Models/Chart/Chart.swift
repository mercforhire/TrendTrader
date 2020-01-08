//
//  Chart.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-20.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation
import Charts

struct Chart {
    var ticker: String
    var timeKeys: [String] = []
    var priceBars: [String : PriceBar] = [:] // Key is an identifier generated from time of the bar
    
    var startTimeKey: String? {
        return timeKeys.first
    }
    
    var startBar: PriceBar? {
        guard let startTimeKey = startTimeKey, let firstBar = priceBars[startTimeKey] else { return nil }
        
        return firstBar
    }
    
    var startDate: Date? {
        return startBar?.time
    }
    
    var absLastBar: PriceBar? {
        guard timeKeys.count > 0 else { return nil }
        
        let lastBarKey = timeKeys[timeKeys.count - 1]
        let lastBar = priceBars[lastBarKey]
        return lastBar
    }
    
    var absLastBarDate: Date? {
        guard let absLastTimeKey = timeKeys.last, let absLastBar = priceBars[absLastTimeKey] else { return nil }
        
        return absLastBar.time
    }
    
    // The last bar is always the second last bar in timeKeys, because the last bar signals are not finalized.
    // Trading decisions must be made from the second last bar
    var lastBar: PriceBar? {
        guard timeKeys.count > 1 else { return nil }
        
        let lastBarKey = timeKeys[timeKeys.count - 2]
        let lastBar = priceBars[lastBarKey]
        return lastBar
    }
    
    var secondLastBar: PriceBar? {
        guard timeKeys.count > 2 else { return nil }
        
        let secondLastBarKey = timeKeys[timeKeys.count - 3]
        let secondLastBar = priceBars[secondLastBarKey]
        return secondLastBar
    }
    
    var lastTimeKey: String? {
        guard timeKeys.count > 1 else { return nil }
        
        let lastBarKey = timeKeys[timeKeys.count - 2]
        return lastBarKey
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
    
    func generateCandleStickData() -> [CandleChartDataEntry] {
        var candleSticks: [CandleChartDataEntry] = []
        
        var x: Double = 0.0
        for timeKey in timeKeys {
            guard let bar = priceBars[timeKey] else { continue }
            
            let candleStick: CandleChartDataEntry = bar.getCandleStickData(x: x)
            candleSticks.append(candleStick)
            
            x += 1
        }
        
        return candleSticks
    }
    
    static func generateChart(ticker: String, candleSticks: [CandleStick], indicatorsSet: [Indicators]) -> Chart? {
        var keys: [String] = []
        
        var timeVsCandleSticks: [String: CandleStick] = [:]
        
        for candleStick in candleSticks {
            let key = candleStick.time.generateDateIdentifier()
            timeVsCandleSticks[key] = candleStick
            keys.append(key)
        }
        
        var timeVsSignals: [String: [Signal]] = [:]
        
        for indicators in indicatorsSet {
            for signal in indicators.signals {
                let key = signal.time.generateDateIdentifier()
                if var existingSignals = timeVsSignals[key] {
                    existingSignals.append(signal)
                    timeVsSignals[key] = existingSignals
                } else {
                    timeVsSignals[key] = [signal]
                }
            }
        }
        
        var timeVsPriceBars: [String: PriceBar] = [:]
        
        for (key, candleStick) in timeVsCandleSticks {
            let signals: [Signal] = timeVsSignals[key] ?? []
            let priceBar = PriceBar(identifier: key, candleStick: candleStick, signals: signals)
            timeVsPriceBars[key] = priceBar
        }
        
        let chart = Chart(ticker: ticker, timeKeys: keys, priceBars: timeVsPriceBars)
        return chart
    }
}
