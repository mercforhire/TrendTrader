//
//  Session.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-23.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

// Stores all the information of a trading session
// The Trader will use the saved info here to decide the next trade

struct TradeDisplayable {
    var type: String
    var entry: String
    var stop: String
    var exit: String
    var pAndL: String
    var entryTime: String
    var exitTime: String
}

struct Session {
    var trades: [Trade] = []
    var currentPosition: Position?
    var latestPriceBar: PriceBar?
    
    func getTotalPAndL() -> Double {
        var pAndL: Double = 0
        
        for trade in trades {
            pAndL = pAndL + (trade.profit ?? 0)
        }
        
        return pAndL
    }
    
    func listOfTrades() -> [TradeDisplayable] {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = Date.DefaultTimeZone
        
        var tradesList: [TradeDisplayable] = []
        
        if let currentPosition = currentPosition {
            tradesList.append(TradeDisplayable(type: currentPosition.direction.description(),
                                           entry: String(format: "%.2f", currentPosition.entryPrice),
                                           stop: String(format: "%.2f", currentPosition.stopLoss.stop),
                                           exit: "--",
                                           pAndL: "--",
                                           entryTime: dateFormatter.string(from: currentPosition.entry.candleStick.time),
                                           exitTime: "--"))
        }
        
        for trade in trades.reversed() {
            tradesList.append(TradeDisplayable(type: trade.direction.description(),
                                           entry: String(format: "%.2f", trade.entryPrice),
                                           stop: "--",
                                           exit: String(format: "%.2f", trade.exitPrice),
                                           pAndL: String(format: "%.2f", trade.profit ?? 0),
                                           entryTime: dateFormatter.string(from: trade.entry.candleStick.time),
                                           exitTime: dateFormatter.string(from: trade.exit.candleStick.time)))
        }
        
        return tradesList
    }
}
