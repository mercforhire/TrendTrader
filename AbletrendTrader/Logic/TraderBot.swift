//
//  TraderBot.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-21.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class TraderBot {
    var sessionManager: BaseSessionManager
    var chart: Chart
    var tradingSetting: TradingSettings
    
    init(chart: Chart, sessionManager: BaseSessionManager, tradingSetting: TradingSettings) {
        self.chart = chart
        self.sessionManager = sessionManager
        self.tradingSetting = tradingSetting
    }
    
    func generateSimSession(upToPriceBar: PriceBar? = nil, completion: @escaping () -> ()) {
        guard chart.timeKeys.count > 1, let lastBar = upToPriceBar ?? chart.absLastBar else {
            return
        }
        
        var previousBar: PriceBar?
        for timeKey in self.chart.timeKeys {
            if timeKey == lastBar.identifier {
                break
            }
            
            guard let currentBar = self.chart.priceBars[timeKey]
//                , currentBar.time > Date().getPastOrFutureDate(days: 0, months: -1, years: 0)
            else { continue }
            
            if let previousBar = previousBar, previousBar.time.day() != currentBar.time.day() {
                sessionManager.highRiskEntriesTaken = 0
            }
            
            // US Holidays
            if currentBar.time.year() == 2019, currentBar.time.month() == 11, currentBar.time.day() == 22 {
                continue
            }
            else if currentBar.time.year() == 2020, currentBar.time.month() == 5, currentBar.time.day() == 25 {
                continue
            }
            else if currentBar.time.year() == 2020, currentBar.time.month() == 9, currentBar.time.day() == 2 {
                continue
            }
            
            // FOMC days
            if currentBar.time.year() == 2019, currentBar.time.month() == 12, currentBar.time.day() == 11 {
                tradingSetting.fomcDay = true
            }
            else if currentBar.time.year() == 2020, currentBar.time.month() == 1, currentBar.time.day() == 29 {
                tradingSetting.fomcDay = true
            }
            else if currentBar.time.year() == 2020, currentBar.time.month() == 4, currentBar.time.day() == 29 {
                tradingSetting.fomcDay = true
            }
            else {
                tradingSetting.fomcDay = false
            }
            
            let action = self.decide(priceBar: currentBar)
            self.sessionManager.processAction(priceBarTime: currentBar.time, action: action, completion: { _ in
            })
            
            previousBar = currentBar
        }
        
        completion()
    }
    
    // decide trade actions at the given PriceBar object, returns the list of actions need to be performed
    func decide(priceBar: PriceBar? = nil) -> TradeActionType {
        guard chart.timeKeys.count > 1,
            let priceBar = priceBar ?? chart.lastBar,
            chart.timeKeys.contains(priceBar.identifier),
            let priceBarIndex = chart.timeKeys.firstIndex(of: priceBar.identifier),
            priceBarIndex > 0,
            let previousPriceBar = chart.priceBars[chart.timeKeys[priceBarIndex - 1]],
            let latestPriceBar = chart.priceBars[chart.timeKeys[priceBarIndex + 1]]
            else {
                return .noAction(entryType: nil, reason: .other)
        }
        
        // already have current position, update the stoploss or close it if needed
        if let currentPosition = sessionManager.pos {
            
            // Exit when the the low of the price hit the current stop loss (Required in simulation only)
            if !sessionManager.liveMonitoring || !currentPosition.executed {
                switch sessionManager.pos?.direction {
                case .long:
                    if let stop = sessionManager.pos?.stopLoss?.stop,
                        priceBar.candleStick.low <= stop {
                        let exitMethod: ExitMethod = sessionManager.pos?.stopLoss?.source == .supportResistanceLevel ||
                            sessionManager.pos?.stopLoss?.source == .currentBar ? .hitStoploss : .twoGreenBars
                        let verifyAction = verifyStopWasHit(duringBar: priceBar, exitMethod: exitMethod)
                        
                        sessionManager.processAction(priceBarTime: priceBar.time, action: verifyAction) { error in
                        }
                        
                        switch handleOpeningNewTrade(currentBar: priceBar, latestBar: latestPriceBar) {
                        case .openPosition(let position, let entryType):
                            return .openPosition(newPosition: position, entryType: entryType)
                        default:
                            return .refresh
                        }
                    }
                default:
                    if let stop = sessionManager.pos?.stopLoss?.stop,
                        let stopSource = sessionManager.pos?.stopLoss?.source,
                        priceBar.candleStick.high >= stop {
                        let exitMethod: ExitMethod = stopSource == .supportResistanceLevel || stopSource == .currentBar ? .hitStoploss : .twoGreenBars
                        let verifyAction = verifyStopWasHit(duringBar: priceBar, exitMethod: exitMethod)
                        
                        sessionManager.processAction(priceBarTime: priceBar.time, action: verifyAction) { error in
                        }
                        
                        switch handleOpeningNewTrade(currentBar: priceBar, latestBar: latestPriceBar) {
                        case .openPosition(let position, let entryType):
                            return .openPosition(newPosition: position, entryType: entryType)
                        default:
                            return .refresh
                        }
                    }
                }
            }
            
            // exit trade during FOMC hour
            if tradingSetting.fomcInterval(date: priceBar.time).contains(priceBar.time) &&
                tradingSetting.fomcDay &&
                !tradingSetting.byPassTradingTimeRestrictions {
                
                return forceExitPosition(atEndOfBar: priceBar, exitMethod: .manual)
            }
            
            // If we reached FlatPositionsTime, exit the trade immediately
            if tradingSetting.flatPositionsTime(date: priceBar.time) <= priceBar.time && !tradingSetting.byPassTradingTimeRestrictions {
                return forceExitPosition(atEndOfBar: priceBar, exitMethod: .endOfDay)
            }
            
            // If we reached ClearPositionTime, close current position on any blue/red bar in favor of the position
            if tradingSetting.clearPositionTime(date: priceBar.time) <= priceBar.time && !tradingSetting.byPassTradingTimeRestrictions {
                switch sessionManager.pos?.direction {
                case .long:
                    if priceBar.barColor == .blue {
                        return forceExitPosition(atEndOfBar: priceBar, exitMethod: .endOfDay)
                    }
                default:
                    if priceBar.barColor == .red {
                        return forceExitPosition(atEndOfBar: priceBar, exitMethod: .endOfDay)
                    }
                }
            }
            
            // Exit when bar of opposite color bar appears
            switch sessionManager.pos?.direction {
            case .long:
                if priceBar.barColor == .red {
                    let exitAction = forceExitPosition(atEndOfBar: priceBar, exitMethod: .signalReversed)
                    return exitAction
                }
            default:
                if priceBar.barColor == .blue {
                    let exitAction = forceExitPosition(atEndOfBar: priceBar, exitMethod: .signalReversed)
                    return exitAction
                }
            }
            
            // Exit when the bar is over 'config.takeProfitBarLength' points long
            if currentPosition.calulateProfit(currentPrice: priceBar.candleStick.close) >= tradingSetting.takeProfitBarLength {
                switch currentPosition.direction {
                case .long:
                    if priceBar.candleStick.close - priceBar.candleStick.open >= tradingSetting.takeProfitBarLength {
                        return forceExitPosition(atEndOfBar: priceBar, exitMethod: .profitTaking)
                    }
                case .short:
                    if priceBar.candleStick.open - priceBar.candleStick.close >= tradingSetting.takeProfitBarLength {
                        return forceExitPosition(atEndOfBar: priceBar, exitMethod: .profitTaking)
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
                    stopLossFromGreenBars = min(previousPriceBar.candleStick.low, priceBar.candleStick.low).flooring(toNearest: 0.5) - tradingSetting.buffer
                    securedProfit = stopLossFromGreenBars - currentPosition.idealEntryPrice
                default:
                    stopLossFromGreenBars = max(previousPriceBar.candleStick.high, priceBar.candleStick.high).ceiling(toNearest: 0.5) + tradingSetting.buffer
                    securedProfit = currentPosition.idealEntryPrice - stopLossFromGreenBars
                }
                
                if securedProfit < tradingSetting.skipGreenExit, securedProfit >= tradingSetting.greenExit {
                    switch sessionManager.pos?.direction {
                    case .long:
                        if stopLossFromGreenBars > currentStop {
                            // decide whether to use the bottom of the two green bars as SL or use 1 point under the 1 min stop
                            if stopLossFromGreenBars - currentStop > tradingSetting.sweetSpot {
                                twoGreenBarsSL = stopLossFromGreenBars
                            } else {
                                twoGreenBarsSL = currentStop - tradingSetting.buffer
                            }
                        }
                    default:
                        if stopLossFromGreenBars < currentStop {
                            // decide whether to use the top of the two green bars as SL or use 1 point above the 1 min stop
                            if currentStop - stopLossFromGreenBars > tradingSetting.sweetSpot {
                                twoGreenBarsSL = stopLossFromGreenBars
                            } else {
                                twoGreenBarsSL = currentStop + tradingSetting.buffer
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
                    if let stop = sessionManager.pos?.stopLoss?.stop, newStop - stop >= 0.25 {
                        return .updateStop(stop: StopLoss(stop: newStop, source: newStopSource))
                    }
                default:
                    if let stop = sessionManager.pos?.stopLoss?.stop, stop - newStop >= 0.25 {
                        return .updateStop(stop: StopLoss(stop: newStop, source: newStopSource))
                    }
                }
            }
        }
        // no current position, check if we should enter on the current bar
        else if sessionManager.pos == nil {
            return handleOpeningNewTrade(currentBar: priceBar, latestBar: latestPriceBar)
        }
        
        return .noAction(entryType: nil, reason: .noTradingAction)
    }

    func buyAtMarket() -> TradeActionType {
        guard let currentPrice = chart.absLastBar?.candleStick.close,
            let currentTime = chart.absLastBarDate else { return .noAction(entryType: nil, reason: .other) }
        
        let buyPosition = Position(executed: true,
                                   direction: .long,
                                   size: 1,
                                   entryTime: currentTime,
                                   idealEntryPrice: currentPrice,
                                   actualEntryPrice: currentPrice)
        return .openPosition(newPosition: buyPosition, entryType: .all)
    }
    
    func sellAtMarket() -> TradeActionType {
        guard let currentPrice = chart.absLastBar?.candleStick.close,
            let currentTime = chart.absLastBarDate else { return .noAction(entryType: nil, reason: .other) }
        
        let sellPosition = Position(executed: true,
                                    direction: .short,
                                    size: 1,
                                    entryTime: currentTime,
                                    idealEntryPrice: currentPrice,
                                    actualEntryPrice: currentPrice)
        return .openPosition(newPosition: sellPosition, entryType: .all)
    }
    
    private func seekToOpenPosition(bar: PriceBar, latestBar: PriceBar, entryType: EntryType) -> TradeActionType {
        if var newPosition: Position =
            checkForEntrySignal(direction: .long, bar: bar, latestBar: latestBar, entryType: entryType)
                ??
            checkForEntrySignal(direction: .short, bar: bar, latestBar: latestBar, entryType: entryType) {
            
            if tradingSetting.profitAvoidSameDirection > 0,
                let lastTrade = sessionManager.trades.last,
                lastTrade.exitTime.isInSameDay(date: newPosition.entryTime),
                lastTrade.direction == newPosition.direction,
                lastTrade.idealProfit > tradingSetting.profitAvoidSameDirection {
                sessionManager.delegate?.newLogAdded(log: "Ignored same direction trade after significant profit: \(TradeActionType.openPosition(newPosition: newPosition, entryType: entryType).description(actionBarTime: bar.time, accountId: sessionManager.accountId))")

                return .noAction(entryType: nil, reason: .lowQualityTrade)
            }
            
            if !checkNotTooFarFromSupport(direction: newPosition.direction, bar: bar) {
                sessionManager.delegate?.newLogAdded(log: "Ignored too far from support trade: \(TradeActionType.openPosition(newPosition: newPosition, entryType: entryType).description(actionBarTime: bar.time, accountId: sessionManager.accountId))")

                return .noAction(entryType: nil, reason: .lowQualityTrade)
            }
            
            if tradingSetting.avoidTakingSameTrade,
                let newPositionStop = newPosition.stopLoss?.stop,
                let lastTrade = sessionManager.trades.last,
                lastTrade.direction == newPosition.direction,
                abs(lastTrade.idealExitPrice - newPositionStop) <= tradingSetting.buffer / 2,
                chart.checkAllSameDirection(direction: lastTrade.direction, fromKey: lastTrade.exitTime.generateDateIdentifier(), toKey: bar.time.generateDateIdentifier()),
                lastTrade.exitMethod == .hitStoploss {
                
                sessionManager.delegate?.newLogAdded(log: "Ignored repeated trade: \(TradeActionType.openPosition(newPosition: newPosition, entryType: entryType).description(actionBarTime: bar.time, accountId: sessionManager.accountId))")

                return .noAction(entryType: nil, reason: .repeatedTrade)
            }
            
            if tradingSetting.avoidTakingSameLosingTrade {
                if let newPositionStop = newPosition.stopLoss?.stop,
                    let lastTrade = sessionManager.trades.last,
                    lastTrade.direction == newPosition.direction,
                    lastTrade.idealProfit < 0,
                    abs(lastTrade.idealExitPrice - newPositionStop) <= tradingSetting.buffer / 2,
                    lastTrade.exitMethod == .hitStoploss {

                    sessionManager.delegate?.newLogAdded(log: "Ignored repeated trade: \(TradeActionType.openPosition(newPosition: newPosition, entryType: .all).description(actionBarTime: bar.time, accountId: sessionManager.accountId))")

                    return .noAction(entryType: nil, reason: .repeatedTrade)
                }
            }
            
            if tradingSetting.drawdownLimit > 0, sessionManager.state.modelDrawdown > 0 {
                let lastTrade = sessionManager.trades.last
                
                if (!sessionManager.state.simMode && lastTrade == nil) || (lastTrade != nil && lastTrade!.executed) {
                    if !sessionManager.state.probationMode && sessionManager.state.modelDrawdown >= tradingSetting.drawdownLimit {
                        newPosition.executed = false
                        sessionManager.printLog ? print("Drawdown: $\(String(format: "%.2f", sessionManager.state.modelDrawdown)) over $\(String(format: "%.2f", tradingSetting.drawdownLimit)), entering sim mode:") : nil
                    }
                    else if sessionManager.state.probationMode &&
                        sessionManager.state.modelDrawdown >= max(tradingSetting.drawdownLimit, sessionManager.state.latestTrough) {
                        newPosition.executed = false
                        sessionManager.printLog ? print("Drawdown: $\(String(format: "%.2f", sessionManager.state.modelDrawdown)) over $\(String(format: "%.2f", max(tradingSetting.drawdownLimit, sessionManager.state.latestTrough))), entering sim mode:") : nil
                    }
                } else if (sessionManager.state.simMode && lastTrade == nil) || (lastTrade != nil && !lastTrade!.executed) {
                    if sessionManager.state.modelDrawdown >= sessionManager.state.latestTrough * 0.7 {
                        newPosition.executed = false
                        sessionManager.printLog ? print("Drawdown: $\(String(format: "%.2f", sessionManager.state.modelDrawdown)) still over $\(String(format: "%.2f", sessionManager.state.latestTrough * 0.7)), remain in sim mode.") : nil
                    }
                }
            }
            
            return .openPosition(newPosition: newPosition, entryType: entryType)
        }
        return .noAction(entryType: entryType, reason: .noTradingAction)
    }
    
    // return a Position object if the given bar presents a entry signal
    private func checkForEntrySignal(direction: TradeDirection, bar: PriceBar, latestBar: PriceBar, entryType: EntryType = .pullBack) -> Position? {
        let color: SignalColor = direction == .long ? .blue : .red
        
        guard bar.barColor == color,
            checkForSignalConfirmation(direction: direction, bar: bar),
            bar.oneMinSignal?.direction == direction,
            let oneMinStop = bar.oneMinSignal?.stop,
            direction == .long ? bar.candleStick.close >= oneMinStop : bar.candleStick.close <= oneMinStop,
            let stopLoss = calculateStopLoss(direction: direction, entryBar: bar),
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
                    pullbackLow < oneMinStop || pullbackLow - oneMinStop <= tradingSetting.sweetSpot else {
                    return nil
                }
            default:
                guard let pullbackHigh = pullBack.getHighestPoint(),
                    pullbackHigh > oneMinStop || oneMinStop - pullbackHigh <= tradingSetting.sweetSpot else {
                    return nil
                }
            }
        default:
            break
        }
        
        let position = Position(executed: true,
                                direction: direction,
                                size: tradingSetting.positionSize,
                                entryTime: bar.time.getOffByMinutes(minutes: 1),
                                idealEntryPrice: latestBar.candleStick.open,
                                actualEntryPrice: latestBar.candleStick.open,
                                stopLoss: stopLoss)
        
        if risk <= tradingSetting.maxRisk {
            
            if tradingSetting.highRiskEntryInteval(date: bar.time).contains(bar.time),
                sessionManager.highRiskEntriesTaken < tradingSetting.maxHighRiskEntryAllowed {
                sessionManager.highRiskEntriesTaken += 1
            }
            
            return position
        }

        return nil
    }
    
    private func handleOpeningNewTrade(currentBar: PriceBar, latestBar: PriceBar) -> TradeActionType {
        // stop trading if P&L <= MaxDailyLoss
        if sessionManager.getDailyPAndL(day: currentBar.time) <= tradingSetting.maxDailyLoss {
            return .noAction(entryType: nil, reason: .exceedLoss)
        }
        
        // no entering trades during FOMC hour
        if tradingSetting.fomcInterval(date: currentBar.time).contains(currentBar.time) &&
            tradingSetting.fomcDay &&
            !tradingSetting.byPassTradingTimeRestrictions {
            
            return .noAction(entryType: nil, reason: .outsideTradingHours)
        }
        
        // If we are in TimeIntervalForHighRiskEntry and highRiskEntriesTaken < config.maxHighRiskEntryAllowed, we want to enter on sweetspot.
        if tradingSetting.highRiskEntryInteval(date: currentBar.time).contains(currentBar.time),
            sessionManager.highRiskEntriesTaken < tradingSetting.maxHighRiskEntryAllowed,
            !tradingSetting.byPassTradingTimeRestrictions {
            return seekToOpenPosition(bar: currentBar, latestBar: latestBar, entryType: .sweetSpot)
        }
        
        // time has pass outside the TradingTimeInterval, no more opening new positions, but still allow to close off existing position
        if !tradingSetting.tradingTimeInterval(date: currentBar.time).contains(currentBar.time) && !tradingSetting.byPassTradingTimeRestrictions {
            return .noAction(entryType: nil, reason: .outsideTradingHours)
        }
        
        // no entering trades during lunch hour
        if tradingSetting.noEntryDuringLunch,
            tradingSetting.lunchInterval(date: currentBar.time).contains(currentBar.time),
            !tradingSetting.byPassTradingTimeRestrictions {
            return .noAction(entryType: nil, reason: .lunchHour)
        }
        
        // If we lost multiple times in alternating directions, stop trading
        if checkChoppyDay(bar: currentBar) {
            return .noAction(entryType: nil, reason: .choppyDay)
        }
        
        if sessionManager.trades.isEmpty {
            return seekToOpenPosition(bar: currentBar, latestBar: latestBar, entryType: .all)
        }
        
        if let lastTrade = sessionManager.trades.last, let currentBarDirection = currentBar.oneMinSignal?.direction {
            // if the last trade was stopped out in the current minute bar AND last trade's direction is opposite of current bar direction, then enter aggressively on any entry
            if lastTrade.exitTime.isInSameMinute(date: currentBar.time),
                lastTrade.direction != currentBarDirection,
                lastTrade.exitMethod != .profitTaking {
                return seekToOpenPosition(bar: currentBar, latestBar: latestBar, entryType: .all)
            }
            
            // Check if the direction from the start of the last trade to current bar are same as current
            // If yes, we need to decide if we want to enter on any Pullback or only SweetSpot
            // Otherwise, then enter aggressively on any entry
            if lastTrade.direction == currentBarDirection,
                chart.checkAllSameDirection(direction: currentBarDirection,
                                           fromKey: lastTrade.exitTime.generateDateIdentifier(),
                                           toKey: currentBar.time.generateDateIdentifier()) {
                
                // If the previous trade profit is higher than enterOnPullback,
                // we allow to enter on any pullback if no opposite signal on any timeframe is found from last trade to now
                if lastTrade.idealProfit > tradingSetting.enterOnAnyPullback, lastTrade.exitMethod != .profitTaking {
                    return seekToOpenPosition(bar: currentBar, latestBar: latestBar, entryType: .pullBack)
                } else {
                    return seekToOpenPosition(bar: currentBar, latestBar: latestBar, entryType: .sweetSpot)
                }
            } else {
                return seekToOpenPosition(bar: currentBar, latestBar: latestBar, entryType: .all)
            }
        }
        
        return seekToOpenPosition(bar: currentBar, latestBar: latestBar, entryType: .sweetSpot)
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
        guard let previousLevel: Double = findPreviousLevel(direction: direction, entryBar: entryBar),
            let currentStop = entryBar.oneMinSignal?.stop else { return nil }
        
        let closeRounded = entryBar.candleStick.close.roundBasedOnDirection(direction: direction)
        
        switch direction {
        case .long:
            if entryBar.candleStick.close - previousLevel <= tradingSetting.maxRisk {
                return StopLoss(stop: min(previousLevel, closeRounded - tradingSetting.minStop), source: .supportResistanceLevel)
            } else if entryBar.candleStick.close - (currentStop - tradingSetting.buffer) <= tradingSetting.maxRisk {
                return StopLoss(stop: min(currentStop - tradingSetting.buffer, closeRounded - tradingSetting.minStop), source: .supportResistanceLevel)
            }
        default:
            if previousLevel - entryBar.candleStick.close <= tradingSetting.maxRisk {
                return StopLoss(stop: max(previousLevel, closeRounded + tradingSetting.minStop), source: .supportResistanceLevel)
            } else if (currentStop + tradingSetting.buffer) - entryBar.candleStick.close <= tradingSetting.maxRisk {
                return StopLoss(stop: max(currentStop + tradingSetting.buffer, closeRounded + tradingSetting.minStop), source: .supportResistanceLevel)
            }
        }
        
        // Method 3:
        let lowRounded = entryBar.candleStick.low.roundBasedOnDirection(direction: direction)
        let highRounded = entryBar.candleStick.high.roundBasedOnDirection(direction: direction)
        
        switch direction {
        case .long:
            return StopLoss(stop: min(lowRounded - tradingSetting.buffer, closeRounded - (tradingSetting.maxRisk / 2)), source: .currentBar)
        default:
            return StopLoss(stop: max(highRounded + tradingSetting.buffer, closeRounded + (tradingSetting.maxRisk / 2)), source: .currentBar)
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
                    if previousLevel - levelRounded > tradingSetting.buffer {
                        previousLevel = levelRounded
                        break outerLoop
                    }
                default:
                    if levelRounded - previousLevel > tradingSetting.buffer {
                        previousLevel = levelRounded
                        break outerLoop
                    }
                }
            }
        }
        
        if previousLevel == initialBarStopRounded {
            switch direction {
            case .long:
                previousLevel = previousLevel - tradingSetting.buffer
            default:
                previousLevel = previousLevel + tradingSetting.buffer
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
    
    // check if the low/high of the bar is too far from the 1 min S/R
    private func checkNotTooFarFromSupport(direction: TradeDirection, bar: PriceBar) -> Bool {
        guard tradingSetting.maxDistanceToSR > 0 else { return true }
        guard let stop = bar.oneMinSignal?.stop else { return false }
        
        var notTooFarFromSupport = false
        switch direction {
        case .long:
            notTooFarFromSupport = bar.candleStick.low - stop <= tradingSetting.maxDistanceToSR
        case .short:
            notTooFarFromSupport = stop - bar.candleStick.high <= tradingSetting.maxDistanceToSR
        }
        
        return notTooFarFromSupport
    }
    
    // check if the last X trades were losers(chop)
    private func checkChoppyDay(bar: PriceBar) -> Bool {
        guard tradingSetting.oppositeLosingTradesToHalt > 0 || tradingSetting.losingTradesToHalt > 0,
            let lastTrade = sessionManager.trades.last,
            lastTrade.entryTime.isInSameDay(date: bar.time),
            lastTrade.idealProfit < 0 else { return false }
        
        var numOfAlternatingLosingTrades = 0
        var numOfLosingTrades = 0
        var directionOfLastLosingTrade: TradeDirection = .long
        
        for trade in sessionManager.trades.reversed() {
            if !trade.entryTime.isInSameDay(date: bar.time) || trade.idealProfit > 0 {
                break
            }
            
            numOfLosingTrades += 1
            
            if numOfAlternatingLosingTrades == 0 || trade.direction != directionOfLastLosingTrade {
                numOfAlternatingLosingTrades += 1
                directionOfLastLosingTrade = trade.direction
            }
            
            if (tradingSetting.oppositeLosingTradesToHalt > 0 && numOfAlternatingLosingTrades >= tradingSetting.oppositeLosingTradesToHalt) ||
                (tradingSetting.losingTradesToHalt > 0 && numOfLosingTrades >= tradingSetting.losingTradesToHalt) {
                return true
            }
        }
        
        return false
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
                
                if signalDirection != direction {
                    switch signal.inteval {
                    case .twoMin:
                        finishedScanningFor2MinConfirmation = true
                    case .threeMin:
                        finishedScanningFor3MinConfirmation = true
                    default:
                        break
                    }
                } else {
                    switch signal.inteval {
                    case .twoMin:
                        if tradingSetting.waitForFinalizedSignals {
                            if !finishedScanningFor2MinConfirmation,
                                let twoMinIndex = chart.timeKeys.firstIndex(of: priceBar.identifier),
                                startIndex - twoMinIndex >= 1 {
                                earliest2MinConfirmationBar = priceBar
                                
                                finishedScanningFor2MinConfirmation = true
                            }
                        } else {
                            if !finishedScanningFor2MinConfirmation {
                                earliest2MinConfirmationBar = priceBar
                                
                                finishedScanningFor2MinConfirmation = true
                            }
                        }
                    case .threeMin:
                        if tradingSetting.waitForFinalizedSignals {
                            if !finishedScanningFor3MinConfirmation,
                                let threeMinIndex = chart.timeKeys.firstIndex(of: priceBar.identifier),
                                startIndex - threeMinIndex >= 2 {
                                earliest3MinConfirmationBar = priceBar
                                
                                finishedScanningFor3MinConfirmation = true
                            }
                        } else {
                            if !finishedScanningFor3MinConfirmation {
                                earliest3MinConfirmationBar = priceBar
                                
                                finishedScanningFor3MinConfirmation = true
                            }
                        }
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
}
