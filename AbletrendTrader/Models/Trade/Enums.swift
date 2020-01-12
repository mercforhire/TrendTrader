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
    
    func description() -> String {
        switch self {
        case .initial:
            return "Initial"
        case .pullBack:
            return "PullBack"
        case .sweetSpot:
            return "SweetSpot"
        }
    }
}

enum TradeActionType {
    case noAction(entryType: EntryType?)
    case openPosition(newPosition: Position, entryType: EntryType)
    case reversePosition(oldPosition: Position, newPosition: Position, entryType: EntryType)
    case updateStop(stop: StopLoss)
    case verifyPositionClosed(closedPosition: Position, closingPrice: Double, closingTime: Date, reason: ExitMethod)
    case forceClosePosition(closedPosition: Position, closingPrice: Double, closingTime: Date, reason: ExitMethod)
    
    func description(actionBarTime: Date) -> String {
        switch self {
        case .noAction(let entryType):
            if let entryType = entryType {
                return String(format: "%@: No action for the minute %@ (enter method: %@)", Date().hourMinuteSecond(), actionBarTime.hourMinute(), entryType.description())
            } else {
                return String(format: "%@: No action for the minute %@", Date().hourMinuteSecond(), actionBarTime.hourMinute())
            }
            
        case .openPosition(let newPosition, let entryType):
            let type: String = newPosition.direction == .long ? "Long" : "Short"
            return String(format: "%@: Opened %@ position at price %.2f with SL %.2f reason: %@ for the minute %@", Date().hourMinuteSecond(), type, newPosition.idealEntryPrice, newPosition.stopLoss?.stop ?? -1.0, entryType.description(), actionBarTime.hourMinute())
            
        case .reversePosition(let oldPosition, let newPosition, let entryType):
            let type: String = oldPosition.direction == .long ? "Long" : "Short"
            return String(format: "%@: Reversed %@ position at price %.2f with SL %.2f for the minute %@", Date().hourMinuteSecond(), type, newPosition.idealEntryPrice, newPosition.stopLoss?.stop ?? -1.0, entryType.description(), actionBarTime.hourMinute())
            
        case .verifyPositionClosed(let closedPosition, let closingPrice, _, let reason):
            let type: String = closedPosition.direction == .long ? "Long" : "Short"
            return String(format: "%@: Verify %@ position closed at %.2f reason: %@ for the minute %@", Date().hourMinuteSecond(), type, closingPrice, reason.reason(), actionBarTime.hourMinute())
            
        case .forceClosePosition(let closedPosition, let closingPrice, _, let reason):
            let type: String = closedPosition.direction == .long ? "Long" : "Short"
            return String(format: "%@: Flat %@ position at %.2f reason: %@ for the minute %@", Date().hourMinuteSecond(), type, closingPrice, reason.reason(), actionBarTime.hourMinute())
            
        case .updateStop(let stopLoss):
            return String(format: "%@: Updated stop loss to %.2f reason: %@ for the minute %@", Date().hourMinuteSecond(), stopLoss.stop, stopLoss.source.reason(), actionBarTime.hourMinute())
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
            return "Broke s/r"
        case .twoGreenBars:
            return "Two green bars"
        case .signalReversed:
            return "Signal reversed"
        case .endOfDay:
            return "End of day"
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
    
    func description(short: Bool = false) -> String {
        switch self {
        case .long:
            return short ? "L" : "Long"
        case .short:
            return short ? "S" : "Short"
        }
    }
    
    func tradeString() -> String {
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

enum LiveTradingMode {
    case interactiveBroker
    case ninjaTrader
}

struct TradesTableRowItem {
    var type: String
    var iEntry: String
    var aEntry: String
    var stop: String
    var iExit: String
    var aExit: String
    var pAndL: String
    var entryTime: String
    var exitTime: String
}
