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
    
    var connected = false
    
    override init() {
        super.init()
        self.ntManager = NTManager(accountId: config.ntAccountName)
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
                                 actions: [TradeActionType],
                                 completion: @escaping (TradingError?) -> ()) {
        if !connected {
            completion(.brokerNotConnected)
            return
        }
        if currentPriceBarTime?.isInSameMinute(date: priceBarTime) ?? false {
            // Actions for this bar already processed
            print(Date().hourMinuteSecond() + ": Actions for " + priceBarTime.hourMinuteSecond() + " already processed")
            return
        }
        currentPriceBarTime = priceBarTime
        
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            let semaphore = DispatchSemaphore(value: 0)
            var inProcessActionIndex: Int = 0
            for action in actions {
                print(action.description(actionBarTime: priceBarTime))
                
                switch action {
                case .openPosition(let newPosition, _):
                    self.ntManager.cleanUpOrderResponseFiles()
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
                            DispatchQueue.main.async {
                                completion(ntError)
                            }
                        }
                        semaphore.signal()
                    }
                case .reversePosition(let oldPosition, let newPosition, _):
                    self.ntManager.cleanUpOrderResponseFiles()
                    self.enterAtMarket(reverseOrder: true,
                                       priceBarTime: priceBarTime,
                                       stop: newPosition.stopLoss?.stop,
                                       direction: newPosition.direction,
                                       size: newPosition.size)
                    { result in
                        switch result {
                        case .success(let confirmation):
                            DispatchQueue.main.async {
                                let trade = Trade(direction: oldPosition.direction,
                                                  entryTime: oldPosition.entryTime,
                                                  idealEntryPrice: oldPosition.idealEntryPrice,
                                                  actualEntryPrice: oldPosition.actualEntryPrice,
                                                  exitTime: confirmation.time,
                                                  idealExitPrice: newPosition.idealEntryPrice,
                                                  actualExitPrice: confirmation.price,
                                                  commission: oldPosition.commission + confirmation.commission)
                                self.trades.append(trade)
                                
                                self.pos = newPosition
                                self.pos?.entryOrderRef = confirmation.orderRef
                                self.pos?.entryTime = confirmation.time
                                self.pos?.actualEntryPrice = confirmation.price
                                self.pos?.commission = confirmation.commission
                                self.pos?.stopLoss?.stopOrderId = confirmation.stopOrderId
                                completion(nil)
                            }
                            
                        case .failure(let ntError):
                            DispatchQueue.main.async {
                                completion(ntError)
                            }
                        }
                        semaphore.signal()
                    }
                case .updateStop(let newStop):
                    guard let currentPosition = self.pos, let stopOrderId = currentPosition.stopLoss?.stopOrderId else {
                        DispatchQueue.main.async {
                            completion(.modifyOrderFailed)
                        }
                        semaphore.signal()
                        continue
                    }
                    self.ntManager.changeOrder(orderRef: stopOrderId, size: currentPosition.size, price: newStop.stop, completion:
                    { result in
                        switch result {
                        case .success:
                            self.pos?.stopLoss?.stop = newStop.stop
                            DispatchQueue.main.async {
                                completion(nil)
                            }
                        case .failure(let error):
                            DispatchQueue.main.async {
                                completion(error)
                            }
                        }
                        semaphore.signal()
                    })
                case .forceClosePosition(let closedPosition, let closingPrice, _, _):
                    self.ntManager.cleanUpOrderResponseFiles()
                    self.ntManager.closePosition(completion: { result in
                        switch result {
                        case .success(let confirmation):
                            print("Order confirmation:", confirmation)
                            let trade = Trade(direction: closedPosition.direction,
                                              entryTime: closedPosition.entryTime,
                                              idealEntryPrice: closedPosition.idealEntryPrice,
                                              actualEntryPrice: closedPosition.actualEntryPrice,
                                              exitTime: confirmation?.time ?? Date(),
                                              idealExitPrice: closingPrice,
                                              actualExitPrice: confirmation?.price ?? closingPrice,
                                              commission: closedPosition.commission * 2)
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
                    })
                case .verifyPositionClosed(let closedPosition, let closingPrice, _, _):
                    if self.pos != nil, let latestFilledOrderResponse = self.ntManager.getLatestFilledOrderResponse() {
                        print("Latest filled order response:", latestFilledOrderResponse)
                        let trade = Trade(direction: closedPosition.direction,
                                          entryTime: closedPosition.entryTime,
                                          idealEntryPrice: closedPosition.idealEntryPrice,
                                          actualEntryPrice: closedPosition.idealEntryPrice,
                                          exitTime: Date(),
                                          idealExitPrice: closingPrice,
                                          actualExitPrice: latestFilledOrderResponse.price,
                                          commission: closedPosition.commission * 2)
                        self.trades.append(trade)
                        self.pos = nil
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                        self.ntManager.cleanUpOrderResponseFiles()
                    } else {
                        DispatchQueue.main.async {
                            completion(.positionNotClosed)
                        }
                    }
                    semaphore.signal()
                case .noAction(_):
                    semaphore.signal()
                }
                inProcessActionIndex += 1
                if actions.count > 1, inProcessActionIndex < actions.count {
                    print("Wait 1 second before executing the next consecutive order")
                    sleep(1)
                }
            }
            semaphore.wait()
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
            
            // Buy/sell order:
            if reverseOrder {
                let orderRef = priceBarTime.generateOrderIdentifier(prefix: direction.description(short: true))
                self.ntManager.reversePositionAndPlaceOrder(direction: direction, size: size, orderType: .market, orderRef: orderRef, completion:
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
            
            if let errorSoFar = errorSoFar {
                DispatchQueue.main.async {
                    completion(.failure(errorSoFar))
                }
                return
            }
            
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
            
            DispatchQueue.main.async {
                print("Order confirmation:", orderConfirmation)
                print("Stop confirmation:", stopConfirmation)
                
                if var confirmation = orderConfirmation {
                    confirmation.stopOrderId = stopConfirmation?.orderId
                    completion(.success(confirmation))
                } else {
                    completion(.failure(errorSoFar ?? .orderFailed))
                }
            }
        }
    }
    
    override func exitPositions(priceBarTime: Date, idealExitPrice: Double, exitReason: ExitMethod, completion: @escaping (TradingError?) -> Void) {
        ntManager.closePosition(completion: { [weak self] result in
            guard let self = self else {
                return
            }
            switch result {
            case .success(let orderConfirmation):
                print("Order confirmation:", orderConfirmation)
                
                if let currentPosition = self.pos {
                    let trade = Trade(direction: currentPosition.direction,
                                      entryTime: currentPosition.entryTime,
                                      idealEntryPrice: currentPosition.idealEntryPrice,
                                      actualEntryPrice: currentPosition.idealEntryPrice,
                                      exitTime: orderConfirmation?.time ?? Date(),
                                      idealExitPrice: idealExitPrice,
                                      actualExitPrice: orderConfirmation?.price ?? idealExitPrice,
                                      commission: currentPosition.commission + (orderConfirmation?.commission ?? currentPosition.commission))
                    self.trades.append(trade)
                    self.pos = nil
                }
                completion(nil)
            case .failure:
                completion(.positionNotClosed)
            }
        })
    }
}

extension NTSessionManager: NTManagerDelegate {
    func connectionStateUpdated(connected: Bool) {
        self.connected = connected
    }
}
