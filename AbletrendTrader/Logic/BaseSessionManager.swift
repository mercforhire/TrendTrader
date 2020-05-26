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
    
    var printLog: Bool = true
    var pointsValue: Double = 20.0
    var commission: Double = 2.5
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
            if let oldValue = oldValue,
                let status = status,
                oldValue.position != 0 && status.position == 0 {
                updateCurrentPositionToBeClosed()
            }
        }
    }
    private(set) var trades: [Trade] = []
    var currentPriceBarTime: Date?
    var liveMonitoring = false
    var accountId: String = "Sim"
    var state: AccountState = AccountState()
    
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
        state = AccountState()
    }
    
    func resetCurrentlyProcessingPriceBar() {
        currentPriceBarTime = nil
    }
    
    func processAction(priceBarTime: Date,
                       action: TradeActionType,
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
        
        for trade in trades where trade.executed == true {
            pAndL = pAndL + trade.actualProfit
        }
        
        return pAndL
    }
    
    func getDailyPAndL(day: Date) -> Double {
        var pAndL: Double = 0
        
        for trade in trades where trade.entryTime.isInSameDay(date: day) && trade.executed == true {
            pAndL = pAndL + trade.actualProfit
        }
        
        return pAndL
    }
    
    func getTotalPAndLDollar() -> Double {
        var pAndLDollar: Double = 0
        
        for trade in trades where trade.executed == true  {
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
            
            tradesList.append(TradesTableRowItem(type: currentPosition.direction.description() + (currentPosition.executed ? "" : "(Sim)"),
                                                 iEntry: String(format: "%.2f", currentPosition.idealEntryPrice),
                                                 aEntry: currentPosition.executed ? String(format: "%.2f", currentPosition.actualEntryPrice) : "--",
                                                 stop: currentStop,
                                                 iExit: "--",
                                                 aExit: "--",
                                                 pAndL: "--",
                                                 entryTime: dateFormatter.string(from: currentPosition.entryTime),
                                                 exitTime: "--",
                                                 commission: (currentPosition.executed ? commission * Double(currentPosition.size) : 0.0).currency()))
        }
        
        for trade in trades.reversed() {
            tradesList.append(TradesTableRowItem(type: trade.direction.description() + (trade.executed ? "" : "(Sim)"),
                                                 iEntry: String(format: "%.2f", trade.idealEntryPrice),
                                                 aEntry: trade.executed ? String(format: "%.2f", trade.actualEntryPrice) : "--",
                                                 stop: "--",
                                                 iExit: String(format: "%.2f", trade.idealExitPrice),
                                                 aExit: trade.executed ? String(format: "%.2f", trade.actualExitPrice) : "--",
                                                 pAndL: String(format: "%.2f", trade.actualProfit),
                                                 entryTime: dateFormatter.string(from: trade.entryTime),
                                                 exitTime: dateFormatter.string(from: trade.exitTime),
                                                 commission: trade.commission.currency()))
        }
        
        return tradesList
    }
    
    func appendTrade(trade: Trade) {
        trades.append(trade)
        
        if trade.executed {
            state.accBalance += trade.idealProfit * pointsValue - trade.commission
        }

        state.simMode = !trade.executed
        state.modelBalance += trade.idealProfit * pointsValue - trade.commission
        state.modelPeak = max(state.modelPeak, state.modelBalance)
        state.accPeak = max(state.accPeak, state.accBalance)
        
        if state.modelDrawdown <= 0 {
            state.latestTrough = 0.0
        } else {
            state.latestTrough = max(state.latestTrough, state.modelDrawdown)
        }
        
        if state.accDrawdown <= 0, state.modelBalance != state.accBalance {
            state.modelBalance = state.accBalance
            state.accPeak = state.accBalance
            state.modelPeak = state.accBalance
            state.latestTrough = 0.0
            printLog ? print("Account balance hit new peak, resetting model balance and peak.") : nil
        }
        
        if printLog {
            print(trade.executed ? "Live" : "Simulated",
                  "trade:", trade.exitTime.generateDateIdentifier(),
                  " P/L:", String(format: "%.2f", trade.idealProfit),
                  " Model DD:", String(format: "$%.2f", state.modelDrawdown),
                  " Model max DD:", String(format: "$%.2f", state.latestTrough),
                  " Model balance:", String(format: "$%.2f", state.modelBalance),
                  " Acc balance:", String(format: "$%.2f", state.accBalance))
            
            if !trade.executed, state.modelDrawdown < state.latestTrough * 0.7 {
                print("Drawdown: $\(String(format: "%.2f", state.modelDrawdown)) under $\(String(format: "%.2f", state.latestTrough * 0.7)), going back to live.")
            }
        }
    }
}
