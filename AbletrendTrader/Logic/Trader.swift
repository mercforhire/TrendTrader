//
//  Trader.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-21.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

enum EntryType {
    // for all 3 entries, the price must be above 1 min support or under 1 min resistance
    case aggressive // enter on any blue/red bar
    case pullBack // enter on any blue/red bar followed by one or more green bars
    case sweetSpot // enter on pullback that bounced/almost bounced off the S/R level
}

class Trader {
    private let MaxRisk: Double = 10.0 // in Points
    private let SweetSpotMinDistance = 1
    // the max allowed distance from support to low of a series of green bar(s) followed by a blue bar
    
    private let TimeIntervalForHighRiskEntry: DateInterval!
    // the time interval where it's allowed to enter trades that has a stop > 10, Default: 9:30 am to 10 am
    
    private let MinProfitToUseTwoGreenBarsExit: Double = 5.0
    // the min profit the trade must in to use the 2 green bars exit rule
    
    private let ProfitRequiredAbandonTwoGreenBarsExit: Double = 20.0
    // if the current profit(based on the currenty set stop) is higher than, we assume it's a big move and won't exit based on the 2 green bar rules

    
    var chart: Chart
    
    init(chart: Chart) {
        self.chart = chart
        
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(abbreviation: "EST")!
        let components = DateComponents(year: chart.startDate?.year(), month: chart.startDate?.month(), day: chart.startDate?.day(), hour: 9, minute: 30)
        let startDate: Date = calendar.date(from: components)!
        self.TimeIntervalForHighRiskEntry = DateInterval(start: startDate, duration: 30 * 60) // 30 minutes
    }
    
    // return a Position object if the given bar presents a entry signal
//    func findEntrySignal(direction: TradeDirection, bar: PriceBar, entryType: EntryType = .pullBack) -> Position? {
//        guard let startIndex = chart.timeKeys.firstIndex(of: bar.identifier) else {
//            return nil
//        }
//
//        // Strategy: From startIndex, look back and find the last bar where all 3 timeframes' signal align
//
//        var entryTimes: [String] = []
//
//        var lastOneMinSupportTime: String?
//        var lastTwoMinSupportTime: String?
//        var lastThreeMinSupportTime: String?
//
//        var currentlyInATrade: Bool = false
//        for i in 0..<chart.timeKeys.count {
//            let timeKey = chart.timeKeys[i]
//            guard let priceBar: PriceBar = chart.priceBars[timeKey] else { continue }
//
//
//
//            for signal in priceBar.signals {
//                // if detect a opposite signal, we invalidate all last know support times and exit any ongoing long position
//                if let signalDirection = signal.direction, signalDirection != direction {
//                    switch signal.inteval {
//                    case .oneMin:
//                        lastOneMinSupportTime = nil
//                    case .twoMin:
//                        lastTwoMinSupportTime = nil
//                    case .threeMin:
//                        lastThreeMinSupportTime = nil
//                    }
//                    currentlyInATrade = false
//                    break
//                }
//
//                if signal.direction == direction {
//                    switch signal.inteval {
//                    case .oneMin:
//                        lastOneMinSupportTime = timeKey
//                    case .twoMin:
//                        lastTwoMinSupportTime = timeKey
//                    case .threeMin:
//                        lastThreeMinSupportTime = timeKey
//                    }
//                }
//            }
//
//            // if not in an existing position, all support on all 3 timeframes are detected, and the color of the bar is correct, we have a signal
//            if !currentlyInATrade,
//                let _ = lastOneMinSupportTime,
//                let _ = lastTwoMinSupportTime,
//                let _ =  lastThreeMinSupportTime,
//                startIndex <= i {
//
//                switch direction {
//                case .long:
//                    if priceBar.getBarColor() == .blue {
//                        entryTimes.append(timeKey)
//                        currentlyInATrade = true
//                    }
//                default:
//                    if priceBar.getBarColor() == .red {
//                        entryTimes.append(timeKey)
//                        currentlyInATrade = true
//                    }
//                }
//            }
//        }
//
//        for entryTime in entryTimes {
//            guard let priceBar = chart.priceBars[entryTime] else { continue }
//
//            entryBars.append(priceBar)
//        }
//
//        return entryBars
//    }
    
