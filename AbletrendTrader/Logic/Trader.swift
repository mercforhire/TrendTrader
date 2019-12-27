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

enum TradeActionType {
    case noAction
    case openedPosition(position: Position)
    case updatedStop(position: Position)
    case closedPosition(trade: Trade)
}

class Trader {
    private var TimeIntervalForHighRiskEntry: DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components1 = DateComponents(year: chart.absLateBarData?.year(),
                                         month: chart.absLateBarData?.month(),
                                         day: chart.absLateBarData?.day(),
                                         hour: config.HighRiskEntryStartTime.0,
                                         minute: config.HighRiskEntryStartTime.1)
        let startDate: Date = calendar.date(from: components1)!
        let components2 = DateComponents(year: chart.absLateBarData?.year(),
                                         month: chart.absLateBarData?.month(),
                                         day: chart.absLateBarData?.day(),
                                         hour: config.HighRiskEntryEndTime.0,
                                         minute: config.HighRiskEntryEndTime.1)
        let endDate: Date = calendar.date(from: components2)!
        return DateInterval(start: startDate, end: endDate)
    }
    // the time interval where it's allowed to enter trades that has a stop > 10, Default: 9:30 am to 10 am
    
    private var TradingTimeInterval: DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components1 = DateComponents(year: chart.absLateBarData?.year(),
                                         month: chart.absLateBarData?.month(),
                                         day: chart.absLateBarData?.day(),
                                         hour: config.TradingSessionStartTime.0,
                                         minute: config.TradingSessionStartTime.1)
        let startDate: Date = calendar.date(from: components1)!
        let components2 = DateComponents(year: chart.absLateBarData?.year(),
                                         month: chart.absLateBarData?.month(),
                                         day: chart.absLateBarData?.day(),
                                         hour: config.TradingSessionEndTime.0,
                                         minute: config.TradingSessionEndTime.1)
        let endDate: Date = calendar.date(from: components2)!
        return DateInterval(start: startDate, end: endDate)
    }
    // the time interval allowed to enter trades, default 9:20 am to 3:55 pm
    
    private var ClearPositionTime: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components = DateComponents(year: chart.absLateBarData?.year(),
                                        month: chart.absLateBarData?.month(),
                                        day: chart.absLateBarData?.day(),
                                        hour: config.ClearPositionTime.0,
                                        minute: config.ClearPositionTime.1)
        let date: Date = calendar.date(from: components)!
        return date
    }
    // after this time, aim to sell at the close of any blue/red bar that's in favor of our ongoing trade
    
    private var FlatPositionsTime: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components = DateComponents(year: chart.absLateBarData?.year(),
                                        month: chart.absLateBarData?.month(),
                                        day: chart.absLateBarData?.day(),
                                        hour: config.FlatPositionsTime.0,
                                        minute: config.FlatPositionsTime.1)
        let date: Date = calendar.date(from: components)!
        return date
    }
    // after this time, clear all positions immediately

    private let config: Config
    var session: Session
    var chart: Chart
    
    init(chart: Chart, config: Config) {
        self.config = config
        self.chart = chart
        self.session = Session()
    }
    
    // Public:
    func generateSession(upToPriceBar: PriceBar? = nil) {
        guard chart.timeKeys.count > 1, let lastBar = upToPriceBar ?? chart.lastBar else {
            return
        }
        
        session = Session()
        
        for timeKey in chart.timeKeys {
            if timeKey == lastBar.identifier {
                break
            }
            
            guard let currentBar = chart.priceBars[timeKey] else { continue }
            
            let actions = process(priceBar: currentBar)
            for action in actions {
                switch action {
                case .noAction:
                    break
                    print(String(format: "No action on %@", timeKey))
                case .openedPosition(let position):
                    let type: String = position.direction == .long ? "Long" : "Short"
                    print(String(format: "Opened %@ position on %@ at price %.2f with SL: %.2f", type, timeKey, position.entryPrice, position.stopLoss.stop))
                case .closedPosition(let trade):
                    let type: String = trade.direction == .long ? "Long" : "Short"
                    print(String(format: "Closed %@ position from %@ on %@ with P/L of %.2f reason: %@", type, trade.entry.identifier, trade.exit.identifier, trade.profit ?? 0, trade.exitMethod.reason()))
                case .updatedStop(let position):
                    print(String(format: "%@ updated stop loss to %.2f reason: %@", position.currentBar.identifier, position.stopLoss.stop, position.stopLoss.source.reason()))
                }
            }
        }
    }
    
    
    // Decide trade actions at the given PriceBar object
    // Return true if an action was performed, false otherwise
    func process(priceBar: PriceBar? = nil) -> [TradeActionType] {
        guard chart.timeKeys.count > 1,
            let priceBar = priceBar ?? chart.lastBar,
            chart.timeKeys.contains(priceBar.identifier),
            let priceBarIndex = chart.timeKeys.firstIndex(of: priceBar.identifier),
            priceBarIndex > 0,
            let previousPriceBar = chart.priceBars[chart.timeKeys[priceBarIndex - 1]]
            else {
                return [.noAction]
        }
        
        session.latestPriceBar = priceBar
        
        // no current position, check if we should enter on the current bar
        if session.currentPosition == nil {
            return [handleNoPosition(currentBar: priceBar)]
        }
        // already have current position, update it or close it if needed
        else {
            session.currentPosition!.currentBar = priceBar
            
            // Rule 0: If we reached FlatPositionsTime, exit the trade immediately
            if FlatPositionsTime <= priceBar.candleStick.time {
                return [exitPosition(currentBar: priceBar, exitPrice: priceBar.candleStick.close, exitMethod: .endOfDay)]
            }
            
            // Rule 3: if we reached ClearPositionTime, close current position on any blue/red bar in favor of the position
            if ClearPositionTime <= priceBar.candleStick.time {
                switch session.currentPosition!.direction {
                case .long:
                    if priceBar.getBarColor() == .blue {
                        return [exitPosition(currentBar: priceBar, exitPrice: priceBar.candleStick.close, exitMethod: .endOfDay)]
                    }
                default:
                    if priceBar.getBarColor() == .red {
                        return [exitPosition(currentBar: priceBar, exitPrice: priceBar.candleStick.close, exitMethod: .endOfDay)]
                    }
                }
            }
            
            // Rule 1: exit when the the low of the price hit the current stop loss
            switch session.currentPosition!.direction {
            case .long:
                if priceBar.candleStick.low <= session.currentPosition!.stopLoss.stop {
                    let exitMethod: ExitMethod = session.currentPosition!.stopLoss.source == .supportResistanceLevel ||
                        session.currentPosition!.stopLoss.source == .currentBar ? .brokeSupportResistence : .twoGreenBars
                    let exitAction = exitPosition(currentBar: priceBar, exitPrice: session.currentPosition!.stopLoss.stop, exitMethod: exitMethod)
                    
                    switch handleNoPosition(currentBar: priceBar) {
                    case .openedPosition(let position):
                        return [exitAction, .openedPosition(position: position)]
                    default:
                        return [exitAction]
                    }
                }
            default:
                if priceBar.candleStick.high >= session.currentPosition!.stopLoss.stop {
                    let exitMethod: ExitMethod = session.currentPosition!.stopLoss.source == .supportResistanceLevel || session.currentPosition!.stopLoss.source == .currentBar ? .brokeSupportResistence : .twoGreenBars
                    let exitAction = exitPosition(currentBar: priceBar, exitPrice: session.currentPosition!.stopLoss.stop, exitMethod: exitMethod)
                    
                    switch handleNoPosition(currentBar: priceBar) {
                    case .openedPosition(let position):
                        return [exitAction, .openedPosition(position: position)]
                    default:
                        return [exitAction]
                    }
                }
            }
            
            // Rule 2: exit when bar of opposite color bar appears
            switch session.currentPosition!.direction {
            case .long:
                if priceBar.getBarColor() == .red {
                    let exitAction = exitPosition(currentBar: priceBar, exitPrice: priceBar.candleStick.close, exitMethod: .signalReversed)
                    
                    switch handleNoPosition(currentBar: priceBar) {
                    case .openedPosition(let position):
                        return [exitAction, .openedPosition(position: position)]
                    default:
                        return [exitAction]
                    }
                }
            default:
                if priceBar.getBarColor() == .blue {
                    let exitAction = exitPosition(currentBar: priceBar, exitPrice: priceBar.candleStick.close, exitMethod: .signalReversed)
                    
                    switch handleNoPosition(currentBar: priceBar) {
                    case .openedPosition(let position):
                        return [exitAction, .openedPosition(position: position)]
                    default:
                        return [exitAction]
                    }
                }
            }
            
            // If not exited the trade yet, update the current trade's stop loss:
            
            var twoGreenBarsSL: Double = session.currentPosition!.direction == .long ? 0 : Double.greatestFiniteMagnitude

            // if 2 green bars are detected and the green bars have not breached the 1 min S/R:
            if session.currentPosition!.securedProfit < config.ProfitRequiredAbandonTwoGreenBarsExit,
                previousPriceBar.getBarColor() == .green,
                priceBar.getBarColor() == .green,
                let currentStop = priceBar.getOneMinSignal()?.stop {
                
                switch session.currentPosition!.direction {
                case .long:
                    let stopLossFromGreenBars = min(previousPriceBar.candleStick.low, priceBar.candleStick.low).flooring(toNearest: 0.5) - 1
                    
                    if stopLossFromGreenBars > currentStop,
                        stopLossFromGreenBars - session.currentPosition!.entryPrice >= config.MinProfitToUseTwoGreenBarsExit,
                        previousPriceBar.candleStick.close >= currentStop,
                        priceBar.candleStick.close >= currentStop {
                        
                        // decide whether to use the bottom of the two green bars as SL or use 1 point under the 1 min stop
                        if stopLossFromGreenBars - currentStop > 1 {
                            twoGreenBarsSL = stopLossFromGreenBars
                        } else {
                            twoGreenBarsSL = currentStop - 1
                        }
                    }
                default:
                    let stopLossFromGreenBars = max(previousPriceBar.candleStick.high, priceBar.candleStick.high).ceiling(toNearest: 0.5) + 1
                    
                    if stopLossFromGreenBars < currentStop,
                        session.currentPosition!.entryPrice - stopLossFromGreenBars >= config.MinProfitToUseTwoGreenBarsExit,
                        previousPriceBar.candleStick.close <= currentStop,
                        priceBar.candleStick.close <= currentStop {
                        
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
            var newStop: Double = session.currentPosition!.stopLoss.stop
            var newStopSource: StopLossSource = session.currentPosition!.stopLoss.source
            
            if let previousLevelSL: Double = findPreviousLevel(direction: session.currentPosition!.direction, entryBar: priceBar) {
                switch session.currentPosition!.direction {
                case .long:
                    newStop = max(twoGreenBarsSL, previousLevelSL)
                    newStopSource = twoGreenBarsSL > previousLevelSL ? .twoGreenBars : .supportResistanceLevel
                default:
                    newStop = min(twoGreenBarsSL, previousLevelSL)
                    newStopSource = twoGreenBarsSL < previousLevelSL ? .twoGreenBars : .supportResistanceLevel
                }
            } else {
                
            }
            
            switch session.currentPosition!.direction {
            case .long:
                if newStop > session.currentPosition!.stopLoss.stop {
                    session.currentPosition!.stopLoss.stop = newStop
                    session.currentPosition!.stopLoss.source = newStopSource
                    return [.updatedStop(position: session.currentPosition!)]
                }
            default:
                if newStop < session.currentPosition!.stopLoss.stop {
                    session.currentPosition!.stopLoss.stop = newStop
                    session.currentPosition!.stopLoss.source = newStopSource
                    return [.updatedStop(position: session.currentPosition!)]
                }
            }
            
            return [.noAction]
        }
    }

    
    // Private:
    private func openNewPositionInSessionIfNeeded(bar: PriceBar, entryType: EntryType) -> TradeActionType {
        if let position: Position = checkForEntrySignal(direction: .long, bar: bar, entryType: entryType) ?? checkForEntrySignal(direction: .short, bar: bar, entryType: entryType) {
            session.currentPosition = position
            return .openedPosition(position: position)
        }
        return .noAction
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
            guard let pullBack = checkForPullback(direction: direction, start: bar),
                pullBack.coloredBars.count == 1 else {
                return nil
            }
            
            // check for SweetSpot bounce
            switch direction {
            case .long:
                guard let pullbackLow = pullBack.getLowestPoint(),
                    pullbackLow < oneMinStop || pullbackLow - oneMinStop <= config.SweetSpotMinDistance else {
                    return nil
                }
            default:
                guard let pullbackHigh = pullBack.getHighestPoint(),
                    pullbackHigh > oneMinStop || oneMinStop - pullbackHigh <= config.SweetSpotMinDistance else {
                    return nil
                }
            }
        default:
            break
        }
        
        if risk > config.MaxRisk && TimeIntervalForHighRiskEntry.contains(bar.candleStick.time) {
            stopLoss.stop = direction == .long ? bar.candleStick.close - 10 : bar.candleStick.close + 10
            let position = Position(direction: direction, entryPrice: bar.candleStick.close, stopLoss: stopLoss, entry: bar, currentBar: bar)
            return position
        } else if risk <= config.MaxRisk {
            let position = Position(direction: direction, entryPrice: bar.candleStick.close, stopLoss: stopLoss, entry: bar, currentBar: bar)
            return position
        }

        return nil
    }
    
    private func handleNoPosition(currentBar: PriceBar) -> TradeActionType {
        // time has pass outside the TradingTimeInterval, no more opening new positions, but still allow to close off existing position
        if !TradingTimeInterval.contains(currentBar.candleStick.time) {
            return .noAction
        }
        
        // If we are in TimeIntervalForHighRiskEntry, we want to enter aggressively on any entry.
        if TimeIntervalForHighRiskEntry.contains(currentBar.candleStick.time) {
            return openNewPositionInSessionIfNeeded(bar: currentBar, entryType: .initial)
        }
        // If the a previous trade exists, the direction of the trade matches the current bar:
        else if let lastTrade = session.trades.last, let currentBarDirection = currentBar.getOneMinSignal()?.direction {
            // if the last trade was stopped out in the current minute bar, enter aggressively on any entry
            if lastTrade.exit.identifier == currentBar.identifier {
                return openNewPositionInSessionIfNeeded(bar: currentBar, entryType: .initial)
            }
            // Check if signals from the end of the last trade to current bar are all of the same color as current
            // If yes, we need to decide if we want to enter on any Pullback or only Sweepspot
            // Otherwise, then enter aggressively on any entry
            else if chart.checkAllSameDirection(direction: currentBarDirection, fromKey: lastTrade.exit.identifier, toKey: currentBar.identifier) {
                // If the previous trade profit is higher than ProfitRequiredToReenterTradeonPullback,
                // we allow to enter on any pullback if no opposite signal on any timeframe is found from last trade to now
                if (lastTrade.profit ?? 0) > config.ProfitRequiredToReenterTradeonPullback {
                    return openNewPositionInSessionIfNeeded(bar: currentBar, entryType: .pullBack)
                } else {
                    return openNewPositionInSessionIfNeeded(bar: currentBar, entryType: .sweetSpot)
                }
            } else {
                return openNewPositionInSessionIfNeeded(bar: currentBar, entryType: .initial)
            }
        }
        else {
            return openNewPositionInSessionIfNeeded(bar: currentBar, entryType: .sweetSpot)
        }
    }
    
    private func exitPosition(currentBar: PriceBar, exitPrice: Double, exitMethod: ExitMethod) -> TradeActionType {
        let trade = Trade(direction: session.currentPosition!.direction,
                          entryPrice: session.currentPosition!.entryPrice,
                          exitPrice: exitPrice,
                          exitMethod: exitMethod,
                          entry: session.currentPosition!.entry,
                          exit: currentBar)
        session.trades.append(trade)
        session.currentPosition = nil
        return .closedPosition(trade: trade)
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
            if entryBar.candleStick.close - previousLevel <= config.MaxRisk {
                return StopLoss(stop: previousLevel, source: .supportResistanceLevel)
            }
        default:
            if previousLevel - entryBar.candleStick.close <= config.MaxRisk {
                return StopLoss(stop: previousLevel, source: .supportResistanceLevel)
            }
        }
        
        // Method 3:
        let lowRounded = entryBar.candleStick.low.roundBasedOnDirection(direction: direction)
        let highRounded = entryBar.candleStick.high.roundBasedOnDirection(direction: direction)
        let closeRounded = entryBar.candleStick.close.roundBasedOnDirection(direction: direction)
        
        switch direction {
        case .long:
            return StopLoss(stop: min(lowRounded - 1, closeRounded - config.MinBarStop), source: .currentBar)
        default:
            return StopLoss(stop: max(highRounded + 1, closeRounded + config.MinBarStop), source: .currentBar)
        }
    }
    
    // given an entry bar and direction of the trade, find the previous resistence/support level, if none exists, use the current one +-1
    private func findPreviousLevel(direction: TradeDirection, entryBar: PriceBar, minimalDistance: Double = 1) -> Double? {
        guard let startIndex = chart.timeKeys.firstIndex(of: entryBar.identifier),
            let initialBarStop = entryBar.getOneMinSignal()?.stop,
            entryBar.getOneMinSignal()?.direction == direction else {
            return nil
        }
        
        let initialBarStopRounded = initialBarStop.roundBasedOnDirection(direction: direction)
        var previousLevel: Double = initialBarStopRounded
        let timeKeysUpToIncludingStartIndex = chart.timeKeys[0...startIndex]
        
        outerLoop: for timeKey in timeKeysUpToIncludingStartIndex.reversed() {
            guard let currentPriceBar = chart.priceBars[timeKey] else { continue }
            
            if currentPriceBar.getOneMinSignal()?.direction != direction {
                break
            } else if let level = currentPriceBar.getOneMinSignal()?.stop {
                let levelRounded = level.roundBasedOnDirection(direction: direction)
                
                switch direction {
                case .long:
                    if previousLevel - levelRounded > minimalDistance {
                        previousLevel = levelRounded
                        break outerLoop
                    }
                default:
                    if levelRounded - previousLevel > minimalDistance {
                        previousLevel = levelRounded
                        break outerLoop
                    }
                }
            }
        }
        
        if previousLevel == initialBarStopRounded {
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
            guard let priceBar = chart.priceBars[timeKey], priceBar.getOneMinSignal()?.direction == direction else {
                break
            }
            
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
        guard let startIndex = chart.timeKeys.firstIndex(of: bar.identifier),
            bar.getOneMinSignal()?.stop != nil,
            bar.getOneMinSignal()?.direction == direction else {
            return false
        }
        
        let timeKeysUpToIncludingStartIndex = chart.timeKeys[0...startIndex]
        
        var earliest2MinBarConfirmationBar: PriceBar?
        var finishedScanningFor2MinConfirmation = false
        
        var earliest3MinBarConfirmationBar: PriceBar?
        var finishedScanningFor3MinConfirmation = false
        
        for timeKey in timeKeysUpToIncludingStartIndex.reversed() {
            guard let priceBar = chart.priceBars[timeKey], !finishedScanningFor2MinConfirmation && !finishedScanningFor3MinConfirmation else { break }
            
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
    
//    // given a starting and end price bar, find the 2 consecutive bars with the highest "low"
//    func findPairOfGreenBarsWithHighestLow(start: PriceBar, end: PriceBar) -> (PriceBar, PriceBar)? {
//        guard let startIndex = simChart.timeKeys.firstIndex(of: start.identifier),
//            let endIndex = simChart.timeKeys.firstIndex(of: end.identifier),
//            startIndex < endIndex else {
//            return nil
//        }
//
//        var indexOfTheFirstBar: Int?
//        var highestLow: Double?
//
//        for i in startIndex..<endIndex {
//            // skip any pair bars that are not green
//            guard let leftBar = simChart.priceBars[simChart.timeKeys[i]],
//                let rightBar = simChart.priceBars[simChart.timeKeys[i + 1]],
//                leftBar.getBarColor() == .green,
//                rightBar.getBarColor() == .green else {
//                continue
//            }
//
//            // found a pair of green bars:
//
//            // if no green pair have been found yet, save this pair as the default
//            if indexOfTheFirstBar == nil && highestLow == nil {
//                indexOfTheFirstBar = i
//                highestLow = max(leftBar.candleStick.low, rightBar.candleStick.low)
//            }
//            // if the highestLow found so far is lower than this new pair's highest "low", update the data
//            else if let highestLowSoFar = highestLow, max(leftBar.candleStick.low, rightBar.candleStick.low) > highestLowSoFar {
//                indexOfTheFirstBar = i
//                highestLow = max(leftBar.candleStick.low, rightBar.candleStick.low)
//            }
//        }
//
//        if let indexOfTheFirstBar = indexOfTheFirstBar,
//            let leftBar: PriceBar = simChart.priceBars[simChart.timeKeys[indexOfTheFirstBar]],
//            let rightBar = simChart.priceBars[simChart.timeKeys[indexOfTheFirstBar + 1]] {
//            return (leftBar, rightBar)
//        }
//
//        return nil
//    }
//    // given a starting and end price bar, find the 2 consecutive bars with the lowest "high"
//    private func findPairOfGreenBarsWithLowestHigh(start: PriceBar, end: PriceBar) -> (PriceBar, PriceBar)? {
//        guard let startIndex = simChart.timeKeys.firstIndex(of: start.identifier),
//            let endIndex = simChart.timeKeys.firstIndex(of: end.identifier),
//            startIndex < endIndex else {
//            return nil
//        }
//
//        var indexOfTheFirstBar: Int?
//        var lowestHigh: Double?
//
//        for i in startIndex..<endIndex {
//            // skip any pair bars that are not green
//            guard let leftBar = simChart.priceBars[simChart.timeKeys[i]],
//                let rightBar = simChart.priceBars[simChart.timeKeys[i + 1]],
//                leftBar.getBarColor() == .green,
//                rightBar.getBarColor() == .green else {
//                continue
//            }
//
//            // found a pair of green bars:
//
//            // if no green pair have been found yet, save this pair as the default
//            if indexOfTheFirstBar == nil && lowestHigh == nil {
//                indexOfTheFirstBar = i
//                lowestHigh = max(leftBar.candleStick.low, rightBar.candleStick.low)
//            }
//            // if the lowest high found so far is higher than this new pair's lowest "high", update the data
//            else if let lowestHighSoFar = lowestHigh, min(leftBar.candleStick.high, rightBar.candleStick.high) < lowestHighSoFar {
//                indexOfTheFirstBar = i
//                lowestHigh = min(leftBar.candleStick.high, rightBar.candleStick.high)
//            }
//        }
//
//        if let indexOfTheFirstBar = indexOfTheFirstBar,
//            let leftBar: PriceBar = simChart.priceBars[simChart.timeKeys[indexOfTheFirstBar]],
//            let rightBar = simChart.priceBars[simChart.timeKeys[indexOfTheFirstBar + 1]] {
//            return (leftBar, rightBar)
//        }
//
//        return nil
//    }
//
//
//    // find series of descending green bars with the lowest low
//    // IE: 5,6,4,3,2,1,2,4,5
//    // the lowest series of descending numbers is 6,4,3,2,1
//    private func findLowestSeriesOfDescendingGreenBars(priceBars: [PriceBar]) -> [PriceBar] {
//        // find the lowest bar first and move left from there
//
//        let priceBarsSorted = priceBars.sorted { (left, right) -> Bool in
//            return left.candleStick.low < right.candleStick.low
//        }
//
//        guard let lowestBar: PriceBar = priceBarsSorted.first else {
//            return []
//        }
//
//        var lowestSeriesOfDescendingGreenBars: [PriceBar] = []
//        var lowestBarIndex: Int = priceBars.firstIndex { (priceBar) -> Bool in
//            return priceBar.identifier == lowestBar.identifier
//            } ?? 0
//
//        while lowestBarIndex >= 0 {
//            if lowestSeriesOfDescendingGreenBars.isEmpty {
//                lowestSeriesOfDescendingGreenBars.append(priceBars[lowestBarIndex])
//            } else if let firstDescendingBar = lowestSeriesOfDescendingGreenBars.first,
//                priceBars[lowestBarIndex].candleStick.low > firstDescendingBar.candleStick.low {
//                lowestSeriesOfDescendingGreenBars.insert(priceBars[lowestBarIndex], at: 0)
//            } else if let firstDescendingBar = lowestSeriesOfDescendingGreenBars.first,
//                priceBars[lowestBarIndex].candleStick.low < firstDescendingBar.candleStick.low {
//                break
//            }
//
//            lowestBarIndex -= 1
//        }
//
//        return lowestSeriesOfDescendingGreenBars
//    }
//
//    // find series of ascending green bars with the highest high
//    // IE: 5,6,4,3,2,1,2,4,5
//    // the highest series of ascending numbers is 1,2,4,5
//    private func findHighestSeriesOfAscendingGreenBars(priceBars: [PriceBar]) -> [PriceBar] {
//        // find the highest bar first and move left from there
//
//        let priceBarsSorted = priceBars.sorted { (left, right) -> Bool in
//            return left.candleStick.high > right.candleStick.high
//        }
//
//        guard let highestBar: PriceBar = priceBarsSorted.first else {
//            return []
//        }
//
//        var highestSeriesOfAscendingGreenBars: [PriceBar] = []
//        var highestBarIndex: Int = priceBars.firstIndex { (priceBar) -> Bool in
//            return priceBar.identifier == highestBar.identifier
//            } ?? 0
//
//        while highestBarIndex >= 0 {
//            if highestSeriesOfAscendingGreenBars.isEmpty {
//                highestSeriesOfAscendingGreenBars.append(priceBars[highestBarIndex])
//            } else if let firstAscendingBar = highestSeriesOfAscendingGreenBars.first,
//                priceBars[highestBarIndex].candleStick.high < firstAscendingBar.candleStick.high {
//                highestSeriesOfAscendingGreenBars.insert(priceBars[highestBarIndex], at: 0)
//            } else if let firstAscendingBar = highestSeriesOfAscendingGreenBars.first,
//                priceBars[highestBarIndex].candleStick.high > firstAscendingBar.candleStick.high {
//                break
//            }
//
//            highestBarIndex -= 1
//        }
//
//        return highestSeriesOfAscendingGreenBars
//    }
}
