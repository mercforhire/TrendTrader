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
    case all // any bar of a triple confirmation
    case pullBack // any blue/red bar followed by one or more green bars
    case sweetSpot // pullback that bounced/almost bounced off the S/R level
    case reversal // opposite entry signal of a previous substantial trend
    
    func description() -> String {
        switch self {
        case .all:
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
    case updateStop(stop: StopLoss)
    case verifyPositionClosed(closedPosition: Position, closingPrice: Double, closingTime: Date, reason: ExitMethod)
    case forceClosePosition(closedPosition: Position, closingPrice: Double, closingTime: Date, reason: ExitMethod)
    case refresh
    
    func description(actionBarTime: Date, accountId: String) -> String {
        switch self {
        case .noAction(let entryType, let reason):
            if let entryType = entryType {
                return String(format: "\(accountId)-%@: No action for %@ (enter method: %@)",
                              Date().hourMinuteSecond(),
                              actionBarTime.hourMinute(),
                              entryType.description())
            } else {
                return String(format: "\(accountId)-%@: No action for %@ (%@)",
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
        default:
            return String(format: "%@: Refresh trades.", Date().hourMinuteSecond())
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

enum ExitMethod: Codable {
    case hitStoploss
    case twoGreenBars
    case signalReversed
    case signalInvalid
    case endOfDay
    case profitTaking
    case manual
    
    enum Key: CodingKey {
        case rawValue
    }
    
    enum CodingError: Error {
        case unknownValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let rawValue = try container.decode(Int.self, forKey: .rawValue)
        switch rawValue {
        case 0:
            self = .hitStoploss
        case 1:
            self = .twoGreenBars
        case 2:
            self = .signalReversed
        case 3:
            self = .signalInvalid
        case 4:
            self = .endOfDay
        case 5:
            self = .profitTaking
        case 6:
            self = .manual
        default:
            throw CodingError.unknownValue
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case .hitStoploss:
            try container.encode(0, forKey: .rawValue)
        case .twoGreenBars:
            try container.encode(1, forKey: .rawValue)
        case .signalReversed:
            try container.encode(2, forKey: .rawValue)
        case .signalInvalid:
            try container.encode(3, forKey: .rawValue)
        case .endOfDay:
            try container.encode(4, forKey: .rawValue)
        case .profitTaking:
            try container.encode(5, forKey: .rawValue)
        case .manual:
            try container.encode(6, forKey: .rawValue)
        }
    }
    
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
        case .profitTaking:
            return "Profit taking"
        case .manual:
            return "Manual action"
        }
    }
}

enum NoActionReason {
    case noTradingAction
    case repeatedTrade
    case lowQualityTrade
    case exceedLoss
    case outsideTradingHours
    case lunchHour
    case choppyDay
    case profitHit
    case other
    
    func description() -> String {
        switch self {
        case .noTradingAction:
            return "No trading action"
        case .repeatedTrade:
            return "Repeated trade"
        case .lowQualityTrade:
            return "Low quality trade"
        case .exceedLoss:
            return "Exceeded maximum loss"
        case .outsideTradingHours:
            return "Outside trading hours"
        case .lunchHour:
            return "Lunch hour"
        case .choppyDay:
            return "Choppy day"
        case .profitHit:
            return "Profit hit for the day"
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

enum TradeDirection: Codable {
    case long
    case short
    
    enum Key: CodingKey {
        case rawValue
    }
    
    enum CodingError: Error {
        case unknownValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let rawValue = try container.decode(Int.self, forKey: .rawValue)
        switch rawValue {
        case 0:
            self = .long
        case 1:
            self = .short
        default:
            throw CodingError.unknownValue
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case .long:
            try container.encode(0, forKey: .rawValue)
        case .short:
            try container.encode(1, forKey: .rawValue)
        }
    }
    
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
    case tradingStartError
    case lunchStartError
    case lunchEndError
    case clearTimeError
    case flatTimeError
    case fomcTimeError
    case positionSizeError
    case maxDailyLossError
    case numOfLosingTradesError
    case maxDistanceToSRError
    case profitAvoidSameDirectionError
    case bufferError
    case drawdownLimitError
    case profitToHaltError
    
    func displayMessage() -> String {
        switch self {
        case .serverURLError:
            return "Server URL Error, must be of format: http://192.168.0.121:80/"
        case .riskMultiplierError:
            return "Risk multplier must be between 1 - 10"
        case .maxRiskError:
            return "Max risk must be between 2 - 20"
        case .minStopError:
            return "Mn stop must be between 2 - 10"
        case .sweetSpotMinDistanceError:
            return "Sweetspot minimum distance between 0.5 - 10"
        case .greenBarsExitError:
            return "Green bars exit profit higher than 3"
        case .skipGreenBarsExitError:
            return "Skip green bars exit must be higher than green bars exit"
        case .enterOnPullbackError:
            return "Enter on pullback must be higher than 10"
        case .takeProfitBarLengthError:
            return "Take profit bar length must be higher than 10"
        case .tradingStartError:
            return "Trading time start error"
        case .lunchStartError:
            return "Lunch start time error"
        case .lunchEndError:
            return "Lunch end time error"
        case .clearTimeError:
            return "Clear time error"
        case .flatTimeError:
            return "Flat time error"
        case .fomcTimeError:
            return "FOMC time error"
        case .positionSizeError:
            return "Position size error"
        case .maxDailyLossError:
            return "Max daily loss must be -20 or lower"
        case .maxDistanceToSRError:
            return "Max distance to SR must be over 3"
        case .numOfLosingTradesError:
            return "Number of opposite losing trades to halt trading must be >= 3"
        case .profitAvoidSameDirectionError:
            return "Profit avoid same direction must be over 4"
        case .bufferError:
            return "Buffer must be over 0"
        case .drawdownLimitError:
            return "Drawdown Limit must be over 500"
        case .profitToHaltError:
            return "Profit to halt must be over 20"
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
