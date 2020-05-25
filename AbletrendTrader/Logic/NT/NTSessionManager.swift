//
//  NTSessionManager.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-01-18.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation
import Cocoa

class NTSessionManager: BaseSessionManager {
    private var ntManager: NTManager
    private var connected = false
    
    override var liveUpdateFrequency: TimeInterval { 1 }
    
    init(accountId: String,
         commission: Double,
         ticker: String,
         pointsValue: Double,
         exchange: String,
         accountLongName: String,
         basePath: String,
         incomingPath: String,
         outgoingPath: String,
         state: AccountState) {
        self.ntManager = NTManager(accountId: accountId,
                                   commission: commission,
                                   ticker: ticker,
                                   exchange: exchange,
                                   accountLongName: accountLongName,
                                   basePath: basePath,
                                   incomingPath: incomingPath,
                                   outgoingPath: outgoingPath)
        super.init()
        self.accountId = accountId
        self.commission = commission
        self.pointsValue = pointsValue
        self.state = state
        self.ntManager.initialize()
        self.ntManager.delegate = self
    }
    
    override func refreshStatus() {
        status = ntManager.readPositionStatusFile()
        if self.liveMonitoring {
            self.resetTimer()
        }
    }
    
    override func processAction(priceBarTime: Date,
                                action: TradeActionType,
                                completion: @escaping (TradingError?) -> ()) {
        switch action {
        case .verifyPositionClosed(let closedPosition, let closingPrice, let closingTime, let reason):
            self.delegate?.newLogAdded(log: action.description(actionBarTime: priceBarTime, accountId: accountId))
            
            let trade = Trade(direction: closedPosition.direction,
                              executed: false,
                              size: closedPosition.size,
                              pointValue: pointsValue,
                              entryTime: closedPosition.entryTime,
                              idealEntryPrice: closedPosition.idealEntryPrice,
                              actualEntryPrice: closedPosition.idealEntryPrice,
                              exitTime: closingTime,
                              idealExitPrice: closingPrice,
                              actualExitPrice: closingPrice,
                              commission: 0.0,
                              exitMethod: reason)
            appendTrade(trade: trade)
            pos = nil
            
            completion(nil)
            return
        case .refresh:
            completion(nil)
            return
        default:
            break
        }
        
        if !connected {
            completion(.brokerNotConnected)
            return
        }
        
        if currentPriceBarTime?.isInSameMinute(date: priceBarTime) ?? false {
            // Actions for this bar already processed
            print("\(accountId)-\(Date().hourMinuteSecond()): Actions for \(priceBarTime.hourMinuteSecond()) already processed")
            return
        }
        currentPriceBarTime = priceBarTime
        
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            let semaphore = DispatchSemaphore(value: 0)
            
            switch action {
            case .noAction:
                print(action.description(actionBarTime: priceBarTime, accountId: self.accountId))
            default:
                self.delegate?.newLogAdded(log: action.description(actionBarTime: priceBarTime, accountId: self.accountId))
            }
            
            switch action {
            case .openPosition(let newPosition, _):
                var skip = false
                if let currentPosition = self.pos, currentPosition.direction != newPosition.direction {
                    self.delegate?.newLogAdded(log: "Conflicting existing position, closing existing position...")
                    self.exitPositions(priceBarTime: priceBarTime,
                                       idealExitPrice: newPosition.idealEntryPrice,
                                       exitReason: .signalReversed)
                    { error in
                        if let ntError = error {
                            skip = true
                            DispatchQueue.main.async {
                                completion(ntError)
                            }
                        } else {
                            self.pos = nil
                        }
                        semaphore.signal()
                    }
                    semaphore.wait()
                } else if let status = self.status?.position, status != 0 {
                    self.delegate?.newLogAdded(log: "Already has existing position, skipping opening new position")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
                
                guard !skip else { return }
                
                if newPosition.executed {
                    self.enterAtMarket(priceBarTime: priceBarTime,
                                       stop: newPosition.stopLoss?.stop,
                                       direction: newPosition.direction,
                                       size: newPosition.size)
                    { result in
                        switch result {
                        case .success(let confirmation):
                            self.pos = newPosition
                            self.pos?.entryOrderRef = confirmation.orderRef
                            self.pos?.entryTime = confirmation.time
                            self.pos?.actualEntryPrice = confirmation.price
                            self.pos?.stopLoss?.stopOrderId = confirmation.stopOrderId
                            DispatchQueue.main.async {
                                completion(nil)
                            }
                        case .failure(let ntError):
                            self.ntManager.flatEverything()
                            DispatchQueue.main.async {
                                completion(ntError)
                            }
                        }
                        semaphore.signal()
                    }
                    semaphore.wait()
                } else {
                    self.pos = newPosition
                    self.pos?.actualEntryPrice = newPosition.idealEntryPrice
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            
            case .updateStop(let newStop):
                guard let currentPosition = self.pos else {
                    DispatchQueue.main.async {
                        completion(.modifyOrderFailed)
                    }
                    return
                }
                
                if currentPosition.executed {
                    if self.status?.position == 0 {
                        if let closedPosition = self.pos,
                            let stopOrderId = closedPosition.stopLoss?.stopOrderId,
                            let latestFilledOrderResponse = self.ntManager.getOrderResponse(orderId: stopOrderId),
                            latestFilledOrderResponse.status == .filled {
                            
                            self.delegate?.newLogAdded(log: "Trying to update stop but position already closed, last filled order response: \(latestFilledOrderResponse.description)")
                            let trade = Trade(direction: closedPosition.direction,
                                              executed: true,
                                              size: closedPosition.size,
                                              pointValue: self.pointsValue,
                                              entryTime: closedPosition.entryTime,
                                              idealEntryPrice: closedPosition.idealEntryPrice,
                                              actualEntryPrice: closedPosition.actualEntryPrice,
                                              exitTime: latestFilledOrderResponse.time,
                                              idealExitPrice: closedPosition.stopLoss?.stop ?? latestFilledOrderResponse.price,
                                              actualExitPrice: latestFilledOrderResponse.price,
                                              commission: self.commission * 2,
                                              exitMethod: .hitStoploss)
                            self.appendTrade(trade: trade)
                        } else {
                            self.delegate?.newLogAdded(log: "Trying to update stop but position already closed, but no last order response")
                        }
                        
                        self.pos = nil
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                    } else if let stopOrderId = currentPosition.stopLoss?.stopOrderId {
                        _ = self.ntManager.deleteOrderResponse(orderId: stopOrderId)
                        self.ntManager.changeOrder(orderRef: stopOrderId,
                                                   size: currentPosition.size,
                                                   price: newStop.stop,
                                                   completion:
                        { result in
                            switch result {
                            case .success:
                                self.pos?.stopLoss?.stop = newStop.stop
                                DispatchQueue.main.async {
                                    completion(nil)
                                }
                                semaphore.signal()
                            case .failure(let error):
                                switch error {
                                case .orderFailed:
                                    self.exitPositions(priceBarTime: priceBarTime,
                                                       idealExitPrice: newStop.stop,
                                                       exitReason: .hitStoploss)
                                    { error in
                                        if let ntError = error {
                                            DispatchQueue.main.async {
                                                completion(ntError)
                                            }
                                        } else {
                                            self.pos = nil
                                            DispatchQueue.main.async {
                                                completion(nil)
                                            }
                                        }
                                        semaphore.signal()
                                    }
                                default:
                                    DispatchQueue.main.async {
                                        completion(error)
                                    }
                                    semaphore.signal()
                                }
                            }
                        })
                        semaphore.wait()
                    } else {
                        let stopOrderId = priceBarTime.generateOrderIdentifier(prefix: currentPosition.direction.reverse().description(short: true))
                        self.ntManager.generatePlaceOrder(direction: currentPosition.direction.reverse(),
                                                          size: currentPosition.size,
                                                          orderType: .stop(price: newStop.stop),
                                                          orderRef: stopOrderId,
                                                          completion:
                        { result in
                            switch result {
                            case .success:
                                self.pos?.stopLoss = newStop
                                self.pos?.stopLoss?.stopOrderId = stopOrderId
                                DispatchQueue.main.async {
                                    completion(nil)
                                }
                            case .failure(let ntError):
                                DispatchQueue.main.async {
                                    completion(ntError)
                                }
                            }
                            semaphore.signal()
                        })
                        semaphore.wait()
                    }
                } else {
                    self.pos?.stopLoss = newStop
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            case .forceClosePosition(let closedPosition, let closingPrice, _, let exitMethod):
                if closedPosition.executed {
                    if self.status?.position == 0 {
                        if let stopOrderId = self.pos?.stopLoss?.stopOrderId,
                            let latestFilledOrderResponse = self.ntManager.getOrderResponse(orderId: stopOrderId),
                            latestFilledOrderResponse.status == .filled {
                            
                            self.delegate?.newLogAdded(log: "Force close position already closed, last filled order response: \(latestFilledOrderResponse.description)")
                            let trade = Trade(direction: closedPosition.direction,
                                              executed: true,
                                              size: closedPosition.size,
                                              pointValue: self.pointsValue,
                                              entryTime: closedPosition.entryTime,
                                              idealEntryPrice: closedPosition.idealEntryPrice,
                                              actualEntryPrice: closedPosition.actualEntryPrice,
                                              exitTime: latestFilledOrderResponse.time,
                                              idealExitPrice: closingPrice,
                                              actualExitPrice: latestFilledOrderResponse.price,
                                              commission: self.commission * Double(closedPosition.size) * 2,
                                              exitMethod: exitMethod)
                            self.appendTrade(trade: trade)
                        } else {
                            self.delegate?.newLogAdded(log: "Force close position already closed, but no last order response")
                            let trade = Trade(direction: closedPosition.direction,
                                              executed: true,
                                              size: closedPosition.size,
                                              pointValue: self.pointsValue,
                                              entryTime: closedPosition.entryTime,
                                              idealEntryPrice: closedPosition.idealEntryPrice,
                                              actualEntryPrice: closedPosition.actualEntryPrice,
                                              exitTime: Date(),
                                              idealExitPrice: closingPrice,
                                              actualExitPrice: closingPrice,
                                              commission: self.commission * Double(closedPosition.size) * 2,
                                              exitMethod: exitMethod)
                            self.appendTrade(trade: trade)
                        }
                        
                        self.pos = nil
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                    } else {
                        self.ntManager.cancelAllOrders()
                        self.enterAtMarket(priceBarTime: priceBarTime,
                                           direction: closedPosition.direction.reverse(),
                                           size: closedPosition.size)
                        { result in
                            switch result {
                            case .success(let confirmation):
                                let trade = Trade(direction: closedPosition.direction,
                                                  executed: true,
                                                  size: closedPosition.size,
                                                  pointValue: self.pointsValue,
                                                  entryTime: closedPosition.entryTime,
                                                  idealEntryPrice: closedPosition.idealEntryPrice,
                                                  actualEntryPrice: closedPosition.actualEntryPrice,
                                                  exitTime: confirmation.time,
                                                  idealExitPrice: closingPrice,
                                                  actualExitPrice: confirmation.price,
                                                  commission: confirmation.commission * 2,
                                                  exitMethod: exitMethod)
                                self.appendTrade(trade: trade)
                                self.pos = nil
                                DispatchQueue.main.async {
                                    completion(nil)
                                }
                            case .failure(let error):
                                DispatchQueue.main.async {
                                    completion(error)
                                }
                            }
                            semaphore.signal()
                        }
                        semaphore.wait()
                    }
                } else {
                    let trade = Trade(direction: closedPosition.direction,
                                      executed: false,
                                      size: closedPosition.size,
                                      pointValue: self.pointsValue,
                                      entryTime: closedPosition.entryTime,
                                      idealEntryPrice: closedPosition.idealEntryPrice,
                                      actualEntryPrice: closedPosition.idealEntryPrice,
                                      exitTime: Date(),
                                      idealExitPrice: closingPrice,
                                      actualExitPrice: closingPrice,
                                      commission: 0.0,
                                      exitMethod: exitMethod)
                    self.appendTrade(trade: trade)
                    self.pos = nil
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            default:
                break
            }
        }
    }
    
    func enterAtMarket(reverseOrder: Bool = false,
                       priceBarTime: Date,
                       stop: Double? = nil,
                       direction: TradeDirection,
                       size: Int,
                       completion: @escaping (Swift.Result<OrderConfirmation, TradingError>) -> Void) {
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var errorSoFar: TradingError?
            var orderConfirmation: OrderConfirmation?
            var stopConfirmation: OrderConfirmation?
            
            // Stop order:
            if let stop = stop {
                let stopOrderId = priceBarTime.generateOrderIdentifier(prefix: direction.reverse().description(short: true))
                self.ntManager.generatePlaceOrder(direction: direction.reverse(),
                                                  size: size,
                                                  orderType: .stop(price: stop),
                                                  orderRef: stopOrderId,
                                                  completion:
                { result in
                    switch result {
                    case .success(let confirmation):
                        stopConfirmation = confirmation
                    case .failure(let ntError):
                        errorSoFar = ntError
                    }
                    semaphore.signal()
                })
                semaphore.wait()
            }
            
            if let errorSoFar = errorSoFar {
                DispatchQueue.main.async {
                    completion(.failure(errorSoFar))
                }
                return
            }
            
            // Buy/sell order:
            if reverseOrder {
                let orderRef = priceBarTime.generateOrderIdentifier(prefix: direction.description(short: true))
                self.ntManager.reversePositionAndPlaceOrder(direction: direction,
                                                            size: size,
                                                            orderType: .market,
                                                            orderRef: orderRef,
                                                            completion:
                { result in
                    switch result {
                    case .success(let confirmation):
                        orderConfirmation = confirmation
                    case .failure(let ntError):
                        errorSoFar = ntError
                    }
                    semaphore.signal()
                })
                semaphore.wait()
            } else {
                let orderRef = priceBarTime.generateOrderIdentifier(prefix: direction.description(short: true))
                self.ntManager.generatePlaceOrder(direction: direction,
                                                  size: size,
                                                  orderType: .market,
                                                  orderRef: orderRef,
                                                  completion:
                { result in
                    switch result {
                    case .success(let confirmation):
                        orderConfirmation = confirmation
                    case .failure(let ntError):
                        if ntError != .orderAlreadyPlaced {
                            errorSoFar = ntError
                        }
                    }
                    semaphore.signal()
                })
                semaphore.wait()
            }
            
            DispatchQueue.main.async {
                print("Order confirmation: \(orderConfirmation?.description ?? "nil")")
                if stop != nil {
                    print("Stop confirmation: \(stopConfirmation?.description ?? "nil")")
                }
                if var confirmation = orderConfirmation {
                    confirmation.stopOrderId = stopConfirmation?.orderId
                    completion(.success(confirmation))
                } else {
                    completion(.failure(errorSoFar ?? .orderFailed))
                }
            }
        }
    }
    
    override func exitPositions(priceBarTime: Date,
                                idealExitPrice: Double,
                                exitReason: ExitMethod,
                                completion: @escaping (TradingError?) -> Void) {
        ntManager.cancelAllOrders()
        if let status = status, status.position != 0 {
            enterAtMarket(priceBarTime: priceBarTime,
                          direction: status.position > 0 ? .short : .long,
                          size: abs(status.position))
            { [weak self] result in
                guard let self = self else {
                    return
                }
                switch result {
                case .success(let orderConfirmation):
                    if let currentPosition = self.pos {
                        let trade = Trade(direction: currentPosition.direction,
                                          executed: true,
                                          size: currentPosition.size,
                                          pointValue: self.pointsValue,
                                          entryTime: currentPosition.entryTime,
                                          idealEntryPrice: currentPosition.idealEntryPrice,
                                          actualEntryPrice: currentPosition.idealEntryPrice,
                                          exitTime: orderConfirmation.time,
                                          idealExitPrice: idealExitPrice,
                                          actualExitPrice: orderConfirmation.price,
                                          commission: orderConfirmation.commission * 2,
                                          exitMethod: .manual)
                        self.appendTrade(trade: trade)
                        self.pos = nil
                    }
                    completion(nil)
                case .failure:
                    completion(.positionNotClosed)
                }
            }
        } else {
            completion(nil)
        }
    }
    
    private var quitLoop = false
    override func updateCurrentPositionToBeClosed() {
        quitLoop = false
        
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else { return }
            
            for _ in 0...2 {
                if self.quitLoop {
                    break
                }
                
                if !self.quitLoop,
                    let closedPosition = self.pos,
                    let stopOrderId = closedPosition.stopLoss?.stopOrderId,
                    let latestFilledOrderResponse = self.ntManager.getOrderResponse(orderId: stopOrderId),
                    latestFilledOrderResponse.status == .filled {
                    
                    let trade = Trade(direction: closedPosition.direction,
                                      executed: true,
                                      size: closedPosition.size,
                                      pointValue: self.pointsValue,
                                      entryTime: closedPosition.entryTime,
                                      idealEntryPrice: closedPosition.idealEntryPrice,
                                      actualEntryPrice: closedPosition.actualEntryPrice,
                                      exitTime: latestFilledOrderResponse.time,
                                      idealExitPrice: closedPosition.stopLoss?.stop ?? latestFilledOrderResponse.price,
                                      actualExitPrice: latestFilledOrderResponse.price,
                                      commission: self.commission * Double(closedPosition.size) * 2,
                                      exitMethod: .hitStoploss)
                    self.appendTrade(trade: trade)
                    self.pos = nil
                    
                    DispatchQueue.main.async {
                        self.delegate?.newLogAdded(log: "Detected position closed, last filled order response: \(latestFilledOrderResponse.description)")
                        self.delegate?.positionStatusChanged()
                    }
                    self.quitLoop = true
                }
                else if !self.quitLoop {
                    print("Detected position closed but last filled order response not found. Retrying...")
                    sleep(1)
                }
            }
        }
    }
    
    override func startLiveMonitoring() {
        super.startLiveMonitoring()
        
        if let existingPosition = status?.position,
            existingPosition != 0,
            pos == nil,
            let existingPrice = status?.price {
            self.delegate?.newLogAdded(log: "Exiting position detected: \(existingPosition)")
            pos = Position(executed: true,
                           direction: existingPosition > 0 ? .long : .short,
                           size: abs(existingPosition),
                           entryTime: Date(),
                           idealEntryPrice: existingPrice,
                           actualEntryPrice: existingPrice,
                           stopLoss: nil,
                           entryOrderRef: nil)
        }
    }
    
    override func placeDemoTrade(latestPriceBar: PriceBar) {
        ntManager.generatePlaceOrder(direction: .long,
                                     size: 1,
                                     orderType: .limit(price: latestPriceBar.candleStick.close - 300),
                                     orderRef: latestPriceBar.time.generateOrderIdentifier(prefix: "DEMO"))
        { result in
            let alert = NSAlert()
            
            switch result {
            case .success:
                alert.messageText = "Demo order placed successfully, please cancel it asap."
            case .failure:
                let alert = NSAlert()
                alert.messageText = "Demo order place error."
            }
            
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Dismiss")
            alert.runModal()
        }
    }
}

extension NTSessionManager: NTManagerDelegate {
    func connectionStateUpdated(connected: Bool) {
        self.connected = connected
    }
}
