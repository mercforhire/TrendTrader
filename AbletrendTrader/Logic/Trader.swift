//
//  Trader.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-21.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class Trader {
    private let MaxRisk: Double = 10.0 // in Points
    private let SweetSpotMinDistance = 1 // the max allowed distance from support to low of a series of green bar(s) followed by a blue bar
    
    private var timeIntervalForHighRiskEntry: DateInterval!
    
    var chart: Chart
    
    init(chart: Chart) {
        self.chart = chart
        
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(abbreviation: "EST")!
        let components = DateComponents(year: chart.startDate?.year(), month: chart.startDate?.month(), day: chart.startDate?.day(), hour: 9, minute: 30)
        let startDate: Date = calendar.date(from: components)!
        self.timeIntervalForHighRiskEntry = DateInterval(start: startDate, duration: 30 * 60) // 30 minutes
    }
    
    func findEntrySignals(direction: TradeDirection, start: PriceBar) -> [PriceBar] {
        guard let startIndex = chart.timeKeys.firstIndex(of: start.identifier) else {
            return []
        }
        
        var entryBars: [PriceBar] = []
        var entryTimes: [String] = []
        
        var lastOneMinSupportTime: String?
        var lastTwoMinSupportTime: String?
        var lastThreeMinSupportTime: String?
        
        var currentlyInATrade: Bool = false
        for i in 0..<chart.timeKeys.count {
            let timeKey = chart.timeKeys[i]
            guard let priceBar: PriceBar = chart.priceBars[timeKey] else { continue }
            
            if timeIntervalForHighRiskEntry.contains(priceBar.candleStick.time) {
                print(priceBar.identifier, " is within timeIntervalForHighRiskEntry")
            } else {
                print(priceBar.identifier, " is outside timeIntervalForHighRiskEntry")
            }
            
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
            
            // if not in an existing position, all support on all 3 timeframes are detected, and the color of the bar is correct, we have a signal
            if !currentlyInATrade,
                let _ = lastOneMinSupportTime,
                let _ = lastTwoMinSupportTime,
                let _ =  lastThreeMinSupportTime,
                startIndex <= i {
                
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
    
    // given an entry Position and direction of the trade, find when the trade should end
    func findExitPoint(direction: TradeDirection, entryBar: PriceBar, entryPrice: Double) -> Trade? {
        guard let startIndex = chart.timeKeys.firstIndex(of: entryBar.identifier) else {
            return nil
        }
        
        var position: Position = Position(direction: direction, entry: entryBar, entryPrice: entryPrice, currentBar: entryBar, stopLoss: 0)
        var exitPrice: Double?
        outerLoop: for i in startIndex..<chart.timeKeys.count {
            guard let currentPriceBar = chart.priceBars[chart.timeKeys[i]] else { continue }
            
            // if we reached the end of the file, set the exitBar to the last priceBar
            if i == chart.timeKeys.count - 1 {
                position.currentBar = currentPriceBar
                exitPrice = currentPriceBar.candleStick.close
            }
            
            // Rule 0: exit when the the low of the price hit the current stop loss
            switch direction {
            case .long:
                if currentPriceBar.candleStick.low <= position.stopLoss {
                    position.currentBar = currentPriceBar
                    exitPrice = position.stopLoss
                    break outerLoop
                }
            default:
                if currentPriceBar.candleStick.high >= position.stopLoss {
                    position.currentBar = currentPriceBar
                    exitPrice = position.stopLoss
                    break outerLoop
                }
            }
            
            // Rule 1: exit when bar of opposite color bar appears
            
            // keep searching for a bar of opposite color
            switch direction {
            case .long:
                if currentPriceBar.getOneMinSignal()?.color == .red {
                    position.currentBar = currentPriceBar
                    exitPrice = currentPriceBar.candleStick.close
                    break outerLoop
                }
            default:
                if currentPriceBar.getOneMinSignal()?.color == .blue {
                    position.currentBar = currentPriceBar
                    exitPrice = currentPriceBar.candleStick.close
                    break outerLoop
                }
            }
            
            // Rule 2: exit the price has hit the previous resistence/support level
        }
        
        if let exitPrice = exitPrice {
            let trade: Trade = Trade(direction: direction, entry: entryBar, entryPrice: entryPrice, exit: position.currentBar, exitPrice: exitPrice)
            return trade
        }
        
        return nil
    }
    
    
    func calculateStopLoss(direction: TradeDirection, entryBar: PriceBar) -> Double {
        // Go with the methods in order. If the stoploss is > MaxRisk, go to the next method
        // Worst case would be method 3 and still having stoploss > MaxRisk, either skip the trade or apply a hard stop at the MaxRisk
        
        // Method 1: previous resistence/support level
        // Method 2: current resistence/support level plus or minus 1 depending on direction
        // Method 3: current bar's high plus 1 or low, minus 1 depending on direction
        
        // Method 1 and 2:
        let previousLevel: Double = findPreviousLevel(direction: direction, entryBar: entryBar)
        if previousLevel <= MaxRisk {
            return previousLevel
        }
        
        // Method 3:
        switch direction {
        case .long:
            return entryBar.candleStick.low - 1
        default:
            return entryBar.candleStick.high + 1
        }
    }
    
    // given an entry bar and direction of the trade, find the previous resistence/support level, if none exists, use the current one +-1
    func findPreviousLevel(direction: TradeDirection, entryBar: PriceBar, minimalDistance: Double = 1) -> Double {
        guard let startIndex = chart.timeKeys.firstIndex(of: entryBar.identifier),
            let initialBarStop = entryBar.getOneMinSignal()?.stop,
            entryBar.getOneMinSignal()?.direction == direction else {
            return -1
        }
        
        var previousLevel: Double = initialBarStop
        let timeKeysUpToIncludingStartIndex = chart.timeKeys[0...startIndex]
        
        outerLoop: for timeKey in timeKeysUpToIncludingStartIndex.reversed() {
            guard let currentPriceBar = chart.priceBars[timeKey] else { continue }
            
            if currentPriceBar.getOneMinSignal()?.direction != direction {
                break
            } else if let level = currentPriceBar.getOneMinSignal()?.stop {
                switch direction {
                case .long:
                    if previousLevel - level > minimalDistance {
                        previousLevel = level
                        break outerLoop
                    }
                default:
                    if level - previousLevel > minimalDistance {
                        previousLevel = level
                        break outerLoop
                    }
                }
            }
        }
        
        if previousLevel == initialBarStop {
            switch direction {
            case .long:
                previousLevel = previousLevel - 1
            default:
                previousLevel = previousLevel + 1
            }
        }
        
        return previousLevel
    }
    
    // given a starting and end price bar, find the 2 consecutive bars with the highest "low"
    func findPairOfGreenBarsWithHighestLow(start: PriceBar, end: PriceBar) -> (PriceBar, PriceBar)? {
        guard let startIndex = chart.timeKeys.firstIndex(of: start.identifier),
            let endIndex = chart.timeKeys.firstIndex(of: end.identifier),
            startIndex < endIndex else {
            return nil
        }
        
        var indexOfTheFirstBar: Int?
        var highestLow: Double?
        
        for i in startIndex..<endIndex {
            // skip any pair bars that are not green
            guard let leftBar = chart.priceBars[chart.timeKeys[i]],
                let rightBar = chart.priceBars[chart.timeKeys[i + 1]],
                leftBar.getOneMinSignal()?.color == .green,
                rightBar.getOneMinSignal()?.color == .green else {
                continue
            }
            
            // found a pair of green bars:
            
            // if no green pair have been found yet, save this pair as the default
            if indexOfTheFirstBar == nil && highestLow == nil {
                indexOfTheFirstBar = i
                highestLow = max(leftBar.candleStick.low, rightBar.candleStick.low)
            }
            // if the highestLow found so far is lower than this new pair's highest "low", update the data
            else if let highestLowSoFar = highestLow, max(leftBar.candleStick.low, rightBar.candleStick.low) > highestLowSoFar {
                indexOfTheFirstBar = i
                highestLow = max(leftBar.candleStick.low, rightBar.candleStick.low)
            }
        }
        
        if let indexOfTheFirstBar = indexOfTheFirstBar,
            let leftBar: PriceBar = chart.priceBars[chart.timeKeys[indexOfTheFirstBar]],
            let rightBar = chart.priceBars[chart.timeKeys[indexOfTheFirstBar + 1]] {
            return (leftBar, rightBar)
        }
        
        return nil
    }
    
    // given a starting and end price bar, find the 2 consecutive bars with the lowest "high"
    func findPairOfGreenBarsWithLowestHigh(start: PriceBar, end: PriceBar) -> (PriceBar, PriceBar)? {
        guard let startIndex = chart.timeKeys.firstIndex(of: start.identifier),
            let endIndex = chart.timeKeys.firstIndex(of: end.identifier),
            startIndex < endIndex else {
            return nil
        }
        
        var indexOfTheFirstBar: Int?
        var lowestHigh: Double?
        
        for i in startIndex..<endIndex {
            // skip any pair bars that are not green
            guard let leftBar = chart.priceBars[chart.timeKeys[i]],
                let rightBar = chart.priceBars[chart.timeKeys[i + 1]],
                leftBar.getOneMinSignal()?.color == .green,
                rightBar.getOneMinSignal()?.color == .green else {
                continue
            }
            
            // found a pair of green bars:
            
            // if no green pair have been found yet, save this pair as the default
            if indexOfTheFirstBar == nil && lowestHigh == nil {
                indexOfTheFirstBar = i
                lowestHigh = max(leftBar.candleStick.low, rightBar.candleStick.low)
            }
            // if the lowest high found so far is higher than this new pair's lowest "high", update the data
            else if let lowestHighSoFar = lowestHigh, min(leftBar.candleStick.high, rightBar.candleStick.high) < lowestHighSoFar {
                indexOfTheFirstBar = i
                lowestHigh = min(leftBar.candleStick.high, rightBar.candleStick.high)
            }
        }
        
        if let indexOfTheFirstBar = indexOfTheFirstBar,
            let leftBar: PriceBar = chart.priceBars[chart.timeKeys[indexOfTheFirstBar]],
            let rightBar = chart.priceBars[chart.timeKeys[indexOfTheFirstBar + 1]] {
            return (leftBar, rightBar)
        }
        
        return nil
    }
    
    // find all 'SweetSpot's within the range based on the given trade direction
    func findSweetSpots(start: PriceBar, end: PriceBar, direction: TradeDirection) -> [SweetSpot] {
        guard let startIndex = chart.timeKeys.firstIndex(of: start.identifier),
            let endIndex = chart.timeKeys.firstIndex(of: end.identifier),
            startIndex < endIndex else {
            return []
        }
        
        var sweetSpots: [SweetSpot] = []
        var greenBarSegment: [PriceBar] = []
        for i in startIndex..<endIndex {
            guard let priceBar = chart.priceBars[chart.timeKeys[i]] else {
                continue
            }
            
            if priceBar.getOneMinSignal()?.color != .green,
                !greenBarSegment.isEmpty {
                
                switch direction {
                case .long:
                    // check if the next bar is blue
                    if priceBar.getOneMinSignal()?.color == .blue {
                        let sweetSpot = SweetSpot(direction: direction, greenBars: greenBarSegment, coloredBar: priceBar)
                        sweetSpots.append(sweetSpot)
                    }
                default:
                    // bheck if the next bar is red
                    if priceBar.getOneMinSignal()?.color == .red {
                        let sweetSpot = SweetSpot(direction: direction, greenBars: greenBarSegment, coloredBar: priceBar)
                        sweetSpots.append(sweetSpot)
                    }
                }
                
                greenBarSegment = []
            } else if priceBar.getOneMinSignal()?.color == .green {
                greenBarSegment.append(priceBar)
            }
        }
        
        return sweetSpots
    }
    
    // find series of descending green bars with the lowest low
    // IE: 5,6,4,3,2,1,2,4,5
    // the lowest series of descending numbers is 6,4,3,2,1
    func findLowestSeriesOfDescendingGreenBars(priceBars: [PriceBar]) -> [PriceBar] {
        // find the lowest bar first and move left from there
        
        let priceBarsSorted = priceBars.sorted { (left, right) -> Bool in
            return left.candleStick.low < right.candleStick.low
        }
        
        guard let lowestBar: PriceBar = priceBarsSorted.first else {
            return []
        }
        
        var lowestSeriesOfDescendingGreenBars: [PriceBar] = []
        var lowestBarIndex: Int = priceBars.firstIndex { (priceBar) -> Bool in
            return priceBar.identifier == lowestBar.identifier
            } ?? 0
        
        while lowestBarIndex >= 0 {
            if lowestSeriesOfDescendingGreenBars.isEmpty {
                lowestSeriesOfDescendingGreenBars.append(priceBars[lowestBarIndex])
            } else if let firstDescendingBar = lowestSeriesOfDescendingGreenBars.first,
                priceBars[lowestBarIndex].candleStick.low > firstDescendingBar.candleStick.low {
                lowestSeriesOfDescendingGreenBars.insert(priceBars[lowestBarIndex], at: 0)
            } else if let firstDescendingBar = lowestSeriesOfDescendingGreenBars.first,
                priceBars[lowestBarIndex].candleStick.low < firstDescendingBar.candleStick.low {
                break
            }
            
            lowestBarIndex -= 1
        }
        
        return lowestSeriesOfDescendingGreenBars
    }
    
    // find series of ascending green bars with the highest high
    // IE: 5,6,4,3,2,1,2,4,5
    // the highest series of ascending numbers is 1,2,4,5
    func findHighestSeriesOfAscendingGreenBars(priceBars: [PriceBar]) -> [PriceBar] {
        // find the highest bar first and move left from there
        
        let priceBarsSorted = priceBars.sorted { (left, right) -> Bool in
            return left.candleStick.high > right.candleStick.high
        }
        
        guard let highestBar: PriceBar = priceBarsSorted.first else {
            return []
        }
        
        var highestSeriesOfAscendingGreenBars: [PriceBar] = []
        var highestBarIndex: Int = priceBars.firstIndex { (priceBar) -> Bool in
            return priceBar.identifier == highestBar.identifier
            } ?? 0
        
        while highestBarIndex >= 0 {
            if highestSeriesOfAscendingGreenBars.isEmpty {
                highestSeriesOfAscendingGreenBars.append(priceBars[highestBarIndex])
            } else if let firstAscendingBar = highestSeriesOfAscendingGreenBars.first,
                priceBars[highestBarIndex].candleStick.high < firstAscendingBar.candleStick.high {
                highestSeriesOfAscendingGreenBars.insert(priceBars[highestBarIndex], at: 0)
            } else if let firstAscendingBar = highestSeriesOfAscendingGreenBars.first,
                priceBars[highestBarIndex].candleStick.high > firstAscendingBar.candleStick.high {
                break
            }
            
            highestBarIndex -= 1
        }
        
        return highestSeriesOfAscendingGreenBars
    }
}
