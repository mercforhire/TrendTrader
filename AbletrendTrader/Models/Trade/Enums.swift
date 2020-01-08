//
//  Enums.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-30.
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
    case openedPosition(newPosition: Position)
    case updatedStop(stop: StopLoss)
    case verifyPositionClosed(closedPosition: Position, closingPrice: Double, closingTime: Date, reason: ExitMethod)
    case forceClosePosition(closedPosition: Position, closingPrice: Double, closingTime: Date, reason: ExitMethod)
    
    func description(actionBarTime: Date) -> String {
        switch self {
        case .noAction:
            return String(format: "%@: No action for bar: %@", Date().hourMinuteSecond(), actionBarTime.hourMinute())
        case .openedPosition(let newPosition):
            let type: String = newPosition.direction == .long ? "Long" : "Short"
            return String(format: "%@: Opened %@ position at price %.2f with SL %.2f for bar: %@", Date().hourMinuteSecond(), type, newPosition.idealEntryPrice, newPosition.stopLoss?.stop ?? -1.0, actionBarTime.hourMinute())
        case .verifyPositionClosed(let closedPosition, let closingPrice, _, let reason):
            let type: String = closedPosition.direction == .long ? "Long" : "Short"
            return String(format: "%@: Verify %@ position closed at %.2f reason: %@ for bar: %@", Date().hourMinuteSecond(), type, closingPrice, reason.reason(), actionBarTime.hourMinute())
        case .forceClosePosition(let closedPosition, let closingPrice, _, let reason):
            let type: String = closedPosition.direction == .long ? "Long" : "Short"
            return String(format: "%@: Flat %@ position at %.2f reason: %@ for bar: %@", Date().hourMinuteSecond(), type, closingPrice, reason.reason(), actionBarTime.hourMinute())
        case .updatedStop(let stopLoss):
            return String(format: "%@: Updated stop loss to %.2f reason: %@ for bar: %@", Date().hourMinuteSecond(), stopLoss.stop, stopLoss.source.reason(), actionBarTime.hourMinute())
        }
    }
}

enum StopLossSource {
    case supportResistanceLevel
    case twoGreenBars
    case currentBar
    
    func reason() -> String {
        switch self {
        case .supportResistanceLevel:
            return "Prev S/R"
        case .twoGreenBars:
            return "Green bars"
        case .currentBar:
            return "Cur S/R"
        }
    }
}

enum ExitMethod {
    case brokeSupportResistence
    case twoGreenBars
    case signalReversed
    case endOfDay
    case manual
    
    func reason() -> String {
        switch self {
        case .brokeSupportResistence:
            return "Broke Support or Resistence"
        case .twoGreenBars:
            return "Two Green Bars"
        case .signalReversed:
            return "Signal Reversed"
        case .endOfDay:
            return "End Of Day"
        case .manual:
            return "Manual action"
        }
    }
}

enum SignalColor {
    case green
    case blue
    case red
}

enum TradeDirection {
    case long
    case short
    
    func description() -> String {
        switch self {
        case .long:
            return "Long"
        case .short:
            return "Short"
        }
    }
    
    func ibTradeString() -> String {
        switch self {
        case .long:
            return "BUY"
        case .short:
            return "SELL"
        }
    }
    
    func reverse() -> TradeDirection {
        switch self {
        case .long:
            return .short
        case .short:
            return .long
        }
    }
}

enum SignalInteval {
    case oneMin
    case twoMin
    case threeMin
    
    func text() -> String {
        switch self {
        case .oneMin:
            return "1"
        case .twoMin:
            return "2"
        case .threeMin:
            return "3"
        }
    }
}

struct TradesTableRowItem {
    var type: String
    var entry: String
    var stop: String
    var exit: String
    var pAndL: String
    var entryTime: String
    var exitTime: String
}
