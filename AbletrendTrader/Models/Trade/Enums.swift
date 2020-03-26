//
//  Enums.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-30.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation
import Cocoa

typealias Action = () -> Void

enum EntryType {
    // for all entries, the price must be above 1 min support or under 1 min resistance
    case any // any bar of a triple confirmation
    case pullBack // any blue/red bar followed by one or more green bars
    case sweetSpot // pullback that bounced/almost bounced off the S/R level
    case reversal // opposite entry signal of a previous substantial trend
    
    func description() -> String {
        switch self {
        case .any:
            return "Any"
        case .pullBack:
            return "PullBack"
        case .sweetSpot:
            return "SweetSpot"
        case .reversal:
            return "Reversal"
        }
    }
}

enum TradeActionType {
    case noAction(entryType: EntryType?, reason: NoActionReason)
    case openPosition(newPosition: Position, entryType: EntryType)
    case reversePosition(oldPosition: Position, newPosition: Position, entryType: EntryType)
    case updateStop(stop: StopLoss)
    case verifyPositionClosed(closedPosition: Position, closingPrice: Double, closingTime: Date, reason: ExitMethod)
    case forceClosePosition(closedPosition: Position, closingPrice: Double, closingTime: Date, reason: ExitMethod)
    
    func description(actionBarTime: Date) -> String {
        switch self {
        case .noAction(let entryType, let reason):
            if let entryType = entryType {
                return String(format: "%@: No action for %@ (enter method: %@)",
                              Date().hourMinuteSecond(),
                              actionBarTime.hourMinute(),
                              entryType.description())
            } else {
                return String(format: "%@: No action for %@(%@)",
                              Date().hourMinuteSecond(),
                              actionBarTime.hourMinute(),
                              reason.description())
            }
            
        case .openPosition(let newPosition, let entryType):
            let type: String = newPosition.direction == .long ? "Long" : "Short"
            return String(format: "%@: Opened %@ position at %.2f with SL %.2f reason: %@ for %@",
                          Date().hourMinuteSecond(),
                          type, newPosition.idealEntryPrice,
                          newPosition.stopLoss?.stop ?? -1.0,
                          entryType.description(),
                          actionBarTime.hourMinute())
            
        case .reversePosition(let oldPosition, let newPosition, let entryType):
            let type: String = oldPosition.direction == .long ? "Long" : "Short"
            return String(format: "%@: Reversed %@ position at %.2f with SL %.2f for %@",
                          Date().hourMinuteSecond(),
                          type, newPosition.idealEntryPrice,
                          newPosition.stopLoss?.stop ?? -1.0,
                          entryType.description(),
                          actionBarTime.hourMinute())
            
        case .verifyPositionClosed(let closedPosition, let closingPrice, _, let reason):
            let type: String = closedPosition.direction == .long ? "Long" : "Short"
            return String(format: "%@: Verify %@ position closed at %.2f reason: %@ for %@",
                          Date().hourMinuteSecond(),
                          type, closingPrice,
                          reason.reason(),
                          actionBarTime.hourMinute())
            
        case .forceClosePosition(let closedPosition, let closingPrice, _, let reason):
            let type: String = closedPosition.direction == .long ? "Long" : "Short"
            return String(format: "%@: Flat %@ position at %.2f reason: %@ for %@",
                          Date().hourMinuteSecond(),
                          type, closingPrice,
                          reason.reason(),
                          actionBarTime.hourMinute())
            
        case .updateStop(let stopLoss):
            return String(format: "%@: Updated stop loss to %.2f reason: %@ for %@",
                          Date().hourMinuteSecond(),
                          stopLoss.stop,
                          stopLoss.source.reason(),
                          actionBarTime.hourMinute())
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
    case hitStoploss
    case twoGreenBars
    case signalReversed
    case signalInvalid
    case endOfDay
    case manual
    
    func reason() -> String {
        switch self {
        case .hitStoploss:
            return "Hit stop loss"
        case .twoGreenBars:
            return "Two green bars"
        case .signalReversed:
            return "Signal reversed"
        case .signalInvalid:
            return "Signal invalid"
        case .endOfDay:
            return "End of day"
        case .manual:
            return "Manual action"
        }
    }
}

enum NoActionReason {
    case noTradingAction
    case exceedLoss
    case outsideTradingHours
    case lunchHour
    case other
    
    func description() -> String {
        switch self {
        case .noTradingAction:
        return "No trading action"
        case .exceedLoss:
        return "Exceeded maximum loss"
        case .outsideTradingHours:
        return "Outside trading hours"
        case .lunchHour:
        return "Lunch hour"
        case .other:
            return "Other reason"
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

enum SignalInteval: Int {
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

enum OrderType {
    case market
    case bracket(stop: Double)
    case stop(price: Double)
    case limit(price: Double)
    
    func typeString() -> String {
        switch self {
        case .market, .bracket:
            return "MKT"
        case .limit:
            return "LMT"
        case .stop:
            return "STP"
        }
    }
    
    func ninjaType() -> String {
        switch self {
        case .market, .bracket:
            return "MARKET"
        case .limit:
            return "LIMIT"
        case .stop:
            return "STOPMARKET"
        }
    }
}

enum LiveTradingMode {
    case ninjaTrader(accountId: String, commission: Double, ticker: String, exchange: String, accountLongName: String, basePath: String, incomingPath: String, outgoingPath: String)
    
    func name() -> String {
        switch self {
        case .ninjaTrader:
            return "NinjaTrader"
        }
    }
}

enum NTOrderStatus: String {
    case working = "WORKING"
    case cancelled = "CANCELLED"
    case filled = "FILLED"
    case rejected = "REJECTED"
    case accepted = "ACCEPTED"
    case changeSubmitted = "CHANGESUBMITTED"
}

enum TradingError: Error {
    case brokerNotConnected
    case fetchAccountsFailed
    case fetchTradesFailed
    case fetchPositionsFailed
    case fetchOrdersFailed
    case orderReplyFailed
    case orderAlreadyPlaced
    case orderFailed
    case noOrderResponse
    case modifyOrderFailed
    case deleteOrderFailed
    case verifyClosedPositionFailed
    case positionNotClosed
    
    func displayMessage() -> String {
        switch self {
        case .brokerNotConnected:
            return "Broker not connected"
        case .fetchAccountsFailed:
            return "Fetch accounts failed."
        case .fetchTradesFailed:
            return "Fetch trades failed."
        case .fetchPositionsFailed:
            return "Fetch positions failed."
        case .fetchOrdersFailed:
             return "Fetch live orders failed."
        case .orderReplyFailed:
            return "Answer question failed."
        case .orderAlreadyPlaced:
            return "Order already placed."
        case .orderFailed:
            return "Place order failed."
        case .modifyOrderFailed:
            return "Modify order failed."
        case .deleteOrderFailed:
            return "Delete order failed."
        case .verifyClosedPositionFailed:
            return "Verify closed position failed."
        case .positionNotClosed:
            return "Position not closed."
        case .noOrderResponse:
            return "No order response."
        }
    }
    
    func printError() {
        print("Network error:", Date().hourMinuteSecond(), self.displayMessage())
    }
}

enum ConfigError: Error {
    case serverURLError
    case riskMultiplierError
    case maxRiskError
    case minStopError
    case sweetSpotMinDistanceError
    case greenBarsExitError
    case skipGreenBarsExitError
    case enterOnPullbackError
    case takeProfitBarLengthError
    case highRiskStartError
    case highRiskEndError
    case tradingStartError
    case tradingEndError
    case lunchStartError
    case lunchEndError
    case clearTimeError
    case flatTimeError
    case positionSizeError
    case maxDailyLossError
    case tickerValueError
    case maxHighRiskEntryAllowedError
    case ntCommissionError
    case ntTickerError
    case ntExchangeError
    case ntAccountLongNameError
    case ntAccountNameError
    case ntBasePathError
    case ntIncomingPathError
    case ntOutgoingPathError
    
    func displayMessage() -> String {
        switch self {
        case .serverURLError:
            return "Server URL Error, must be of format: http://192.168.0.121/"
        case .riskMultiplierError:
            return "Risk multplier must be between 1 - 10"
        case .maxRiskError:
            return "Max risk must be between 2 - 20"
        case .minStopError:
            return "Mn stop must be between 2 - 10"
        case .sweetSpotMinDistanceError:
            return "Sweetspot minimum distance between 1 - 5"
        case .greenBarsExitError:
            return "Green bars exit profit higher than 5"
        case .skipGreenBarsExitError:
            return "Skip green bars exit must be higher than green bars exit"
        case .enterOnPullbackError:
            return "Enter on pullback must be higher than 10"
        case .takeProfitBarLengthError:
            return "Take profit bar length must be higher than 10"
        case .highRiskStartError:
            return "High risk start time error"
        case .highRiskEndError:
            return "High risk end time error"
        case .tradingStartError:
            return "Trading time start error"
        case .tradingEndError:
            return "Trading time end error"
        case .lunchStartError:
            return "Lunch start time error"
        case .lunchEndError:
            return "Lunch end time error"
        case .clearTimeError:
            return "Clear time error"
        case .flatTimeError:
            return "Flat time error"
        case .positionSizeError:
            return "Position size error"
        case .maxDailyLossError:
            return "Max daily loss must be -20 or lower"
        case .tickerValueError:
            return "Ticker value must be 1 or more"
        case .maxHighRiskEntryAllowedError:
            return "Max high risk entry allowed must be positive number"
        case .ntCommissionError:
            return "Commission must be a positive number"
        case .ntTickerError:
            return "Ticket name error"
        case .ntExchangeError:
            return "Exchange name error"
        case .ntAccountLongNameError:
            return "NT long account name error"
        case .ntAccountNameError:
            return "NT account name error"
        case .ntBasePathError:
            return "Base path error"
        case .ntIncomingPathError:
            return "Incoming path error"
        case .ntOutgoingPathError:
            return "Outgoing path error"
        }
    }
    
    func displayErrorDialog() {
        let alert = NSAlert()
        alert.messageText = self.displayMessage()
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Dismiss")
        alert.runModal()
    }
}
