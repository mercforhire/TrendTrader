//
//  SimSessionManager.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-01-18.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation

class SimSessionManager: BaseSessionManager {
    override func processAction(priceBarTime: Date,
                                action: TradeActionType,
                                completion: @escaping (TradingError?) -> ()) {
        switch action {
        case .noAction:
            break
        default:
            self.delegate?.newLogAdded(log: action.description(actionBarTime: priceBarTime, accountId: accountId))
        }
        
        switch action {
        case .openPosition(let newPosition, _):
            pos = newPosition
            pos?.actualEntryPrice = newPosition.idealEntryPrice
            
        case .updateStop(let newStop):
            pos?.stopLoss = newStop
            
        case .forceClosePosition(let closedPosition, let closingPrice, let closingTime, let method):
            let trade = Trade(direction: closedPosition.direction,
                              executed: closedPosition.executed,
                              size: closedPosition.size,
                              pointValue: pointsValue,
                              entryTime: closedPosition.entryTime,
                              idealEntryPrice: closedPosition.idealEntryPrice,
                              actualEntryPrice: closedPosition.idealEntryPrice,
                              exitTime: closingTime,
                              idealExitPrice: closingPrice,
                              actualExitPrice: closingPrice,
                              commission: closedPosition.executed ? commission * 2 : 0.0,
                              exitMethod: method)
            appendTrade(trade: trade)
            pos = nil
            
        case .verifyPositionClosed(let closedPosition, let closingPrice, let closingTime, _):
            let trade = Trade(direction: closedPosition.direction,
                              executed: closedPosition.executed,
                              size: closedPosition.size,
                              pointValue: pointsValue,
                              entryTime: closedPosition.entryTime,
                              idealEntryPrice: closedPosition.idealEntryPrice,
                              actualEntryPrice: closedPosition.idealEntryPrice,
                              exitTime: closingTime,
                              idealExitPrice: closingPrice,
                              actualExitPrice: closingPrice,
                              commission: closedPosition.executed ? commission * 2 : 0.0,
                              exitMethod: .hitStoploss)
            appendTrade(trade: trade)
            pos = nil
            
        case .noAction(_):
            break
        }
        
        completion(nil)
    }
}
