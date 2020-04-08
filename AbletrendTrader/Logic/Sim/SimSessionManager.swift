//
//  SimSessionManager.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-01-18.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation

class SimSessionManager: BaseSessionManager {
    override func processActions(priceBarTime: Date,
                                 action: TradeActionType,
                                 completion: @escaping (TradingError?) -> ()) {
        switch action {
        case .noAction:
            print(action.description(actionBarTime: priceBarTime))
        default:
            self.delegate?.newLogAdded(log: action.description(actionBarTime: priceBarTime))
        }
        
        switch action {
        case .openPosition(let newPosition, _):
            pos = newPosition
            pos?.actualEntryPrice = newPosition.idealEntryPrice
        case .reversePosition(let oldPosition, let newPosition, _):
            let trade = Trade(direction: oldPosition.direction,
                              size: newPosition.size,
                              pointValue: pointsValue,
                              entryTime: oldPosition.entryTime,
                              idealEntryPrice: oldPosition.idealEntryPrice,
                              actualEntryPrice: oldPosition.idealEntryPrice,
                              exitTime: newPosition.entryTime,
                              idealExitPrice: newPosition.idealEntryPrice,
                              actualExitPrice: newPosition.idealEntryPrice,
                              commission: commission * 2,
                              exitMethod: .signalReversed)
            trades.append(trade)
            
            pos = newPosition
            pos?.actualEntryPrice = newPosition.idealEntryPrice
        case .updateStop(let newStop):
            pos?.stopLoss = newStop
        case .forceClosePosition(let closedPosition, let closingPrice, let closingTime, let method):
            let trade = Trade(direction: closedPosition.direction,
                              size: closedPosition.size,
                              pointValue: pointsValue,
                              entryTime: closedPosition.entryTime,
                              idealEntryPrice: closedPosition.idealEntryPrice,
                              actualEntryPrice: closedPosition.idealEntryPrice,
                              exitTime: closingTime,
                              idealExitPrice: closingPrice,
                              actualExitPrice: closingPrice,
                              commission: commission * 2,
                              exitMethod: method)
            trades.append(trade)
            pos = nil
        case .verifyPositionClosed(let closedPosition, let closingPrice, let closingTime, _):
            let trade = Trade(direction: closedPosition.direction,
                              size: closedPosition.size,
                              pointValue: pointsValue,
                              entryTime: closedPosition.entryTime,
                              idealEntryPrice: closedPosition.idealEntryPrice,
                              actualEntryPrice: closedPosition.idealEntryPrice,
                              exitTime: closingTime,
                              idealExitPrice: closingPrice,
                              actualExitPrice: closingPrice,
                              commission: commission * 2,
                              exitMethod: .hitStoploss)
            trades.append(trade)
            pos = nil
        case .noAction(_):
            break
        }
        completion(nil)
    }
}
