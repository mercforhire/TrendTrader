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
                                 actions: [TradeActionType],
                                 completion: @escaping (TradingError?) -> ()) {
        for action in actions {
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
                                  entryTime: oldPosition.entryTime,
                                  idealEntryPrice: oldPosition.idealEntryPrice,
                                  actualEntryPrice: oldPosition.idealEntryPrice,
                                  exitTime: newPosition.entryTime,
                                  idealExitPrice: newPosition.idealEntryPrice,
                                  actualExitPrice: newPosition.idealEntryPrice,
                                  commission: oldPosition.commission * 2)
                trades.append(trade)
                
                pos = newPosition
                pos?.actualEntryPrice = newPosition.idealEntryPrice
            case .updateStop(let newStop):
                pos?.stopLoss = newStop
            case .forceClosePosition(let closedPosition, let closingPrice, let closingTime, _):
                let trade = Trade(direction: closedPosition.direction,
                                  entryTime: closedPosition.entryTime,
                                  idealEntryPrice: closedPosition.idealEntryPrice,
                                  actualEntryPrice: closedPosition.idealEntryPrice,
                                  exitTime: closingTime,
                                  idealExitPrice: closingPrice,
                                  actualExitPrice: closingPrice,
                                  commission: closedPosition.commission * 2)
                trades.append(trade)
                pos = nil
            case .verifyPositionClosed(let closedPosition, let closingPrice, let closingTime, _):
                let trade = Trade(direction: closedPosition.direction,
                                  entryTime: closedPosition.entryTime,
                                  idealEntryPrice: closedPosition.idealEntryPrice,
                                  actualEntryPrice: closedPosition.idealEntryPrice,
                                  exitTime: closingTime,
                                  idealExitPrice: closingPrice,
                                  actualExitPrice: closingPrice,
                                  commission: closedPosition.commission * 2)
                trades.append(trade)
                pos = nil
            case .noAction(_):
                break
            }
        }
        completion(nil)
    }
}
