//
//  Chart.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-20.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct Chart {
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
    
    // The last bar is always the second last bar in timeKeys, because the very last bar's signal is not finalized
    // Trading decisions must be made from the second last bar
    var lastBar: PriceBar? {
        guard timeKeys.count > 1 else { return nil }
        
        let lastBarKey = timeKeys[timeKeys.count - 2]
        let lastBar = priceBars[lastBarKey]
        return lastBar
    }
    
    var lastTimeKey: String? {
        guard timeKeys.count > 1 else { return nil }
        
        let lastBarKey = timeKeys[timeKeys.count - 2]
        return lastBarKey
    }
    
    func checkAllSameDirection(direction: TradeDirection, currBar: PriceBar, fromKey: String, toKey: String) -> Bool {
        guard let fromKeyIndex = timeKeys.firstIndex(of: fromKey),
            let toKeyIndex = timeKeys.firstIndex(of: toKey),
            fromKeyIndex < toKeyIndex else { return true }
        
        var opposite1MinDots = 0
        var opposite2MinCrosses = 0
        var opposite3MinCrosses = 0
        
        // toKeyIndex is the currentIndex, so skip comparing with itself by toKeyIndex-1
        for i in (fromKeyIndex...toKeyIndex-1).reversed() {
            let key = timeKeys[i]
            guard let bar = priceBars[key] else { continue }
            
            for signal in bar.signals {
                switch signal.inteval {
                case .oneMin:
                    if let signalDirection = signal.direction, signalDirection != direction {
                        opposite1MinDots += 1
                    }
                case .twoMin:
                    if let signalDirection = signal.direction, signalDirection != direction {
                        opposite2MinCrosses += 1
                    }
                case .threeMin:
                    if let signalDirection = signal.direction, signalDirection != direction {
                        opposite3MinCrosses += 1
                    }
                }
                if opposite1MinDots > 0 || opposite2MinCrosses > 2 || opposite3MinCrosses > 1 {
                    return false
                }
            }
        }
        
        return true
    }
    
    static func generateChart(candleSticks: [CandleStick], indicatorsSet: [Indicators]) -> Chart {
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
        
        let chart = Chart(timeKeys: keys, priceBars: timeVsPriceBars)
        return chart
    }
    
    func printSignalsDescription() {
        guard let latestBar = absLastBar,
            let currentDirection: TradeDirection = latestBar.oneMinSignal?.direction else { return }
        
        var latestBarWith1MinSignal: Date?
        var latestBarWith2MinSignal: Date?
        var latestBarWith3MinSignal: Date?
        
        for timekey in timeKeys.reversed() {
            guard let bar = priceBars[timekey] else { continue }
            
            if latestBarWith1MinSignal != nil {
                break
            }
            
            for signal in bar.signals where signal.inteval == .oneMin {
                if signal.direction != currentDirection {
                    break
                } else {
                    latestBarWith1MinSignal = bar.time
                }
            }
        }
        
        outerloop1: for timekey in timeKeys.reversed() {
            guard let bar = priceBars[timekey] else { continue }
            
            if latestBarWith2MinSignal != nil {
                break
            }
            
            for signal in bar.signals where signal.inteval == .twoMin {
                if signal.direction != currentDirection {
                    break outerloop1
                } else {
                    latestBarWith2MinSignal = bar.time
                }
            }
        }
        
        outerloop2: for timekey in timeKeys.reversed() {
            guard let bar = priceBars[timekey] else { continue }
            
            if latestBarWith3MinSignal != nil {
                break
            }
            
            for signal in bar.signals where signal.inteval == .threeMin {
                if signal.direction != currentDirection {
                    break outerloop2
                } else {
                    latestBarWith3MinSignal = bar.time
                }
            }
        }
        
        let log = String(format: "For bar %@: Latest 1m %@ Signal: %@, 2m Signal: %@, 3m Signal: %@",
                         latestBar.time.hourMinuteSecond(),
                         currentDirection.description(),
                         (latestBarWith1MinSignal?.hourMinute() ?? "--"),
                         (latestBarWith2MinSignal?.hourMinute() ?? "--"),
                         (latestBarWith3MinSignal?.hourMinute() ?? "--"))
        print(log)
    }
}
