//
//  TraderBot.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-21.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class TraderBot {
    private let config = ConfigurationManager.shared
    private let Buffer = 1.0
    
    var sessionManager: BaseSessionManager
    var chart: Chart
    
    init(chart: Chart, sessionManager: BaseSessionManager) {

        self.chart = chart
        self.sessionManager = sessionManager
    }
    
    func generateSimSession(upToPriceBar: PriceBar? = nil, completion: @escaping () -> ()) {
        guard chart.timeKeys.count > 1, let lastBar = upToPriceBar ?? chart.absLastBar else {
            return
        }
        
        sessionManager.resetSession()
        
        var previousBar: PriceBar?
        for timeKey in self.chart.timeKeys {
            if timeKey == lastBar.identifier {
                break
            }
            
            guard let currentBar = self.chart.priceBars[timeKey] else { continue }
            
            if let previousBar = previousBar, previousBar.time.day() != currentBar.time.day() {
                sessionManager.highRiskEntriesTaken = 0
            }
            
            let actions = self.decide(priceBar: currentBar)
            self.sessionManager.processActions(priceBarTime: currentBar.time, actions: actions, completion: { _ in
            })
            
            previousBar = currentBar
        }
        
        completion()
    }
    
    // decide trade actions at the given PriceBar object, returns the list of actions need to be performed
    func decide(priceBar: PriceBar? = nil) -> [TradeActionType] {
        guard chart.timeKeys.count > 1,
            let priceBar = priceBar ?? chart.lastBar,
            chart.timeKeys.contains(priceBar.identifier),
            let priceBarIndex = chart.timeKeys.firstIndex(of: priceBar.identifier),
            priceBarIndex > 0,
            let previousPriceBar = chart.priceBars[chart.timeKeys[priceBarIndex - 1]]
            else {
                return [.noAction(entryType: nil, reason: .other)]
        }
        
        // already have current position, update the stoploss or close it if needed
        if let currentPosition = sessionManager.pos {
            
            // Exit when the the low of the price hit the current stop loss (Required in simulation only)
            if !sessionManager.liveMonitoring {
                switch sessionManager.pos?.direction {
                case .long:
                    if let stop = sessionManager.pos?.stopLoss?.stop,
                        priceBar.candleStick.low <= stop {
                        let exitMethod: ExitMethod = sessionManager.pos?.stopLoss?.source == .supportResistanceLevel ||
                            sessionManager.pos?.stopLoss?.source == .currentBar ? .hitStoploss : .twoGreenBars
                        let verifyAction = verifyStopWasHit(duringBar: priceBar, exitMethod: exitMethod)
                        
                        sessionManager.processActions(priceBarTime: priceBar.time, actions: [verifyAction]) { error in
                        }
                        
                        switch handleOpeningNewTrade(currentBar: priceBar) {
                        case .openPosition(let position, let entryType):
                            return [.openPosition(newPosition: position, entryType: entryType)]
                        default:
                            return [.noAction(entryType: nil, reason: .noTradingAction)]
                        }
                    }
                default:
                    if let stop = sessionManager.pos?.stopLoss?.stop,
                        let stopSource = sessionManager.pos?.stopLoss?.source,
                        priceBar.candleStick.high >= stop {
                        let exitMethod: ExitMethod = stopSource == .supportResistanceLevel || stopSource == .currentBar ? .hitStoploss : .twoGreenBars
                        let verifyAction = verifyStopWasHit(duringBar: priceBar, exitMethod: exitMethod)
                        
                        sessionManager.processActions(priceBarTime: priceBar.time, actions: [verifyAction]) { error in
                        }
                        
                        switch handleOpeningNewTrade(currentBar: priceBar) {
                        case .openPosition(let position, let entryType):
                            return [.openPosition(newPosition: position, entryType: entryType)]
                        default:
                            return [.noAction(entryType: nil, reason: .noTradingAction)]
                        }
                    }
                }
            }
            
            // If we reached FlatPositionsTime, exit the trade immediately
            if Date.flatPositionsTime(date: priceBar.time) <= priceBar.time && !config.byPassTradingTimeRestrictions {
                return [forceExitPosition(atEndOfBar: priceBar, exitMethod: .endOfDay)]
            }
            
            // If we reached ClearPositionTime, close current position on any blue/red bar in favor of the position
            if Date.clearPositionTime(date: priceBar.time) <= priceBar.time && !config.byPassTradingTimeRestrictions {
                switch sessionManager.pos?.direction {
                case .long:
                    if priceBar.barColor == .blue {
                        return [forceExitPosition(atEndOfBar: priceBar, exitMethod: .endOfDay)]
                    }
                default:
                    if priceBar.barColor == .red {
                        return [forceExitPosition(atEndOfBar: priceBar, exitMethod: .endOfDay)]
                    }
                }
            }
            
            // Exit when bar of opposite color bar appears
            switch sessionManager.pos?.direction {
            case .long:
                if priceBar.barColor == .red {
                    let exitAction = forceExitPosition(atEndOfBar: priceBar, exitMethod: .signalReversed)
                    switch handleOpeningNewTrade(currentBar: priceBar) {
                    case .openPosition(let position, let entryType):
                        return [.reversePosition(oldPosition: currentPosition, newPosition: position, entryType: entryType)]
                    default:
                        return [exitAction]
                    }
                }
            default:
                if priceBar.barColor == .blue {
                   let exitAction = forceExitPosition(atEndOfBar: priceBar, exitMethod: .signalReversed)
                    
                    switch handleOpeningNewTrade(currentBar: priceBar) {
                    case .openPosition(let position, let entryType):
                        return [.reversePosition(oldPosition: currentPosition, newPosition: position, entryType: entryType)]
                    default:
                        return [exitAction]
                    }
                }
            }
            
            // Exit when the bar is over 'config.takeProfitBarLength' points long
            if !Date.highRiskEntryInteval(date: priceBar.time).contains(priceBar.time),
                currentPosition.calulateProfit(currentPrice: priceBar.candleStick.close) >= config.takeProfitBarLength {
                
                switch currentPosition.direction {
                case .long:
                    if priceBar.candleStick.close - priceBar.candleStick.open >= config.takeProfitBarLength {
                        return [forceExitPosition(atEndOfBar: priceBar, exitMethod: .profitTaking)]
                    }
                case .short:
                    if priceBar.candleStick.open - priceBar.candleStick.close >= config.takeProfitBarLength {
                        return [forceExitPosition(atEndOfBar: priceBar, exitMethod: .profitTaking)]
                    }
                }
            }
            
            // If not exited the trade yet, update the current trade's stop loss:
            
            // Calculate the SL based on the 2 green bars(if applicable)
            var twoGreenBarsSL: Double = sessionManager.pos?.direction == .long ? 0 : Double.greatestFiniteMagnitude
            
            if previousPriceBar.barColor == .green,
                priceBar.barColor == .green,
                let currentStop = priceBar.oneMinSignal?.stop {
                
                let stopLossFromGreenBars: Double
                let securedProfit: Double
                switch sessionManager.pos?.direction {
                case .long:
                    stopLossFromGreenBars = min(previousPriceBar.candleStick.low, priceBar.candleStick.low).flooring(toNearest: 0.5) - Buffer
                    securedProfit = stopLossFromGreenBars - currentPosition.idealEntryPrice
                default:
                    stopLossFromGreenBars = max(previousPriceBar.candleStick.high, priceBar.candleStick.high).ceiling(toNearest: 0.5) + Buffer
                    securedProfit = currentPosition.idealEntryPrice - stopLossFromGreenBars
                }
                
                if securedProfit < config.skipGreenExit, securedProfit >= config.greenExit {
                    switch sessionManager.pos?.direction {
                    case .long:
                        if stopLossFromGreenBars > currentStop {
                            // decide whether to use the bottom of the two green bars as SL or use 1 point under the 1 min stop
                            if stopLossFromGreenBars - currentStop > config.sweetSpot {
                                twoGreenBarsSL = stopLossFromGreenBars
                            } else {
                                twoGreenBarsSL = currentStop - Buffer
                            }
                        }
                    default:
                        if stopLossFromGreenBars < currentStop {
                            // decide whether to use the top of the two green bars as SL or use 1 point above the 1 min stop
                            if currentStop - stopLossFromGreenBars > config.sweetSpot {
                                twoGreenBarsSL = stopLossFromGreenBars
                            } else {
                                twoGreenBarsSL = currentStop + Buffer
                            }
                        }
                    }
                }
            }
            
            if var newStop: Double = sessionManager.pos?.stopLoss?.stop,
                var newStopSource: StopLossSource = sessionManager.pos?.stopLoss?.source {
                
                // Calculate the SL based on the previous S/R level and decide which of the two SLs should we use
                if let previousLevelSL: Double = findPreviousLevel(direction: sessionManager.pos!.direction, entryBar: priceBar) {
                    switch sessionManager.pos?.direction {
                    case .long:
                        newStop = max(twoGreenBarsSL, previousLevelSL).round(nearest: 0.25)
                        newStopSource = twoGreenBarsSL > previousLevelSL ? .twoGreenBars : .supportResistanceLevel
                    default:
                        newStop = min(twoGreenBarsSL, previousLevelSL).round(nearest: 0.25)
                        newStopSource = twoGreenBarsSL < previousLevelSL ? .twoGreenBars : .supportResistanceLevel
                    }
                }
                
                // Apply the new SL if it is more in favor than the existing SL
                switch sessionManager.pos!.direction {
                case .long:
                    if let stop = sessionManager.pos?.stopLoss?.stop, newStop > stop {
                        return [.updateStop(stop: StopLoss(stop: newStop, source: newStopSource))]
                    }
                default:
                    if let stop = sessionManager.pos?.stopLoss?.stop, newStop < stop {
                        return [.updateStop(stop: StopLoss(stop: newStop, source: newStopSource))]
                    }
                }
            }
        }
        // no current position, check if we should enter on the current bar
        else if sessionManager.pos == nil {
            return [handleOpeningNewTrade(currentBar: priceBar)]
        }
        
        return [.noAction(entryType: nil, reason: .noTradingAction)]
    }

    func buyAtMarket() -> TradeActionType {
        guard let currentPrice = chart.absLastBar?.candleStick.close,
            let currentTime = chart.absLastBarDate else { return .noAction(entryType: nil, reason: .other) }
        
        let buyPosition = Position(direction: .long, size: 1, entryTime: currentTime, idealEntryPrice: currentPrice, actualEntryPrice: currentPrice)
        return .openPosition(newPosition: buyPosition, entryType: .all)
    }
    
    func sellAtMarket() -> TradeActionType {
        guard let currentPrice = chart.absLastBar?.candleStick.close,
            let currentTime = chart.absLastBarDate else { return .noAction(entryType: nil, reason: .other) }
        
        let sellPosition = Position(direction: .short, size: 1, entryTime: currentTime, idealEntryPrice: currentPrice, actualEntryPrice: currentPrice)
        return .openPosition(newPosition: sellPosition, entryType: .all)
    }
    
    private func seekToOpenPosition(bar: PriceBar, entryType: EntryType) -> TradeActionType {
        if let newPosition: Position = checkForEntrySignal(direction: .long, bar: bar, entryType: entryType) ?? checkForEntrySignal(direction: .short, bar: bar, entryType: entryType) {
            
//            if let newPositionStop = newPosition.stopLoss?.stop,
//                let lastTrade = sessionManager.trades.last,
//                lastTrade.direction == newPosition.direction,
//                lastTrade.idealProfit < 0,
//                abs(lastTrade.idealExitPrice - newPositionStop) <= 0.25,
//                lastTrade.exitMethod == .hitStoploss {
//
//                print("Ignored repeated trade:", newPosition)
//                return .noAction(entryType: nil, reason: .noTradingAction)
//            }
            
            return .openPosition(newPosition: newPosition, entryType: entryType)
        }
        return .noAction(entryType: entryType, reason: .noTradingAction)
    }
    
    // return a Position object if the given bar presents a entry signal
    private func checkForEntrySignal(direction: TradeDirection, bar: PriceBar, entryType: EntryType = .pullBack) -> Position? {
        let color: SignalColor = direction == .long ? .blue : .red
        
        guard bar.barColor == color,
            checkForSignalConfirmation(direction: direction, bar: bar),
            bar.oneMinSignal?.direction == direction,
            let oneMinStop = bar.oneMinSignal?.stop,
            direction == .long ? bar.candleStick.close >= oneMinStop : bar.candleStick.close <= oneMinStop,
            var stopLoss = calculateStopLoss(direction: direction, entryBar: bar),
            let barIndex: Int = chart.timeKeys.firstIndex(of: bar.identifier),
            barIndex < chart.timeKeys.count - 1 else {
            return nil
        }
        
        let risk: Double = abs(bar.candleStick.close - stopLoss.stop)
        
        switch entryType {
        case .pullBack:
            guard let pullBack = checkForPullback(direction: direction, start: bar) else {
                return nil
            }
            
            switch direction {
            case .long:
                guard let pullbackLow = pullBack.getLowestPoint(),
                    pullbackLow < oneMinStop || !pullBack.greenBars.isEmpty else {
                    return nil
                }
            default:
                guard let pullbackHigh = pullBack.getHighestPoint(),
                    pullbackHigh > oneMinStop || !pullBack.greenBars.isEmpty else {
                    return nil
                }
            }
            
        case .sweetSpot:
            guard let pullBack = checkForPullback(direction: direction, start: bar) else {
                return nil
            }
            
            // check for SweetSpot bounce
            switch direction {
            case .long:
                guard let pullbackLow = pullBack.getLowestPoint(),
                    pullbackLow < oneMinStop || pullbackLow - oneMinStop <= config.sweetSpot else {
                    return nil
                }
            default:
                guard let pullbackHigh = pullBack.getHighestPoint(),
                    pullbackHigh > oneMinStop || oneMinStop - pullbackHigh <= config.sweetSpot else {
                    return nil
                }
            }
        default:
            break
        }
        
        if risk > config.maxRisk,
            Date.highRiskEntryInteval(date: bar.time).contains(bar.time),
            sessionManager.highRiskEntriesTaken < config.maxHighRiskEntryAllowed {
            sessionManager.highRiskEntriesTaken += 1
            stopLoss.stop = direction == .long ? bar.candleStick.close - config.maxRisk : bar.candleStick.close + config.maxRisk
            let position = Position(direction: direction,
                                    size: config.positionSize,
                                    entryTime: bar.time.getOffByMinutes(minutes: 1),
                                    idealEntryPrice: bar.candleStick.close,
                                    actualEntryPrice: bar.candleStick.close,
                                    stopLoss: stopLoss)
            return position
        } else if risk <= config.maxRisk {
            let position = Position(direction: direction,
                                    size: config.positionSize,
                                    entryTime: bar.time.getOffByMinutes(minutes: 1),
                                    idealEntryPrice: bar.candleStick.close,
                                    actualEntryPrice: bar.candleStick.close,
                                    stopLoss: stopLoss)
            return position
        }

        return nil
    }
    
    private func handleOpeningNewTrade(currentBar: PriceBar) -> TradeActionType {
        // stop trading if P&L <= MaxDailyLoss
        if sessionManager.getTotalPAndL() <= config.maxDailyLoss {
            return .noAction(entryType: nil, reason: .exceedLoss)
        }
        
        // time has pass outside the TradingTimeInterval, no more opening new positions, but still allow to close off existing position
        if !Date.tradingTimeInterval(date: currentBar.time).contains(currentBar.time) && !config.byPassTradingTimeRestrictions {
            return .noAction(entryType: nil, reason: .outsideTradingHours)
        }
        
        // no entrying trades during lunch hour
        if config.noEntryDuringLunch,
            Date.lunchInterval(date: currentBar.time).contains(currentBar.time), !config.byPassTradingTimeRestrictions {
            return .noAction(entryType: nil, reason: .lunchHour)
        }
        
        // If we are in TimeIntervalForHighRiskEntry and highRiskEntriesTaken < config.maxHighRiskEntryAllowed, we want to enter aggressively on any entry.
        if Date.highRiskEntryInteval(date: currentBar.time).contains(currentBar.time),
            sessionManager.highRiskEntriesTaken < config.maxHighRiskEntryAllowed {
            return seekToOpenPosition(bar: currentBar, entryType: .all)
        }
        
        if sessionManager.trades.isEmpty {
            return seekToOpenPosition(bar: currentBar, entryType: .all)
        }
        
        if let lastTrade = sessionManager.trades.last, let currentBarDirection = currentBar.oneMinSignal?.direction {
            
            // if the last trade was stopped out in the current minute bar AND last trade's direction is opposite of current bar direction, then enter aggressively on any entry
            if lastTrade.exitTime.isInSameMinute(date: currentBar.time),
                lastTrade.direction != currentBarDirection,
                lastTrade.exitMethod != .profitTaking {
                return seekToOpenPosition(bar: currentBar, entryType: .all)
            }
            
            // Check if the direction from the start of the last trade to current bar are same as current
            // If yes, we need to decide if we want to enter on any Pullback or only SweetSpot
            // Otherwise, then enter aggressively on any entry
            if chart.checkAllSameDirection(direction: currentBarDirection,
                                           currBar: currentBar,
                                           fromKey: lastTrade.exitTime.generateDateIdentifier(),
                                           toKey: currentBar.time.generateDateIdentifier()) {
                
                // If the previous trade profit is higher than enterOnPullback,
                // we allow to enter on any pullback if no opposite signal on any timeframe is found from last trade to now
                if lastTrade.idealProfit > config.enterOnAnyPullback, lastTrade.exitMethod != .profitTaking {
                    return seekToOpenPosition(bar: currentBar, entryType: .pullBack)
                } else {
                    let action = seekToOpenPosition(bar: currentBar, entryType: .sweetSpot)
                    
//                    switch action {
//                    case .openPosition(let newPosition, _):
//                        if let newPositionStop = newPosition.stopLoss?.stop,
//                            lastTrade.direction == newPosition.direction,
//                            lastTrade.idealProfit < 0,
//                            abs(lastTrade.idealExitPrice - newPositionStop) <= 0.25,
//                            lastTrade.exitMethod == .hitStoploss {
//
//                            print("Ignoring repeated losing trade:", newPosition)
//                            return .noAction(entryType: nil, reason: .noTradingAction)
//                        }
//                    default:
//                        break
//                    }
                    
                    return action
                }
            } else {
                return seekToOpenPosition(bar: currentBar, entryType: .all)
            }
        }
        
        return seekToOpenPosition(bar: currentBar, entryType: .sweetSpot)
    }
    
    private func forceExitPosition(atEndOfBar: PriceBar, exitMethod: ExitMethod) -> TradeActionType {
        guard let currentPosition = sessionManager.pos else { return .noAction(entryType: nil, reason: .other) }
        
        return .forceClosePosition(closedPosition: currentPosition, closingPrice: atEndOfBar.candleStick.close, closingTime: atEndOfBar.time.getOffByMinutes(minutes: 1), reason: exitMethod)
    }
    
    private func verifyStopWasHit(duringBar: PriceBar, exitMethod: ExitMethod) -> TradeActionType {
        guard let currentPosition = sessionManager.pos, let stop = currentPosition.stopLoss?.stop else {
            return .noAction(entryType: nil, reason: .other)
        }
        
        return .verifyPositionClosed(closedPosition: currentPosition, closingPrice: stop, closingTime: duringBar.time, reason: exitMethod)
    }
    
    private func calculateStopLoss(direction: TradeDirection, entryBar: PriceBar) -> StopLoss? {
        // Go with the methods in order. If the stoploss is > MaxRisk, go to the next method
        // Worst case would be method 3 and still having stoploss > MaxRisk, either skip the trade or apply a hard stop at the MaxRisk
        
        // Method 1: previous resistence/support level
        // Method 2: current resistence/support level plus or minus 1 depending on direction
        // Method 3: current bar's high plus 1 or low, minus 1 depending on direction(min 5 points)
        
        // Method 1 and 2:
        guard let previousLevel: Double = findPreviousLevel(direction: direction, entryBar: entryBar) else { return nil }
        
        let closeRounded = entryBar.candleStick.close.roundBasedOnDirection(direction: direction)
        let highRiskAllowed = Date.highRiskEntryInteval(date: entryBar.time).contains(entryBar.time) && sessionManager.highRiskEntriesTaken < config.maxHighRiskEntryAllowed
        
        switch direction {
        case .long:
            if entryBar.candleStick.close - previousLevel <= config.maxRisk || highRiskAllowed {
                return StopLoss(stop: min(previousLevel, closeRounded - config.minStop), source: .supportResistanceLevel)
            } else if let currentStop = entryBar.oneMinSignal?.stop,
                entryBar.candleStick.close - (currentStop - Buffer) <= config.maxRisk || highRiskAllowed {
                return StopLoss(stop: min(currentStop - Buffer, closeRounded - config.minStop), source: .supportResistanceLevel)
            }
        default:
            if previousLevel - entryBar.candleStick.close <= config.maxRisk || highRiskAllowed {
                return StopLoss(stop: max(previousLevel, closeRounded + config.minStop), source: .supportResistanceLevel)
            } else if let currentStop = entryBar.oneMinSignal?.stop,
                (currentStop + Buffer) - entryBar.candleStick.close <= config.maxRisk || highRiskAllowed {
                return StopLoss(stop: max(currentStop + Buffer, closeRounded + config.minStop), source: .supportResistanceLevel)
            }
        }
        
        // Method 3:
        let lowRounded = entryBar.candleStick.low.roundBasedOnDirection(direction: direction)
        let highRounded = entryBar.candleStick.high.roundBasedOnDirection(direction: direction)
        
        switch direction {
        case .long:
            return StopLoss(stop: min(lowRounded - Buffer, closeRounded - config.minStop), source: .currentBar)
        default:
            return StopLoss(stop: max(highRounded + Buffer, closeRounded + config.minStop), source: .currentBar)
        }
    }
    
    // given an entry bar and direction of the trade, find the previous resistence/support level, if none exists, use the current one +-1
    private func findPreviousLevel(direction: TradeDirection, entryBar: PriceBar) -> Double? {
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
                    if previousLevel - levelRounded > Buffer {
                        previousLevel = levelRounded
                        break outerLoop
                    }
                default:
                    if levelRounded - previousLevel > Buffer {
                        previousLevel = levelRounded
                        break outerLoop
                    }
                }
            }
        }
        
        if previousLevel == initialBarStopRounded {
            switch direction {
            case .long:
                previousLevel = previousLevel - Buffer
            default:
                previousLevel = previousLevel + Buffer
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
        var coloredBar: PriceBar?
        
        for timeKey in timeKeysUpToIncludingStartIndex.reversed() {
            guard let priceBar = chart.priceBars[timeKey], priceBar.oneMinSignal?.direction == direction else {
                break
            }
            
            if coloredBar == nil, priceBar.barColor == color {
                coloredBar = priceBar
            } else if let coloredBar = coloredBar,
                abs((priceBar.oneMinSignal?.stop ?? 0) - (coloredBar.oneMinSignal?.stop ?? 0)) <= 0.25,
                priceBar.barColor == .green {
                greenBars.insert(priceBar, at: 0)
            } else {
                break
            }
        }
        
        if let coloredBar = coloredBar {
            let sweetSpot = Pullback(direction: direction, greenBars: greenBars, coloredBar: coloredBar)
            return sweetSpot
        }
        
        return nil
    }
    
    // check if the current bar has a buy or sell confirmation(signal align on all 3 timeframes)
    private func checkForSignalConfirmation(direction: TradeDirection, bar: PriceBar) -> Bool {
        guard let startIndex = chart.timeKeys.firstIndex(of: bar.identifier) else {
            return false
        }
        
        let timeKeysUpToIncludingStartIndex = chart.timeKeys[0...startIndex]
        
        var earliest2MinConfirmationBar: PriceBar?
        var finishedScanningFor2MinConfirmation = false
        
        var earliest3MinConfirmationBar: PriceBar?
        var finishedScanningFor3MinConfirmation = false
        
        for timeKey in timeKeysUpToIncludingStartIndex.reversed() {
            guard let priceBar = chart.priceBars[timeKey],
                !finishedScanningFor2MinConfirmation || !finishedScanningFor3MinConfirmation else { break }
            
            for signal in priceBar.signals where signal.inteval != .oneMin {
                guard let signalDirection = signal.direction else { continue }
                
                if signalDirection == direction {
                    switch signal.inteval {
                    case .twoMin:
                        if !finishedScanningFor2MinConfirmation {
                            earliest2MinConfirmationBar = priceBar
                            
                            // Once we set earliest2MinConfirmationBar, 2MinConfirm is finished
                            finishedScanningFor2MinConfirmation = true
                        }
                    case .threeMin:
                        if !finishedScanningFor3MinConfirmation {
                            earliest3MinConfirmationBar = priceBar
                            
                            // Once we set earliest3MinConfirmationBar, 3MinConfirm is finished
                            finishedScanningFor3MinConfirmation = true
                        }
                    default:
                        break
                    }
                } else {
                    switch signal.inteval {
                    case .twoMin:
                        finishedScanningFor2MinConfirmation = true
                    case .threeMin:
                        finishedScanningFor3MinConfirmation = true
                    default:
                        break
                    }
                }
            }

            // This enables early exit rather than checking for empty PriceBars
            if finishedScanningFor2MinConfirmation && finishedScanningFor3MinConfirmation {
                break
            }
        }
        
        return earliest2MinConfirmationBar != nil && earliest3MinConfirmationBar != nil
    }
    
    // Unused
    private func checkFor3MinSignalConfirmation(direction: TradeDirection, bar: PriceBar) -> Bool {
        guard let startIndex = chart.timeKeys.firstIndex(of: bar.identifier) else {
            return false
        }
        
        let timeKeysUpToIncludingStartIndex = chart.timeKeys[0...startIndex]
        
        for timeKey in timeKeysUpToIncludingStartIndex.reversed() {
            guard let priceBar = chart.priceBars[timeKey] else { break }
            
            for signal in priceBar.signals where signal.inteval == .threeMin {
                guard let signalDirection = signal.direction else { continue }
                
                if signalDirection == direction {
                    return true
                } else {
                    return false
                }
            }
        }
        
        return false
    }
}
