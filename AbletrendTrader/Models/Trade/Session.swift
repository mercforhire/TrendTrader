//
//  Session.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-23.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct Session {
    var trades: [Trade] = []
    var currentPosition: Position?
    
    func getTotalPAndL() -> Double {
        var pAndL: Double = 0
        
        for trade in trades {
            pAndL = pAndL + (trade.profit ?? 0)
        }
        
        return pAndL
    }
    
    func listOfTrades() -> [TradesTableRowItem] {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = Date.DefaultTimeZone
        
        var tradesList: [TradesTableRowItem] = []
        
        if let currentPosition = currentPosition {
            tradesList.append(TradesTableRowItem(type: currentPosition.direction.description(),
                                           entry: String(format: "%.2f", currentPosition.entryPrice),
                                           stop: String(format: "%.2f", currentPosition.stopLoss.stop),
                                           exit: "--",
                                           pAndL: "--",
                                           entryTime: dateFormatter.string(from: currentPosition.entryTime),
                                           exitTime: "--"))
        }
        
        for trade in trades.reversed() {
            tradesList.append(TradesTableRowItem(type: trade.direction.description(),
                                           entry: String(format: "%.2f", trade.entryPrice),
                                           stop: "--",
                                           exit: String(format: "%.2f", trade.exitPrice),
                                           pAndL: String(format: "%.2f", trade.profit ?? 0),
                                           entryTime: dateFormatter.string(from: trade.entryTime),
                                           exitTime: dateFormatter.string(from: trade.exitTime)))
        }
        
        return tradesList
    }
}