    // given an entry Position and direction of the trade, find when the trade should end
    func findExitPoint(direction: TradeDirection, entryBar: PriceBar, entryPrice: Double) -> Trade? {
        guard let startIndex = chart.timeKeys.firstIndex(of: entryBar.identifier) else {
            return nil
        }
        
        let stopLoss = calculateStopLoss(direction: direction, entryBar: entryBar)
        var position: Position = Position(direction: direction,
                                          entry: entryBar,
                                          entryPrice: entryPrice,
                                          currentBar: entryBar,
                                          stopLoss: stopLoss)
        var exitPrice: Double?
        outerLoop: for i in startIndex..<chart.timeKeys.count {
            guard let currentPriceBar = chart.priceBars[chart.timeKeys[i]] else { continue }
            
            // if we reached the end of the file, set the exitBar to the last priceBar
            if i == chart.timeKeys.count - 1 {
                position.currentBar = currentPriceBar
                exitPrice = currentPriceBar.candleStick.close
            }
            
            // Rule 1: exit when the the low of the price hit the current stop loss
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
            
            // Rule 2: exit when bar of opposite color bar appears
            switch direction {
            case .long:
                if currentPriceBar.getBarColor() == .red {
                    position.currentBar = currentPriceBar
                    exitPrice = currentPriceBar.candleStick.close
                    break outerLoop
                }
            default:
                if currentPriceBar.getBarColor() == .blue {
                    position.currentBar = currentPriceBar
                    exitPrice = currentPriceBar.candleStick.close
                    break outerLoop
                }
            }
            
            position.currentBar = currentPriceBar
            
            // If the rules are not broken, update the stop loss using rules:
            // Rule 1: update to the low/high of current 2 green bars
            var rule1SL: Double
            switch direction {
            case .long:
                rule1SL = 0
            default:
                rule1SL = Double.greatestFiniteMagnitude
            }
            
            
            if position.profit < ProfitRequiredAbandonTwoGreenBarsExit,
                i > 0,
                let previousPriceBar = chart.priceBars[chart.timeKeys[i - 1]],
                previousPriceBar.getBarColor() == .green,
                currentPriceBar.getBarColor() == .green {
                
                switch direction {
                case .long:
                    rule1SL = min(previousPriceBar.candleStick.low, currentPriceBar.candleStick.low)
                default:
                    rule1SL = max(previousPriceBar.candleStick.high, currentPriceBar.candleStick.high)
                }
            }
            
            // Rule 2: update to previous S/R level
            let rule2SL: Double = findPreviousLevel(direction: direction, entryBar: currentPriceBar)
            
            switch direction {
            case .long:
                position.stopLoss = max(rule1SL, rule2SL)
            default:
                position.stopLoss = min(rule1SL, rule2SL)
            }
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
        // Method 3: current bar's high plus 1 or low, minus 1 depending on direction(min 5 points)
        
        // Method 1 and 2:
        let previousLevel: Double = findPreviousLevel(direction: direction, entryBar: entryBar)
        switch direction {
        case .long:
            if entryBar.candleStick.close - previousLevel <= MaxRisk {
                return previousLevel
            }
        default:
            if previousLevel - entryBar.candleStick.close <= MaxRisk {
                return previousLevel
            }
        }
        
        // Method 3:
        switch direction {
        case .long:
            return min(entryBar.candleStick.low - 1, entryBar.candleStick.close - 5)
        default:
            return max(entryBar.candleStick.high + 1, entryBar.candleStick.close + 5)
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
                leftBar.getBarColor() == .green,
                rightBar.getBarColor() == .green else {
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
    
    // check if the give bar is the end of a 'pullback' pattern based on the given trade direction
    func checkForPullback(direction: TradeDirection, start: PriceBar) -> Pullback? {
        guard let startIndex = chart.timeKeys.firstIndex(of: start.identifier),
        start.getOneMinSignal()?.stop != nil else {
            return nil
        }
        
        let timeKeysUpToIncludingStartIndex = chart.timeKeys[0...startIndex]
        
        let color: SignalColor = direction == .long ? .blue : .red
        var greenBars: [PriceBar] = []
        var coloredBars: [PriceBar] = []
        var coloredBarsIsComplete: Bool = false
        
        for timeKey in timeKeysUpToIncludingStartIndex.reversed() {
            guard let priceBar = chart.priceBars[timeKey] else { return nil }
            
            // if the current bar is green or an opposite color, it's not a sweetspot
            if coloredBars.isEmpty, priceBar.getBarColor() != color {
                return nil
            }
            // if the current bar is the correct color, add it to 'coloredBars'
            else if !coloredBarsIsComplete, priceBar.getBarColor() == color {
                coloredBars.insert(priceBar, at: 0)
            }
            // if the current bar is green, 'coloredBars' array is complete, start adding to 'greenBars'
            else if !coloredBars.isEmpty, priceBar.getBarColor() == .green {
                coloredBarsIsComplete = true
                greenBars.insert(priceBar, at: 0)
            }
            // if the current bar is not green anymore, 'greenBars' array is complete, the sweet spot is formed
            else if coloredBarsIsComplete, priceBar.getBarColor() != .green {
                break
            }
        }
        
        if !coloredBars.isEmpty {
            let sweetSpot = Pullback(direction: direction, greenBars: greenBars, coloredBars: coloredBars)
            return sweetSpot
        }
        
        return nil
    }
    
    // check if the current bar has a buy or sell confirmation(signal align on all 3 timeframes)
    func checkForSignalConfirmation(direction: TradeDirection, bar: PriceBar) -> Bool {
        guard let startIndex = chart.timeKeys.firstIndex(of: bar.identifier),
        bar.getOneMinSignal()?.stop != nil else {
            return false
        }
        
        let timeKeysUpToIncludingStartIndex = chart.timeKeys[0...startIndex]
        
        var oneMinBarConfirmation = false
        var twoMinBarConfirmation = false
        var threeMinBarConfirmation = false
        
        var finishedScanning = false
        for timeKey in timeKeysUpToIncludingStartIndex.reversed() {
            guard let priceBar = chart.priceBars[timeKey], !finishedScanning else { break }
            
            for signal in priceBar.signals {
                if let signalDirection = signal.direction, signalDirection != direction {
                    finishedScanning = true
                    break
                } else if let signalDirection = signal.direction, signalDirection == direction {
                    switch signal.inteval {
                    case .oneMin:
                        oneMinBarConfirmation = true
                    case .twoMin:
                        twoMinBarConfirmation = true
                    case .threeMin:
                        threeMinBarConfirmation = true
                    }
                }
            }
            
            if oneMinBarConfirmation && twoMinBarConfirmation && threeMinBarConfirmation {
                return true
            }
        }
        
        return false
    }
    
    
    
    // NOT USED:
    
    // given a starting and end price bar, find the 2 consecutive bars with the lowest "high"
    private func findPairOfGreenBarsWithLowestHigh(start: PriceBar, end: PriceBar) -> (PriceBar, PriceBar)? {
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
                leftBar.getBarColor() == .green,
                rightBar.getBarColor() == .green else {
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
    
    
    // find series of descending green bars with the lowest low
    // IE: 5,6,4,3,2,1,2,4,5
    // the lowest series of descending numbers is 6,4,3,2,1
    private func findLowestSeriesOfDescendingGreenBars(priceBars: [PriceBar]) -> [PriceBar] {
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
    private func findHighestSeriesOfAscendingGreenBars(priceBars: [PriceBar]) -> [PriceBar] {
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
