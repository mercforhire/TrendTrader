//
//  ChartBuilder.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-20.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class ChartBuilder {
    func generateChart(ticker: String, candleSticks: [CandleStick], indicatorsSet: [Indicators], startTime: Date? = nil, cutOffTime: Date? = nil) -> Chart? {
        var keys: [String] = []
        
        var timeVsCandleSticks: [String: CandleStick] = [:]
        
        for candleStick in candleSticks {
            if let startTime = startTime, candleStick.time < startTime {
                continue
            }
            if let cutOffTime = cutOffTime, candleStick.time > cutOffTime {
                continue
            }
            
            let key = candleStick.time.generateDateIdentifier()
            timeVsCandleSticks[key] = candleStick
            keys.append(key)
        }
        
        var timeVsSignals: [String: [Signal]] = [:]
        
        for indicators in indicatorsSet {
            for signal in indicators.signals {
                if let startTime = startTime, signal.time < startTime {
                    continue
                }
                if let cutOffTime = cutOffTime, signal.time > cutOffTime {
                    continue
                }
                
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
