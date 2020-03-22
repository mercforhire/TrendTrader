//
//  NTSessionManager.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-01-18.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation

class NTSessionManager: BaseSessionManager {
    private var ntManager: NTManager!
    private let commission: Double
    
    override var liveUpdateFrequency: TimeInterval { 1 }
    var connected = false
    
    init(accountId: String,
         commission: Double,
         ticker: String,
         exchange: String,
         accountLongName: String,
         basePath: String,
         incomingPath: String,
         outgoingPath: String) {
        self.commission = commission
        super.init()
        
        self.ntManager = NTManager(accountId: accountId,
                                   commission: commission,
                                   ticker: ticker,
                                   exchange: exchange,
                                   accountLongName: accountLongName,
                                   basePath: basePath,
                                   incomingPath: incomingPath,
                                   outgoingPath: outgoingPath)
        self.ntManager.initialize()
        self.ntManager.delegate = self
    }
    
    override func refreshStatus() {
        status = ntManager.readPositionStatusFile()
        if self.liveMonitoring {
            self.resetTimer()
        }
    }
    
    override func processActions(priceBarTime: Date,
                                 action: TradeActionType,
                                 completion: @escaping (TradingError?) -> ()) {
        if !connected {
            completion(.brokerNotConnected)
            return
        }
        
        if currentPriceBarTime?.isInSameMinute(date: priceBarTime) ?? false {
            // Actions for this bar already processed
            print("\(Date().hourMinuteSecond()): Actions for \(priceBarTime.hourMinuteSecond()) already processed")
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
                print(action.description(actionBarTime: priceBarTime))
            default:
                self.delegate?.newLogAdded(log: action.description(actionBarTime: priceBarTime))
            }
            
            switch action {
            case .openPosition(let newPosition, _):
                var skip = false
                if let currentPosition = self.pos, currentPosition.direction == newPosition.direction {
                    self.delegate?.newLogAdded(log: "Already has existing position, skipping opening new position")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                } else if let currentPosition = self.pos, currentPosition.direction != newPosition.direction {
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
                }
                
                guard !skip else { return }
                
                self.enterAtMarket(priceBarTime: priceBarTime,
                                   stop: newPosition.stopLoss?.stop,
                                   direction: newPosition.direction,
                                   size: newPosition.size)
                { result in
                    switch result {
                    case .success(let confirmation):
                        DispatchQueue.main.async {
                            self.pos = newPosition
                            self.pos?.entryOrderRef = confirmation.orderRef
                            self.pos?.entryTime = confirmation.time
                            self.pos?.actualEntryPrice = confirmation.price
                            self.pos?.commission = confirmation.commission
                            self.pos?.stopLoss?.stopOrderId = confirmation.stopOrderId
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
            case .reversePosition(let oldPosition, let newPosition, _):
                let tradeAlreadyClosed = self.status?.position == 0
                self.enterAtMarket(reverseOrder: !tradeAlreadyClosed,
                                   priceBarTime: priceBarTime,
                                   stop: newPosition.stopLoss?.stop,
                                   direction: newPosition.direction,
                                   size: newPosition.size)
                { result in
                    switch result {
                    case .success(let confirmation):
                        DispatchQueue.main.async {
                            if !tradeAlreadyClosed {
                                let trade = Trade(direction: oldPosition.direction,
                                                  entryTime: oldPosition.entryTime,
                                                  idealEntryPrice: oldPosition.idealEntryPrice,
                                                  actualEntryPrice: oldPosition.actualEntryPrice,
                                                  exitTime: confirmation.time,
                                                  idealExitPrice: newPosition.idealEntryPrice,
                                                  actualExitPrice: confirmation.price,
                                                  commission: oldPosition.commission + confirmation.commission)
                                self.trades.append(trade)
                            }
                            self.pos = newPosition
                            self.pos?.entryOrderRef = confirmation.orderRef
                            self.pos?.entryTime = confirmation.time
                            self.pos?.actualEntryPrice = confirmation.price
                            self.pos?.commission = confirmation.commission
                            self.pos?.stopLoss?.stopOrderId = confirmation.stopOrderId
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
            case .updateStop(let newStop):
                guard let currentPosition = self.pos else {
                    DispatchQueue.main.async {
                        completion(.modifyOrderFailed)
                    }
                    return
                }
                
                if let stopOrderId = currentPosition.stopLoss?.stopOrderId {
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
            case .forceClosePosition(let closedPosition, let closingPrice, _, _):
                if let stopOrderId = self.pos?.stopLoss?.stopOrderId,
                    let latestFilledOrderResponse = self.ntManager.getOrderResponse(orderId: stopOrderId),
                    latestFilledOrderResponse.status == .filled {
                    self.delegate?.newLogAdded(log: "Force close position already closed, last filled order response: \(latestFilledOrderResponse.description)")
                    let trade = Trade(direction: closedPosition.direction,
                                      entryTime: closedPosition.entryTime,
                                      idealEntryPrice: closedPosition.idealEntryPrice,
                                      actualEntryPrice: closedPosition.actualEntryPrice,
                                      exitTime: latestFilledOrderResponse.time,
                                      idealExitPrice: closingPrice,
                                      actualExitPrice: latestFilledOrderResponse.price,
                                      commission: closedPosition.commission * 2)
                    self.trades.append(trade)
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
                                              entryTime: closedPosition.entryTime,
                                              idealEntryPrice: closedPosition.idealEntryPrice,
                                              actualEntryPrice: closedPosition.actualEntryPrice,
                                              exitTime: confirmation.time,
                                              idealExitPrice: closingPrice,
                                              actualExitPrice: confirmation.price,
                                              commission: closedPosition.commission + confirmation.commission)
                            self.trades.append(trade)
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
            case .verifyPositionClosed(let closedPosition, let closingPrice, _, _):
                if self.status?.position == 0,
                    let stopOrderId = self.pos?.stopLoss?.stopOrderId {
                    if let latestFilledOrderResponse = self.ntManager.getOrderResponse(orderId: stopOrderId),
                    latestFilledOrderResponse.status == .filled {
                        self.delegate?.newLogAdded(log: "Latest filled order response: \(latestFilledOrderResponse.description)")
                        let trade = Trade(direction: closedPosition.direction,
                                          entryTime: closedPosition.entryTime,
                                          idealEntryPrice: closedPosition.idealEntryPrice,
                                          actualEntryPrice: closedPosition.actualEntryPrice,
                                          exitTime: latestFilledOrderResponse.time,
                                          idealExitPrice: closingPrice,
                                          actualExitPrice: latestFilledOrderResponse.price,
                                          commission: closedPosition.commission * 2)
                        self.trades.append(trade)
                        self.pos = nil
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                    } else if self.status?.position == 0, self.pos == nil {
                        self.delegate?.newLogAdded(log: "Position already closed")
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                    } else {
                        self.delegate?.newLogAdded(log: "Position not closed, flat all positions immediately")
                        self.ntManager.flatEverything()
                        DispatchQueue.main.async {
                            completion(.positionNotClosed)
                        }
                    }
                } else {
                    self.delegate?.newLogAdded(log: "Position not closed, flat all positions immediately")
                    self.ntManager.flatEverything()
                    DispatchQueue.main.async {
                        completion(.positionNotClosed)
                    }
                }
            case .noAction(_):
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
                    print("Order confirmation: \(orderConfirmation.description)")
                    if let currentPosition = self.pos {
                        let trade = Trade(direction: currentPosition.direction,
                                          entryTime: currentPosition.entryTime,
                                          idealEntryPrice: currentPosition.idealEntryPrice,
                                          actualEntryPrice: currentPosition.idealEntryPrice,
                                          exitTime: orderConfirmation.time,
                                          idealExitPrice: idealExitPrice,
                                          actualExitPrice: orderConfirmation.price,
                                          commission: currentPosition.commission + orderConfirmation.commission)
                        self.trades.append(trade)
                        self.pos = nil
                    }
                    completion(nil)
                case .failure:
                    completion(.positionNotClosed)
                }
            }
        }
    }
    
    override func updateCurrentPositionToBeClosed() {
        if let closedPosition = self.pos,
            let stopOrderId = closedPosition.stopLoss?.stopOrderId,
            let latestFilledOrderResponse = self.ntManager.getOrderResponse(orderId: stopOrderId),
            latestFilledOrderResponse.status == .filled {
            
            self.delegate?.newLogAdded(log: "Detected position closed, last filled order response: \(latestFilledOrderResponse.description)")
            let trade = Trade(direction: closedPosition.direction,
                              entryTime: closedPosition.entryTime,
                              idealEntryPrice: closedPosition.idealEntryPrice,
                              actualEntryPrice: closedPosition.actualEntryPrice,
                              exitTime: latestFilledOrderResponse.time,
                              idealExitPrice: latestFilledOrderResponse.price,
                              actualExitPrice: latestFilledOrderResponse.price,
                              commission: closedPosition.commission * 2)
            self.trades.append(trade)
            self.pos = nil
            self.delegate?.positionStatusChanged()
        }
    }
    
    override func startLiveMonitoring() {
        super.startLiveMonitoring()
        
        if let existingPosition = status?.position,
            existingPosition != 0,
            pos == nil,
            let existingPrice = status?.price {
            self.delegate?.newLogAdded(log: "Exiting position detected: \(existingPosition)")
            pos = Position(direction: existingPosition > 0 ? .long : .short,
                           size: abs(existingPosition),
                           entryTime: Date(),
                           idealEntryPrice: existingPrice,
                           actualEntryPrice: existingPrice,
                           stopLoss: nil,
                           entryOrderRef: nil,
                           commission: self.commission)
        }
    }
}

extension NTSessionManager: NTManagerDelegate {
    func connectionStateUpdated(connected: Bool) {
        self.connected = connected
    }
}
