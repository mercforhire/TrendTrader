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
    case initial // enter on the first signal of a new triple confirmation
    case pullBack // enter on any blue/red bar followed by one or more green bars
    case sweetSpot // enter on pullback that bounced/almost bounced off the S/R level
}

class Trader {
    private var TimeIntervalForHighRiskEntry: DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(abbreviation: "EST")!
        let components1 = DateComponents(year: simChart.lastDate?.year(),
                                         month: simChart.lastDate?.month(),
                                         day: simChart.lastDate?.day(),
                                         hour: Config.HighRiskEntryStartTime.0,
                                         minute: Config.HighRiskEntryStartTime.1)
        let startDate: Date = calendar.date(from: components1)!
        let components2 = DateComponents(year: simChart.lastDate?.year(),
                                         month: simChart.lastDate?.month(),
                                         day: simChart.lastDate?.day(),
                                         hour: Config.HighRiskEntryEndTime.0,
                                         minute: Config.HighRiskEntryEndTime.1)
        let endDate: Date = calendar.date(from: components2)!
        return DateInterval(start: startDate, end: endDate)
    }
    // the time interval where it's allowed to enter trades that has a stop > 10, Default: 9:30 am to 10 am
    
    private var TradingTimeInterval: DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(abbreviation: "EST")!
        let components1 = DateComponents(year: simChart.lastDate?.year(),
                                         month: simChart.lastDate?.month(),
                                         day: simChart.lastDate?.day(),
                                         hour: Config.TradingSessionStartTime.0,
                                         minute: Config.TradingSessionStartTime.1)
        let startDate: Date = calendar.date(from: components1)!
        let components2 = DateComponents(year: simChart.lastDate?.year(),
                                         month: simChart.lastDate?.month(),
                                         day: simChart.lastDate?.day(),
                                         hour: Config.TradingSessionEndTime.0,
                                         minute: Config.TradingSessionEndTime.1)
        let endDate: Date = calendar.date(from: components2)!
        return DateInterval(start: startDate, end: endDate)
    }
    // the time interval allowed to enter trades, default 9:20 am to 3:55 pm
    
    private var ClearPositionTime: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(abbreviation: "EST")!
        let components = DateComponents(year: simChart.lastDate?.year(),
                                        month: simChart.lastDate?.month(),
                                        day: simChart.lastDate?.day(),
                                        hour: Config.ClearPositionTime.0,
                                        minute: Config.ClearPositionTime.1)
        let date: Date = calendar.date(from: components)!
        return date
    }
    // after this time, aim to sell at the close of any blue/red bar that's in favor of our ongoing trade
    
    private var FlatPositionsTime: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(abbreviation: "EST")!
        let components = DateComponents(year: simChart.lastDate?.year(),
                                        month: simChart.lastDate?.month(),
                                        day: simChart.lastDate?.day(),
                                        hour: Config.FlatPositionsTime.0,
                                        minute: Config.FlatPositionsTime.1)
        let date: Date = calendar.date(from: components)!
        return date
    }
    // after this time, clear all positions immediately

    private var fullChart: Chart
    private var simChart: Chart
    private var session: Session?
    
    init(chart: Chart) {
        self.fullChart = chart
        self.simChart = Chart(ticker: fullChart.ticker)
    }
    
    // Public:
    
    func newSession(startTime: Date, cutOffTime: Date) {
        session = Session(startTime: startTime, cutOffTime: cutOffTime)
        _ = simulateOneMinutePassed()
    }
    
    func generateSession() -> Session? {
        guard session != nil else {
            return nil
        }
        
        while simChart.lastTimeStamp != fullChart.lastTimeStamp {
            guard let currentBar = simChart.lastBar,
            session!.startTime <= currentBar.candleStick.time else {
                _ = simulateOneMinutePassed()
                continue
            }
            
//            if simChart.timeKeys.count == 435 {
//                print("break")
//            }
            
            // no current position, check if we should enter on the current bar
            if session!.currentPosition == nil {
                // close the session after time moves passes the cutOffTime
                if session!.cutOffTime <= currentBar.candleStick.time {
                    return session
                }
                
                // time has pass outside the TradingTimeInterval, no more opening new positions, but still allow to close off existing position
                if !TradingTimeInterval.contains(currentBar.candleStick.time) {
                    _ = simulateOneMinutePassed()
                    continue
                }
                
                // If we are in TimeIntervalForHighRiskEntry, we want to enter aggressively on any entry.
                if TimeIntervalForHighRiskEntry.contains(currentBar.candleStick.time) {
                    openNewPositionInSessionIfNeeded(bar: currentBar, entryType: .initial)
                }
                // If the a previous trade exists, the direction of the trade matches the current bar:
                else if let lastTrade = session?.trades.last, let currentBarDirection = currentBar.getOneMinSignal()?.direction {
                    
                    // Check if signals from the end of the last trade to current bar are all of the same color as current
                    // If yes, we need to decide if we want to enter on any Pullback or only Sweepspot
                    // Otherwise, then enter aggressively on any entry
                    if simChart.checkAllSameDirection(direction: currentBarDirection, fromKey: lastTrade.exit.identifier, toKey: currentBar.identifier) {
                        // If the previous trade profit is higher than ProfitRequiredToReenterTradeonPullback,
                        // we allow to enter on any pullback if no opposite signal on any timeframe is found from last trade to now
                        if (lastTrade.profit ?? 0) > Config.ProfitRequiredToReenterTradeonPullback {
                            openNewPositionInSessionIfNeeded(bar: currentBar, entryType: .pullBack)
                        } else {
                            openNewPositionInSessionIfNeeded(bar: currentBar, entryType: .sweetSpot)
                        }
                    } else {
                        openNewPositionInSessionIfNeeded(bar: currentBar, entryType: .initial)
                    }
                }
                else {
                    openNewPositionInSessionIfNeeded(bar: currentBar, entryType: .sweetSpot)
                }
            }
            // already have current position, update it or close it if needed
            else {
                var exitPrice: Double?
                var exitMethod: ExitMethod?
                var exitSession = false
                
                // if we reached FlatPositionsTime, set the exitBar to current
                if FlatPositionsTime <= currentBar.candleStick.time {
                    session!.currentPosition!.bars.append(currentBar)
                    exitPrice = currentBar.candleStick.close
                    exitMethod = .endOfDay
                    exitSession = true
                }
                else {
                    // Rule 1: exit when the the low of the price hit the current stop loss
                    switch session!.currentPosition!.direction {
                    case .long:
                        if currentBar.candleStick.low <= session!.currentPosition!.stopLoss.stop {
                            session!.currentPosition!.bars.append(currentBar)
                            exitPrice = session!.currentPosition!.stopLoss.stop
                            exitMethod = session!.currentPosition!.stopLoss.source == .supportResistanceLevel || session!.currentPosition!.stopLoss.source == .currentBar ? .brokeSupportResistence : .twoGreenBars
                        }
                    default:
                        if currentBar.candleStick.high >= session!.currentPosition!.stopLoss.stop {
                            session!.currentPosition!.bars.append(currentBar)
                            exitPrice = session!.currentPosition!.stopLoss.stop
                            exitMethod = session!.currentPosition!.stopLoss.source == .supportResistanceLevel || session!.currentPosition!.stopLoss.source == .currentBar ? .brokeSupportResistence : .twoGreenBars
                        }
                    }
                    
                    // Rule 2: exit when bar of opposite color bar appears
                    switch session!.currentPosition!.direction {
                    case .long:
                        if currentBar.getBarColor() == .red {
                            session!.currentPosition!.bars.append(currentBar)
                            exitPrice = currentBar.candleStick.close
                            exitMethod = .signalReversed
                        }
                    default:
                        if currentBar.getBarColor() == .blue {
                            session!.currentPosition!.bars.append(currentBar)
                            exitPrice = currentBar.candleStick.close
                            exitMethod = .signalReversed
                        }
                    }
                    
                    // Rule 3: if we reached ClearPositionTime, close current position on any blue/red bar in favor of the position
                    if ClearPositionTime <= currentBar.candleStick.time {
                        switch session!.currentPosition!.direction {
                        case .long:
                            if currentBar.getBarColor() == .blue {
                                exitPrice = currentBar.candleStick.close
                                exitMethod = .endOfDay
                                exitSession = true
                            }
                        default:
                            if currentBar.getBarColor() == .red {
                                exitPrice = currentBar.candleStick.close
                                exitMethod = .endOfDay
                                exitSession = true
                            }
                        }
                    }
                    
                    session!.currentPosition!.bars.append(currentBar)
                    
                    // Update the stop loss:
                    
                    var twoGreenBarsSL: Double
                    switch session!.currentPosition!.direction {
                    case .long:
                        twoGreenBarsSL = 0
                    default:
                        twoGreenBarsSL = Double.greatestFiniteMagnitude
                    }
                    // if 2 green bars are detected and the green bars have not breached the 1 min S/R:
                    if session!.currentPosition!.securedProfit < Config.ProfitRequiredAbandonTwoGreenBarsExit,
                        let previousBar = simChart.secondLastBar,
                        previousBar.getBarColor() == .green,
                        currentBar.getBarColor() == .green,
                        let currentStop = currentBar.getOneMinSignal()?.stop {
                        
                        switch session!.currentPosition!.direction {
                        case .long:
                            let stopLossFromGreenBars = min(previousBar.candleStick.low, currentBar.candleStick.low) - 1
                            
                            if stopLossFromGreenBars - session!.currentPosition!.entryPrice >= Config.MinProfitToUseTwoGreenBarsExit,
                                previousBar.candleStick.close >= currentStop,
                                currentBar.candleStick.close >= currentStop {
                                
                                // decide whether to use the bottom of the two green bars as SL or use 1 point under the 1 min stop
                                if stopLossFromGreenBars - currentStop > 1 {
                                    twoGreenBarsSL = stopLossFromGreenBars
                                } else {
                                    twoGreenBarsSL = currentStop - 1
                                }
                            }
                        default:
                            let stopLossFromGreenBars = max(previousBar.candleStick.high, currentBar.candleStick.high) + 1
                            
                            if session!.currentPosition!.entryPrice - stopLossFromGreenBars >= Config.MinProfitToUseTwoGreenBarsExit,
                                previousBar.candleStick.close <= currentStop,
                                currentBar.candleStick.close <= currentStop {
                                
                                // decide whether to use the top of the two green bars as SL or use 1 point above the 1 min stop
                                if currentStop - stopLossFromGreenBars > 1 {
                                    twoGreenBarsSL = stopLossFromGreenBars
                                } else {
                                    twoGreenBarsSL = currentStop + 1
                                }
                            }
                        }
                    }
                    
                    // update to previous S/R level
                    if let previousLevelSL: Double = findPreviousLevel(direction: session!.currentPosition!.direction, entryBar: currentBar) {
                        switch session!.currentPosition!.direction {
                        case .long:
                            session!.currentPosition!.stopLoss.stop = max(twoGreenBarsSL, previousLevelSL)
                            session!.currentPosition!.stopLoss.source = twoGreenBarsSL > previousLevelSL ? .twoGreenBars : .supportResistanceLevel
                        default:
                            session!.currentPosition!.stopLoss.stop = min(twoGreenBarsSL, previousLevelSL)
                            session!.currentPosition!.stopLoss.source = twoGreenBarsSL < previousLevelSL ? .twoGreenBars : .supportResistanceLevel
                        }
                    } else {
                        switch session!.currentPosition!.direction {
                        case .long:
                            session!.currentPosition!.stopLoss.stop = twoGreenBarsSL
                            session!.currentPosition!.stopLoss.source = .twoGreenBars
                        default:
                            session!.currentPosition!.stopLoss.stop = twoGreenBarsSL
                            session!.currentPosition!.stopLoss.source = .twoGreenBars
                        }
                    }
                }
                
                
                if let exitPrice = exitPrice, let exitMethod = exitMethod {
                    let trade = Trade(direction: session!.currentPosition!.direction,
                                      entryPrice: session!.currentPosition!.entryPrice,
                                      exitPrice: exitPrice,
                                      bars: session!.currentPosition!.bars,
                                      exitMethod: exitMethod)
                    session!.trades.append(trade)
                    session!.currentPosition = nil
                }
                
                if exitSession {
                    return session
                }
            }
            
            _ = simulateOneMinutePassed()
        }
        
        return session
    }

    
    // Private:
    private func openNewPositionInSessionIfNeeded(bar: PriceBar, entryType: EntryType) {
        if let position: Position = checkForEntrySignal(direction: .long, bar: bar, entryType: entryType) ?? checkForEntrySignal(direction: .short, bar: bar, entryType: entryType) {
            session!.currentPosition = position
        }
    }
    
    private func simulateOneMinutePassed() -> Bool {
        guard !fullChart.timeKeys.isEmpty, !fullChart.priceBars.isEmpty else { return false }
        
        if simChart.timeKeys.isEmpty {
            let firstBarKey = fullChart.timeKeys.first!
            simChart.timeKeys.append(firstBarKey)
            simChart.priceBars[firstBarKey] = fullChart.priceBars[firstBarKey]
            return true
        } else if let previousBarKey: String = simChart.timeKeys.last,
            let previousBarIndex: Int = fullChart.timeKeys.firstIndex(of: previousBarKey),
            previousBarIndex + 1 < fullChart.timeKeys.count {
            let currentBarKey = fullChart.timeKeys[previousBarIndex + 1]
            let currentBar = fullChart.priceBars[currentBarKey]
            
            simChart.timeKeys.append(currentBarKey)
            simChart.priceBars[currentBarKey] = currentBar
            return true
        }
        
        return false
    }
    
    // return a Position object if the given bar presents a entry signal
    private func checkForEntrySignal(direction: TradeDirection, bar: PriceBar, entryType: EntryType = .pullBack) -> Position? {
        let color: SignalColor = direction == .long ? .blue : .red
        
        guard bar.getBarColor() == color,
            checkForSignalConfirmation(direction: direction, bar: bar),
            let oneMinStop = bar.getOneMinSignal()?.stop,
            var stopLoss = calculateStopLoss(direction: direction, entryBar: bar) else {
            return nil
        }
        
        let risk: Double = abs(bar.candleStick.close - stopLoss.stop)
        
        switch entryType {
        case .pullBack:
            guard let pullBack = checkForPullback(direction: direction, start: bar), !pullBack.greenBars.isEmpty,
                pullBack.coloredBars.count == 1 else {
                return nil
            }
        case .sweetSpot:
            guard let pullBack = checkForPullback(direction: direction, start: bar), !pullBack.greenBars.isEmpty,
                pullBack.coloredBars.count == 1 else {
                return nil
            }
            
            // check for SweetSpot bounce
            switch direction {
            case .long:
                guard let pullbackLow = pullBack.getLowestPoint(),
                    pullbackLow - oneMinStop <= Config.SweetSpotMinDistance else {
                    return nil
                }
            default:
                guard let pullbackHigh = pullBack.getHighestPoint(),
                    oneMinStop - pullbackHigh <= Config.SweetSpotMinDistance else {
                    return nil
                }
            }
        default:
            break
        }
        
        if risk > Config.MaxRisk && TimeIntervalForHighRiskEntry.contains(bar.candleStick.time) {
            stopLoss.stop = direction == .long ? bar.candleStick.close - 10 : bar.candleStick.close + 10
            let position = Position(direction: direction, entryPrice: bar.candleStick.close, bars: [bar], stopLoss: stopLoss)
            return position
        } else if risk <= Config.MaxRisk {
            let position = Position(direction: direction, entryPrice: bar.candleStick.close, bars: [bar], stopLoss: stopLoss)
            return position
        }

        return nil
    }
    
    private func calculateStopLoss(direction: TradeDirection, entryBar: PriceBar) -> StopLoss? {
        // Go with the methods in order. If the stoploss is > MaxRisk, go to the next method
        // Worst case would be method 3 and still having stoploss > MaxRisk, either skip the trade or apply a hard stop at the MaxRisk
        
        // Method 1: previous resistence/support level
        // Method 2: current resistence/support level plus or minus 1 depending on direction
        // Method 3: current bar's high plus 1 or low, minus 1 depending on direction(min 5 points)
        
        // Method 1 and 2:
        guard let previousLevel: Double = findPreviousLevel(direction: direction, entryBar: entryBar) else { return nil }
        switch direction {
        case .long:
            if entryBar.candleStick.close - previousLevel <= Config.MaxRisk {
                return StopLoss(stop: previousLevel, source: .supportResistanceLevel)
            }
        default:
            if previousLevel - entryBar.candleStick.close <= Config.MaxRisk {
                return StopLoss(stop: previousLevel, source: .supportResistanceLevel)
            }
        }
        
        // Method 3:
        switch direction {
        case .long:
            return StopLoss(stop: min(entryBar.candleStick.low - 1, entryBar.candleStick.close - Config.MinBarStop), source: .currentBar)
        default:
            return StopLoss(stop: max(entryBar.candleStick.high + 1, entryBar.candleStick.close + Config.MinBarStop), source: .currentBar)
        }
    }
    
    // given an entry bar and direction of the trade, find the previous resistence/support level, if none exists, use the current one +-1
    private func findPreviousLevel(direction: TradeDirection, entryBar: PriceBar, minimalDistance: Double = 1) -> Double? {
        guard let startIndex = simChart.timeKeys.firstIndex(of: entryBar.identifier),
            let initialBarStop = entryBar.getOneMinSignal()?.stop,
            entryBar.getOneMinSignal()?.direction == direction else {
            return nil
        }
        
        var previousLevel: Double = initialBarStop
        let timeKeysUpToIncludingStartIndex = simChart.timeKeys[0...startIndex]
        
        outerLoop: for timeKey in timeKeysUpToIncludingStartIndex.reversed() {
            guard let currentPriceBar = simChart.priceBars[timeKey] else { continue }
            
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
    
    // check if the give bar is the end of a 'pullback' pattern based on the given trade direction
    private func checkForPullback(direction: TradeDirection, start: PriceBar) -> Pullback? {
        guard let startIndex = simChart.timeKeys.firstIndex(of: start.identifier),
        start.getOneMinSignal()?.stop != nil else {
            return nil
        }
        
        let timeKeysUpToIncludingStartIndex = simChart.timeKeys[0...startIndex]
        
        let color: SignalColor = direction == .long ? .blue : .red
        var greenBars: [PriceBar] = []
        var coloredBars: [PriceBar] = []
        var coloredBarsIsComplete: Bool = false
        
        for timeKey in timeKeysUpToIncludingStartIndex.reversed() {
            guard let priceBar = simChart.priceBars[timeKey], priceBar.getOneMinSignal()?.direction == direction else { return nil }
            
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
    private func checkForSignalConfirmation(direction: TradeDirection, bar: PriceBar) -> Bool {
        guard let startIndex = simChart.timeKeys.firstIndex(of: bar.identifier),
            bar.getOneMinSignal()?.stop != nil,
            bar.getOneMinSignal()?.direction == direction else {
            return false
        }
        
        let timeKeysUpToIncludingStartIndex = simChart.timeKeys[0...startIndex]
        
        var earliest2MinBarConfirmationBar: PriceBar?
        var finishedScanningFor2MinConfirmation = false
        
        var earliest3MinBarConfirmationBar: PriceBar?
        var finishedScanningFor3MinConfirmation = false
        
        for timeKey in timeKeysUpToIncludingStartIndex.reversed() {
            guard let priceBar = simChart.priceBars[timeKey], !finishedScanningFor2MinConfirmation && !finishedScanningFor3MinConfirmation else { break }
            
            for signal in priceBar.signals where signal.inteval != .oneMin {
                if let signalDirection = signal.direction, signalDirection != direction {
                    switch signal.inteval {
                    case .twoMin:
                        finishedScanningFor2MinConfirmation = true
                    case .threeMin:
                        finishedScanningFor3MinConfirmation = true
                    default:
                        break
                    }
                } else if let signalDirection = signal.direction, signalDirection == direction {
                    switch signal.inteval {
                    case .twoMin:
                        earliest2MinBarConfirmationBar = priceBar
                    case .threeMin:
                        earliest3MinBarConfirmationBar = priceBar
                    default:
                        break
                    }
                }
            }
        }
        
        return earliest2MinBarConfirmationBar != nil && earliest3MinBarConfirmationBar != nil
    }
    
    // NOT USED:
    
    // given a starting and end price bar, find the 2 consecutive bars with the highest "low"
    func findPairOfGreenBarsWithHighestLow(start: PriceBar, end: PriceBar) -> (PriceBar, PriceBar)? {
        guard let startIndex = simChart.timeKeys.firstIndex(of: start.identifier),
            let endIndex = simChart.timeKeys.firstIndex(of: end.identifier),
            startIndex < endIndex else {
            return nil
        }
        
        var indexOfTheFirstBar: Int?
        var highestLow: Double?
        
        for i in startIndex..<endIndex {
            // skip any pair bars that are not green
            guard let leftBar = simChart.priceBars[simChart.timeKeys[i]],
                let rightBar = simChart.priceBars[simChart.timeKeys[i + 1]],
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
            let leftBar: PriceBar = simChart.priceBars[simChart.timeKeys[indexOfTheFirstBar]],
            let rightBar = simChart.priceBars[simChart.timeKeys[indexOfTheFirstBar + 1]] {
            return (leftBar, rightBar)
        }
        
        return nil
    }
    // given a starting and end price bar, find the 2 consecutive bars with the lowest "high"
    private func findPairOfGreenBarsWithLowestHigh(start: PriceBar, end: PriceBar) -> (PriceBar, PriceBar)? {
        guard let startIndex = simChart.timeKeys.firstIndex(of: start.identifier),
            let endIndex = simChart.timeKeys.firstIndex(of: end.identifier),
            startIndex < endIndex else {
            return nil
        }
        
        var indexOfTheFirstBar: Int?
        var lowestHigh: Double?
        
        for i in startIndex..<endIndex {
            // skip any pair bars that are not green
            guard let leftBar = simChart.priceBars[simChart.timeKeys[i]],
                let rightBar = simChart.priceBars[simChart.timeKeys[i + 1]],
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
            let leftBar: PriceBar = simChart.priceBars[simChart.timeKeys[indexOfTheFirstBar]],
            let rightBar = simChart.priceBars[simChart.timeKeys[indexOfTheFirstBar + 1]] {
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
