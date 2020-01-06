//
//  TraderBot.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-21.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class TraderBot {
    var sessionManager: SessionManager
    var chart: Chart
    
    private let config = Config.shared
    private let networkManager = NetworkManager.shared
    
    init(chart: Chart, sessionManager: SessionManager) {
        self.chart = chart
        self.sessionManager = sessionManager
    }
    
    // Public:
    func generateSimSession(upToPriceBar: PriceBar? = nil, completion: @escaping () -> ()) {
        guard chart.timeKeys.count > 1, let lastBar = upToPriceBar ?? chart.lastBar else {
            return
        }
        
        sessionManager.resetSession()
        
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            for timeKey in self.chart.timeKeys {
                if timeKey == lastBar.identifier {
                    break
                }
                
                guard let currentBar = self.chart.priceBars[timeKey] else { continue }
                
                let actions = self.decide(priceBar: currentBar)
                DispatchQueue.main.async {
                    for action in actions {
                        switch action {
                        case .noAction:
                            break
                            print(String(format: "No action on %@", timeKey))
                        case .openedPosition(let position):
                            let type: String = position.direction == .long ? "Long" : "Short"
                            print(String(format: "Opened %@ position on %@ at price %.2f with SL: %.2f", type, timeKey, position.entryPrice, position.stopLoss?.stop ?? -1))
                        case .closedPosition(let trade):
                            let type: String = trade.direction == .long ? "Long" : "Short"
                            print(String(format: "Closed %@ position from %@ on %@ with P/L of %.2f reason: %@", type, trade.entryTime?.generateShortDate() ?? "--", trade.exitTime.generateShortDate(), trade.profit ?? 0, trade.exitMethod.reason()))
                        case .updatedStop(let stopLoss):
                            print(String(format: "Updated stop loss to %.2f reason: %@", stopLoss.stop, stopLoss.source.reason()))
                        }
                    }
                }
                
                self.sessionManager.processActions(actions: actions) { networkError in
                    semaphore.signal()
                }
                
                semaphore.wait()
            }
            
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    
    // Decide trade actions at the given PriceBar object, returns the list of actions need to be performed
    func decide(priceBar: PriceBar? = nil) -> [TradeActionType] {
        guard chart.timeKeys.count > 1,
            let priceBar = priceBar ?? chart.lastBar,
            chart.timeKeys.contains(priceBar.identifier),
            let priceBarIndex = chart.timeKeys.firstIndex(of: priceBar.identifier),
            priceBarIndex > 0,
            let previousPriceBar = chart.priceBars[chart.timeKeys[priceBarIndex - 1]]
            else {
                return [.noAction]
        }
        
        // no current position, check if we should enter on the current bar
        if !sessionManager.hasCurrentPosition {
            return [handleOpeningNewTrade(currentBar: priceBar)]
        }
        // already have current position, update it or close it if needed
        else {
            // Rule 3: If we reached FlatPositionsTime, exit the trade immediately
            if config.flatPositionsTime(chart: chart) <= priceBar.time && !config.byPassTradingTimeRestrictions {
                return [exitPosition(currentBar: priceBar, exitPrice: priceBar.candleStick.close, exitMethod: .endOfDay)]
            }
            
            // Rule 4: if we reached ClearPositionTime, close current position on any blue/red bar in favor of the position
            if config.clearPositionTime(chart: chart) <= priceBar.time && !config.byPassTradingTimeRestrictions {
                switch sessionManager.currentPositionDirection {
                case .long:
                    if priceBar.barColor == .blue {
                        return [exitPosition(currentBar: priceBar, exitPrice: priceBar.candleStick.close, exitMethod: .endOfDay)]
                    }
                default:
                    if priceBar.barColor == .red {
                        return [exitPosition(currentBar: priceBar, exitPrice: priceBar.candleStick.close, exitMethod: .endOfDay)]
                    }
                }
            }
            
            // Rule 1: exit when the the low of the price hit the current stop loss
            switch sessionManager.currentPositionDirection {
            case .long:
                if let stop = sessionManager.stopLoss?.stop,
                    priceBar.candleStick.low <= stop {
                    let exitMethod: ExitMethod = sessionManager.stopLoss?.source == .supportResistanceLevel ||
                        sessionManager.stopLoss?.source == .currentBar ? .brokeSupportResistence : .twoGreenBars
                    let exitAction = exitPosition(currentBar: priceBar, exitPrice: stop, exitMethod: exitMethod)
                    
                    switch handleOpeningNewTrade(currentBar: priceBar) {
                    case .openedPosition(let position):
                        return [exitAction, .openedPosition(position: position)]
                    default:
                        return [exitAction]
                    }
                }
            default:
                if let stop = sessionManager.stopLoss?.stop,
                    let stopSource = sessionManager.stopLoss?.source,
                    priceBar.candleStick.high >= stop {
                    let exitMethod: ExitMethod = stopSource == .supportResistanceLevel || stopSource == .currentBar ? .brokeSupportResistence : .twoGreenBars
                    let exitAction = exitPosition(currentBar: priceBar, exitPrice: stop, exitMethod: exitMethod)
                    
                    switch handleOpeningNewTrade(currentBar: priceBar) {
                    case .openedPosition(let position):
                        return [exitAction, .openedPosition(position: position)]
                    default:
                        return [exitAction]
                    }
                }
            }
            
            // Rule 2: exit when bar of opposite color bar appears
            switch sessionManager.currentPositionDirection {
            case .long:
                if priceBar.barColor == .red {
                    let exitAction = exitPosition(currentBar: priceBar, exitPrice: priceBar.candleStick.close, exitMethod: .signalReversed)
                    
                    switch handleOpeningNewTrade(currentBar: priceBar) {
                    case .openedPosition(let position):
                        return [exitAction, .openedPosition(position: position)]
                    default:
                        return [exitAction]
                    }
                }
            default:
                if priceBar.barColor == .blue {
                    let exitAction = exitPosition(currentBar: priceBar, exitPrice: priceBar.candleStick.close, exitMethod: .signalReversed)
                    
                    switch handleOpeningNewTrade(currentBar: priceBar) {
                    case .openedPosition(let position):
                        return [exitAction, .openedPosition(position: position)]
                    default:
                        return [exitAction]
                    }
                }
            }
            
            // If not exited the trade yet, update the current trade's stop loss:
            
            // Calculate the SL based on the 2 green bars(if applicable)
            var twoGreenBarsSL: Double = sessionManager.currentPositionDirection == .long ? 0 : Double.greatestFiniteMagnitude

            if let securedProfit = sessionManager.securedProfit,
                securedProfit < config.skipGreenBarsExit,
                let entryPrice = sessionManager.currentPosition?.entryPrice,
                previousPriceBar.barColor == .green,
                priceBar.barColor == .green,
                let currentStop = priceBar.oneMinSignal?.stop {
                
                switch sessionManager.currentPositionDirection {
                case .long:
                    let stopLossFromGreenBars = min(previousPriceBar.candleStick.low, priceBar.candleStick.low).flooring(toNearest: 0.5) - 1
                    
                    if stopLossFromGreenBars > currentStop,
                        stopLossFromGreenBars - entryPrice >= config.greenBarsExit,
                        previousPriceBar.candleStick.close >= currentStop,
                        priceBar.candleStick.close >= currentStop {
                        
                        // decide whether to use the bottom of the two green bars as SL or use 1 point under the 1 min stop
                        if stopLossFromGreenBars - currentStop > config.sweetSpotMinDistance {
                            twoGreenBarsSL = stopLossFromGreenBars
                        } else {
                            twoGreenBarsSL = currentStop - 1
                        }
                    }
                default:
                    let stopLossFromGreenBars = max(previousPriceBar.candleStick.high, priceBar.candleStick.high).ceiling(toNearest: 0.5) + 1
                    
                    if stopLossFromGreenBars < currentStop,
                        sessionManager.currentPosition!.entryPrice - stopLossFromGreenBars >= config.greenBarsExit,
                        previousPriceBar.candleStick.close <= currentStop,
                        priceBar.candleStick.close <= currentStop {
                        
                        // decide whether to use the top of the two green bars as SL or use 1 point above the 1 min stop
                        if currentStop - stopLossFromGreenBars > config.sweetSpotMinDistance {
                            twoGreenBarsSL = stopLossFromGreenBars
                        } else {
                            twoGreenBarsSL = currentStop + 1
                        }
                    }
                }
            }
            
            if var newStop: Double = sessionManager.currentPosition?.stopLoss?.stop,
                var newStopSource: StopLossSource = sessionManager.currentPosition?.stopLoss?.source {
                
                // Calculate the SL based on the previous S/R level and decide which of the two SLs should we use
                if let previousLevelSL: Double = findPreviousLevel(direction: sessionManager.currentPosition!.direction, entryBar: priceBar) {
                    
                    switch sessionManager.currentPositionDirection {
                    case .long:
                        newStop = max(twoGreenBarsSL, previousLevelSL)
                        newStopSource = twoGreenBarsSL > previousLevelSL ? .twoGreenBars : .supportResistanceLevel
                    default:
                        newStop = min(twoGreenBarsSL, previousLevelSL)
                        newStopSource = twoGreenBarsSL < previousLevelSL ? .twoGreenBars : .supportResistanceLevel
                    }
                }
                
                // Apply the new SL if it is more in favor than the existing SL
                switch sessionManager.currentPosition!.direction {
                case .long:
                    if let stop = sessionManager.stopLoss?.stop, newStop > stop {
                        return [.updatedStop(stop: StopLoss(stop: newStop, source: newStopSource))]
                    }
                default:
                    if let stop = sessionManager.stopLoss?.stop, newStop < stop {
                        return [.updatedStop(stop: StopLoss(stop: newStop, source: newStopSource))]
                    }
                }
            }
            
            return [.noAction]
        }
    }

    func buyAtMarket() -> TradeActionType {
        guard let currentPrice = chart.absLastBar?.candleStick.close else { return .noAction }
        
        let buyPosition = Position(direction: .long, entryTime: chart.absLastBarDate, entryPrice: currentPrice)
        return .openedPosition(position: buyPosition)
    }
    
    func sellAtMarket() -> TradeActionType {
        guard let currentPrice = chart.absLastBar?.candleStick.close else { return .noAction }
        
        let sellPosition = Position(direction: .short, entryTime: chart.absLastBarDate, entryPrice: currentPrice)
        return .openedPosition(position: sellPosition)
    }
    
    // Private:
    private func seekToOpenPosition(bar: PriceBar, entryType: EntryType) -> TradeActionType {
        if let position: Position = checkForEntrySignal(direction: .long, bar: bar, entryType: entryType) ?? checkForEntrySignal(direction: .short, bar: bar, entryType: entryType) {
            return .openedPosition(position: position)
        }
        return .noAction
    }
    
    // return a Position object if the given bar presents a entry signal
    private func checkForEntrySignal(direction: TradeDirection, bar: PriceBar, entryType: EntryType = .pullBack) -> Position? {
        let color: SignalColor = direction == .long ? .blue : .red
        
        guard bar.barColor == color,
            checkForSignalConfirmation(direction: direction, bar: bar),
            let oneMinStop = bar.oneMinSignal?.stop,
            var stopLoss = calculateStopLoss(direction: direction, entryBar: bar),
            let barIndex: Int = chart.timeKeys.firstIndex(of: bar.identifier),
            barIndex < chart.timeKeys.count - 1,
            let nextBar = chart.priceBars[chart.timeKeys[barIndex + 1]] else {
            return nil
        }
        
        let risk: Double = abs(bar.candleStick.close - stopLoss.stop)
        
        switch entryType {
        case .pullBack:
            guard let pullBack = checkForPullback(direction: direction, start: bar), !pullBack.greenBars.isEmpty,
                pullBack.coloredBars.count >= 1 else {
                return nil
            }
        case .sweetSpot:
            guard let pullBack = checkForPullback(direction: direction, start: bar),
                pullBack.coloredBars.count >= 1 else {
                return nil
            }
            
            // check for SweetSpot bounce
            switch direction {
            case .long:
                guard let pullbackLow = pullBack.getLowestPoint(),
                    pullbackLow < oneMinStop || pullbackLow - oneMinStop <= config.sweetSpotMinDistance else {
                    return nil
                }
            default:
                guard let pullbackHigh = pullBack.getHighestPoint(),
                    pullbackHigh > oneMinStop || oneMinStop - pullbackHigh <= config.sweetSpotMinDistance else {
                    return nil
                }
            }
        default:
            break
        }
        
        if risk > config.maxRisk && config.timeIntervalForHighRiskEntry(chart: chart).contains(bar.time) {
            stopLoss.stop = direction == .long ? bar.candleStick.close - config.maxRisk : bar.candleStick.close + config.maxRisk
            let position = Position(direction: direction, entryTime: nextBar.time, entryPrice: nextBar.candleStick.open, stopLoss: stopLoss)
            return position
        } else if risk <= config.maxRisk {
            let position = Position(direction: direction, entryTime: nextBar.time, entryPrice: nextBar.candleStick.open, stopLoss: stopLoss)
            return position
        }

        return nil
    }
    
    private func handleOpeningNewTrade(currentBar: PriceBar) -> TradeActionType {
        // stop trading if P&L <= MaxDailyLoss
        if sessionManager.getTotalPAndL() <= config.maxDailyLoss {
            return .noAction
        }
        
        // time has pass outside the TradingTimeInterval, no more opening new positions, but still allow to close off existing position
        if !config.tradingTimeInterval(chart: chart).contains(currentBar.time) && !config.byPassTradingTimeRestrictions {
            return .noAction
        }
        
        // If we are in TimeIntervalForHighRiskEntry, we want to enter aggressively on any entry.
        if config.timeIntervalForHighRiskEntry(chart: chart).contains(currentBar.time) {
            return seekToOpenPosition(bar: currentBar, entryType: .initial)
        }
        // If the a previous trade exists, the direction of the trade matches the current bar:
        else if let lastTrade = sessionManager.trades.last, let currentBarDirection = currentBar.oneMinSignal?.direction {
            // if the last trade was stopped out in the current minute bar, enter aggressively on any entry
            if lastTrade.exitTime.isInSameMinute(date: currentBar.time) {
                return seekToOpenPosition(bar: currentBar, entryType: .initial)
            }
            // Check if signals from the end of the last trade to current bar are all of the same color as current
            // If yes, we need to decide if we want to enter on any Pullback or only Sweepspot
            // Otherwise, then enter aggressively on any entry
            else if chart.checkAllSameDirection(direction: currentBarDirection,
                                                fromKey: lastTrade.exitTime.generateDateIdentifier(),
                                                toKey: currentBar.time.generateDateIdentifier()) {
                // If the previous trade profit is higher than ProfitRequiredToReenterTradeonPullback,
                // we allow to enter on any pullback if no opposite signal on any timeframe is found from last trade to now
                if (lastTrade.profit ?? 0) > config.enterOnPullback {
                    return seekToOpenPosition(bar: currentBar, entryType: .pullBack)
                } else {
                    return seekToOpenPosition(bar: currentBar, entryType: .sweetSpot)
                }
            } else {
                return seekToOpenPosition(bar: currentBar, entryType: .initial)
            }
        }
        else {
            return seekToOpenPosition(bar: currentBar, entryType: .sweetSpot)
        }
    }
    
    private func exitPosition(currentBar: PriceBar, exitPrice: Double, exitMethod: ExitMethod) -> TradeActionType {
        guard let currentPosition = sessionManager.currentPosition else { return .noAction }
        
        let trade = Trade(direction: currentPosition.direction,
                          entryPrice: currentPosition.entryPrice,
                          exitPrice: exitPrice,
                          exitMethod: exitMethod,
                          entryTime: currentPosition.entryTime,
                          exitTime: currentBar.time)
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
            if entryBar.candleStick.close - previousLevel <= config.maxRisk {
                return StopLoss(stop: previousLevel, source: .supportResistanceLevel)
            }
        default:
            if previousLevel - entryBar.candleStick.close <= config.maxRisk {
                return StopLoss(stop: previousLevel, source: .supportResistanceLevel)
            }
        }
        
        // Method 3:
        let lowRounded = entryBar.candleStick.low.roundBasedOnDirection(direction: direction)
        let highRounded = entryBar.candleStick.high.roundBasedOnDirection(direction: direction)
        let closeRounded = entryBar.candleStick.close.roundBasedOnDirection(direction: direction)
        
        switch direction {
        case .long:
            return StopLoss(stop: min(lowRounded - 1, closeRounded - config.minBarStop), source: .currentBar)
        default:
            return StopLoss(stop: max(highRounded + 1, closeRounded + config.minBarStop), source: .currentBar)
        }
    }
    
    // given an entry bar and direction of the trade, find the previous resistence/support level, if none exists, use the current one +-1
    private func findPreviousLevel(direction: TradeDirection, entryBar: PriceBar, minimalDistance: Double = 1) -> Double? {
        guard let startIndex = chart.timeKeys.firstIndex(of: entryBar.identifier),
            let initialBarStop = entryBar.oneMinSignal?.stop,
            entryBar.oneMinSignal?.direction == direction else {
            return nil
        }
        
        let initialBarStopRounded = initialBarStop.roundBasedOnDirection(direction: direction)
        var previousLevel: Double = initialBarStopRounded
        let timeKeysUpToIncludingStartIndex = chart.timeKeys[0...startIndex]
        
        outerLoop: for timeKey in timeKeysUpToIncludingStartIndex.reversed() {
            guard let currentPriceBar = chart.priceBars[timeKey] else { continue }
            
            if currentPriceBar.oneMinSignal?.direction != direction {
                break
            } else if let level = currentPriceBar.oneMinSignal?.stop {
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
            start.oneMinSignal?.stop != nil else {
                return nil
        }
        
        let timeKeysUpToIncludingStartIndex = chart.timeKeys[0...startIndex]
        let color: SignalColor = direction == .long ? .blue : .red
        var greenBars: [PriceBar] = []
        var coloredBars: [PriceBar] = []
        var coloredBarsIsComplete: Bool = false
        
        for timeKey in timeKeysUpToIncludingStartIndex.reversed() {
            guard let priceBar = chart.priceBars[timeKey], priceBar.oneMinSignal?.direction == direction else {
                break
            }
            
            // if the current bar is green or an opposite color, it's not a sweetspot
            if coloredBars.isEmpty, priceBar.barColor != color {
                return nil
            }
            // if the current bar is the correct color, add it to 'coloredBars'
            else if !coloredBarsIsComplete, priceBar.barColor == color {
                coloredBars.insert(priceBar, at: 0)
            }
            // if the current bar is green, 'coloredBars' array is complete, start adding to 'greenBars'
            else if !coloredBars.isEmpty, priceBar.barColor == .green {
                coloredBarsIsComplete = true
                greenBars.insert(priceBar, at: 0)
            }
            // if the current bar is not green anymore, 'greenBars' array is complete, the sweet spot is formed
            else if coloredBarsIsComplete, priceBar.barColor != .green {
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
            bar.oneMinSignal?.stop != nil,
            bar.oneMinSignal?.direction == direction else {
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
}
