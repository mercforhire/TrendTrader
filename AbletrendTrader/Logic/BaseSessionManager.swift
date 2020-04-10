//
//  BaseSessionManager.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-01-18.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation

protocol SessionManagerDelegate: class {
    func positionStatusChanged()
    func newLogAdded(log: String)
}

class BaseSessionManager {
    let config = ConfigurationManager.shared
    
    var pointsValue: Double = 20.0
    var commission: Double = 2.0
    var highRiskEntriesTaken: Int = 0
    var liveUpdateFrequency: TimeInterval { 10 }
    var pos: Position?
    var status: PositionStatus? {
        didSet {
            if oldValue?.position != status?.position {
                delegate?.positionStatusChanged()
                if let status = status {
                    delegate?.newLogAdded(log: status.status())
                }
            }
            if oldValue?.position != 0 && status?.position == 0 {
                updateCurrentPositionToBeClosed()
            }
        }
    }
    var trades: [Trade] = []
    var currentPriceBarTime: Date?
    var liveMonitoring = false
    weak var delegate: SessionManagerDelegate?
    
    private var timer: Timer?
    
    func startLiveMonitoring() {
        if liveMonitoring {
            return
        }
        liveMonitoring = true
        startTimer()
    }
    
    func stopLiveMonitoring() {
        liveMonitoring = false
    }
    
    func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(liveUpdateFrequency),
                                     target: self,
                                     selector: #selector(refreshStatus),
                                     userInfo: nil,
                                     repeats: false)
    }
    
    @objc func refreshStatus() {
        // override
    }

    func resetTimer() {
        timer?.invalidate()
        startTimer()
    }
    
    func resetSession() {
        trades = []
        pos = nil
        status = nil
        timer?.invalidate()
        stopLiveMonitoring()
    }
    
    func resetCurrentlyProcessingPriceBar() {
        currentPriceBarTime = nil
    }
    
    func processActions(priceBarTime: Date,
                        actions: [TradeActionType],
                        completion: @escaping (TradingError?) -> ()) {
        // Override
    }
    
    func exitPositions(priceBarTime: Date,
                       idealExitPrice: Double,
                       exitReason: ExitMethod,
                       completion: @escaping (TradingError?) -> Void) {
        // Override
    }
    
    func updateCurrentPositionToBeClosed() {
        // Override
    }
    
    func placeDemoTrade(latestPriceBar: PriceBar) {
        // Override
    }
    
    func getTotalPAndL() -> Double {
        var pAndL: Double = 0
        
        for trade in trades {
            pAndL = pAndL + trade.actualProfit
        }
        
        return pAndL
    }
    
    func getTotalPAndLDollar() -> Double {
        var pAndLDollar: Double = 0
        
        for trade in trades {
            pAndLDollar = pAndLDollar + trade.actualProfitDollar
        }
        
        return pAndLDollar
    }
    
    func listOfTrades() -> [TradesTableRowItem] {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = Date.DefaultTimeZone
        
        var tradesList: [TradesTableRowItem] = []
        
        if let currentPosition = pos {
            let currentStop: String = currentPosition.stopLoss?.stop != nil ? String(format: "%.2f", currentPosition.stopLoss!.stop) : "--"
            
            tradesList.append(TradesTableRowItem(type: currentPosition.direction.description(),
                                                 iEntry: String(format: "%.2f", currentPosition.idealEntryPrice),
                                                 aEntry: String(format: "%.2f", currentPosition.actualEntryPrice),
                                                 stop: currentStop,
                                                 iExit: "--",
                                                 aExit: "--",
                                                 pAndL: "--",
                                                 entryTime: dateFormatter.string(from: currentPosition.entryTime),
                                                 exitTime: "--",
                                                 commission: (commission * Double(currentPosition.size)).currency(true, showPlusSign: false)))
        }
        
        for trade in trades.reversed() {
            tradesList.append(TradesTableRowItem(type: trade.direction.description(),
                                                 iEntry: String(format: "%.2f", trade.idealEntryPrice),
                                                 aEntry: String(format: "%.2f", trade.actualEntryPrice),
                                                 stop: "--",
                                                 iExit: String(format: "%.2f", trade.idealExitPrice),
                                                 aExit: String(format: "%.2f", trade.actualExitPrice),
                                                 pAndL: String(format: "%.2f", trade.actualProfit),
                                                 entryTime: dateFormatter.string(from: trade.entryTime),
                                                 exitTime: dateFormatter.string(from: trade.exitTime),
                                                 commission: trade.commission.currency(true)))
        }
        
        return tradesList
    }
}
