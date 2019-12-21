//
//  Trader.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-21.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class Trader {
    var chart: Chart
    
    init(chart: Chart) {
        self.chart = chart
    }
    
    func findEntrySignals(direction: TradeDirection) -> [PriceBar] {
        var entryBars: [PriceBar] = []
        var entryTimes: [String] = []
        
        var lastOneMinSupportTime: String?
        var lastTwoMinSupportTime: String?
        var lastThreeMinSupportTime: String?
        
        var currentlyInATrade: Bool = false
        for timeKey in chart.timeKeys {
            guard let priceBar: PriceBar = chart.priceBars[timeKey] else { continue }
            
            for signal in priceBar.signals {
                // if detect a opposite signal, we invalidate all last know support times and exit any ongoing long position
                if let signalDirection = signal.direction, signalDirection != direction {
                    switch signal.inteval {
                    case .oneMin:
                        lastOneMinSupportTime = nil
                    case .twoMin:
                        lastTwoMinSupportTime = nil
                    case .threeMin:
                        lastThreeMinSupportTime = nil
                    }
                    currentlyInATrade = false
                    break
                }
                
                if signal.direction == direction {
                    switch signal.inteval {
                    case .oneMin:
                        lastOneMinSupportTime = timeKey
                    case .twoMin:
                        lastTwoMinSupportTime = timeKey
                    case .threeMin:
                        lastThreeMinSupportTime = timeKey
                    }
                }
            }
            
            // if not in an existing position, all support on all 3 timeframes are detected, and the color of the bar is correct, we have a buy signal
            if !currentlyInATrade,
                let _ = lastOneMinSupportTime,
                let _ = lastTwoMinSupportTime,
                let _ =  lastThreeMinSupportTime {
                
                switch direction {
                case .long:
                    if priceBar.getOneMinSignal()?.color == .blue {
                        entryTimes.append(timeKey)
                        currentlyInATrade = true
                    }
                default:
                    if priceBar.getOneMinSignal()?.color == .red {
                        entryTimes.append(timeKey)
                        currentlyInATrade = true
                    }
                }
            }
        }
        
        for entryTime in entryTimes {
            guard let priceBar = chart.priceBars[entryTime] else { continue }
            
            entryBars.append(priceBar)
        }
        
        return entryBars
    }
}
