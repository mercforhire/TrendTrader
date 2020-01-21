//
//  SessionManager.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-31.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class IBSessionManager: BaseSessionManager {
    private let networkManager = IBManager.shared
    private var stopOrders: [LiveOrder] = []
    
    override func resetSession() {
        super.resetSession()
        stopOrders = []
    }
    
    override func refreshStatus() {
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let semaphore = DispatchSemaphore(value: 0)
            
            self.networkManager.fetchAccounts { _ in
                semaphore.signal()
            }
            semaphore.wait()
            
            self.networkManager.fetchRelevantPositions { [weak self] result in
                guard let self = self else {
                    semaphore.signal()
                    return
                }
                
                switch result {
                case .success(let response):
                    if let ibPosition = response {
                        self.status = PositionStatus(position: ibPosition.position, price: ibPosition.avgPrice)
                    } else {
                        self.status = PositionStatus(position: 0, price: 0)
                    }
                case .failure:
                    break
                }
                semaphore.signal()
            }
            semaphore.wait()
            
            self.networkManager.fetchLiveStopOrders { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let orders):
                    self.stopOrders = orders
                case .failure:
                    break
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    if self.liveMonitoring {
                        self.resetTimer()
                    }
                }
            }
        }
    }
    
    override func exitPositions(priceBarTime: Date, idealExitPrice: Double, exitReason: ExitMethod, completion: @escaping (TradingError?) -> Void) {
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var errorSoFar: TradingError?
            
            // cancel stop order
            self.deleteAllStopOrders { networkError in
                if let networkError = networkError {
                    errorSoFar = networkError
                }
                semaphore.signal()
            }
            
            semaphore.wait()
            
            // reverse current position
            var ibPosition: IBPosition?
            self.networkManager.fetchRelevantPositions { result in
                switch result {
                case .success(let response):
                    ibPosition = response
                case .failure(let error):
                    errorSoFar = error
                }
                
                semaphore.signal()
            }
            semaphore.wait()
            
            if let ibPosition = ibPosition {
                self.enterAtMarket(priceBarTime: priceBarTime,
                                   direction: ibPosition.direction.reverse(),
                                   size: abs(ibPosition.position))
                { result in
                    switch result {
                    case .success(let exitOrderConfirmation):
                        if let currentPosition = self.pos {
                            let trade = Trade(direction: ibPosition.direction,
                                              entryTime: currentPosition.entryTime,
                                              idealEntryPrice: currentPosition.idealEntryPrice,
                                              actualEntryPrice: currentPosition.actualEntryPrice,
                                              entryOrderRef: currentPosition.entryOrderRef,
                                              exitTime: exitOrderConfirmation.time,
                                              idealExitPrice: idealExitPrice,
                                              actualExitPrice: exitOrderConfirmation.price,
                                              exitOrderRef: exitOrderConfirmation.orderRef,
                                              commission: currentPosition.commission + exitOrderConfirmation.commission)
                            self.trades.append(trade)
                            self.pos = nil
                        }
                    case .failure(let networkError):
                        errorSoFar = networkError
                    }
                    semaphore.signal()
                }
                
                semaphore.wait()
            }
            
            DispatchQueue.main.async {
                completion(errorSoFar)
            }
        }
    }
    
    override func processActions(priceBarTime: Date,
                                 actions: [TradeActionType],
                                 completion: @escaping (TradingError?) -> ()) {
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
            var retriedTimes: Int = 1
            while inProcessActionIndex < actions.count {
                let action = actions[inProcessActionIndex]
                
                if retriedTimes >= self.config.maxIBActionRetryTimes {
                    print("Action have been retried more than", self.config.maxIBActionRetryTimes, "times, skipping...")
                    inProcessActionIndex += 1
                    retriedTimes = 1
                    continue
                }
                
                print(action.description(actionBarTime: priceBarTime))
                
                switch action {
                case .openPosition(let newPosition, _):
                    let previousMinute = Date().getOffByMinutes(minutes: -1)
                    if !previousMinute.isInSameMinute(date: priceBarTime) {
                        print("Open Position action expired, skipping...")
                        inProcessActionIndex += 1
                        continue
                    }
                    
                    self.enterAtMarket(priceBarTime: priceBarTime, stop: newPosition.stopLoss?.stop, direction: newPosition.direction, size: newPosition.size)
                    { result in
                        switch result {
                        case .success(let orderConfirmation):
                            DispatchQueue.main.async {
                                self.pos = newPosition
                                self.pos?.actualEntryPrice = orderConfirmation.price
                                self.pos?.entryTime = orderConfirmation.time
                                self.pos?.entryOrderRef = orderConfirmation.orderRef
                                self.pos?.stopLoss?.stopOrderId = orderConfirmation.stopOrderId
                                self.pos?.commission = orderConfirmation.commission
                                completion(nil)
                            }
                            inProcessActionIndex += 1
                        case .failure(let networkError):
                            DispatchQueue.main.async {
                                completion(networkError)
                            }
                            retriedTimes += 1
                        }
                        
                        semaphore.signal()
                    }
                case .reversePosition(let oldPosition, let newPosition, _):
                    let previousMinute = Date().getOffByMinutes(minutes: -1)
                    if !previousMinute.isInSameMinute(date: priceBarTime) {
                        print("Reverse Position action expired, skipping...")
                        inProcessActionIndex += 1
                        continue
                    }
                    
                    self.removeStopOrdersAndEnterAtMarket(priceBarTime: priceBarTime, stop: newPosition.stopLoss?.stop, direction: newPosition.direction, size: oldPosition.size + newPosition.size)
                    { result in
                        switch result {
                        case .success(let orderConfirmation):
                            DispatchQueue.main.async {
                                // closed old position
                                let trade = Trade(direction: oldPosition.direction,
                                                  entryTime: oldPosition.entryTime,
                                                  idealEntryPrice: oldPosition.idealEntryPrice,
                                                  actualEntryPrice: oldPosition.actualEntryPrice,
                                                  entryOrderRef: oldPosition.entryOrderRef,
                                                  exitTime: orderConfirmation.time,
                                                  idealExitPrice: newPosition.idealEntryPrice,
                                                  actualExitPrice: orderConfirmation.price,
                                                  exitOrderRef: orderConfirmation.orderRef,
                                                  commission: oldPosition.commission + orderConfirmation.commission)
                                self.trades.append(trade)
                                
                                // opened new position
                                self.pos = newPosition
                                self.pos?.actualEntryPrice = orderConfirmation.price
                                self.pos?.entryTime = orderConfirmation.time
                                self.pos?.entryOrderRef = orderConfirmation.orderRef
                                self.pos?.stopLoss?.stopOrderId = orderConfirmation.stopOrderId
                                self.pos?.commission = orderConfirmation.commission
                                completion(nil)
                            }
                            inProcessActionIndex += 1
                        case .failure(let networkError):
                            DispatchQueue.main.async {
                                completion(networkError)
                            }
                            retriedTimes += 1
                        }
                        
                        semaphore.signal()
                    }
                case .updateStop(let newStop):
                    guard let stopOrderId = self.pos?.stopLoss?.stopOrderId,
                        let size = self.pos?.size,
                        let direction = self.pos?.direction else {
                            DispatchQueue.main.async {
                                completion(.modifyOrderFailed)
                            }
                            retriedTimes += 1
                            semaphore.signal()
                            return
                    }
                    
                    self.modifyStopOrder(stopOrderId: stopOrderId,
                                         stop: newStop.stop,
                                         quantity: size,
                                         direction: direction.reverse()) { networkError in
                                            if networkError == nil {
                                                self.pos?.stopLoss?.stop = newStop.stop
                                            }
                                            DispatchQueue.main.async {
                                                completion(networkError)
                                            }
                                            if networkError == nil {
                                                inProcessActionIndex += 1
                                            } else {
                                                retriedTimes += 1
                                            }
                                            semaphore.signal()
                    }
                case .forceClosePosition(_, let idealExitPrice, _, let reason):
                    self.exitPositions(priceBarTime: priceBarTime,
                                       idealExitPrice: idealExitPrice,
                                       exitReason: reason,
                                       completion:
                        { networkError in
                            DispatchQueue.main.async {
                                completion(networkError)
                            }
                            
                            if networkError != nil {
                                retriedTimes += 1
                            } else {
                                inProcessActionIndex += 1
                            }
                            
                            semaphore.signal()
                    })
                case .verifyPositionClosed(let closedPosition, let idealClosingPrice, _, let reason):
                    self.verifyClosedPosition(closedPosition: closedPosition, reason: reason) { result in
                        switch result {
                        case .success(let orderConfirmation):
                            DispatchQueue.main.async {
                                if let orderConfirmation = orderConfirmation {
                                    self.pos = nil
                                    let trade = Trade(direction: closedPosition.direction,
                                                      entryTime: closedPosition.entryTime,
                                                      idealEntryPrice: closedPosition.idealEntryPrice,
                                                      actualEntryPrice: closedPosition.actualEntryPrice,
                                                      entryOrderRef: closedPosition.entryOrderRef,
                                                      exitTime: orderConfirmation.time,
                                                      idealExitPrice: idealClosingPrice,
                                                      actualExitPrice: orderConfirmation.price,
                                                      exitOrderRef: orderConfirmation.orderRef,
                                                      commission: closedPosition.commission + orderConfirmation.commission)
                                    self.trades.append(trade)
                                }
                                completion(nil)
                            }
                            inProcessActionIndex += 1
                        case .failure(let networkError):
                            DispatchQueue.main.async {
                                completion(networkError)
                            }
                            retriedTimes += 1
                        }
                        
                        semaphore.signal()
                    }
                case .noAction(_):
                    inProcessActionIndex += 1
                    semaphore.signal()
                }
                
                semaphore.wait()
                
                if actions.count > 1, inProcessActionIndex < actions.count {
                    print("Wait 1 second before executing the next consecutive order")
                    sleep(1)
                }
            }
        }
    }
    
    private func removeStopOrdersAndEnterAtMarket(priceBarTime: Date,
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
            
            self.deleteAllStopOrders { networkError in
                errorSoFar = networkError
                semaphore.signal()
            }
            semaphore.wait()
            
            if let errorSoFar = errorSoFar {
                DispatchQueue.main.async {
                    completion(.failure(errorSoFar))
                }
                return
            }
            
            DispatchQueue.main.async {
                self.enterAtMarket(priceBarTime: priceBarTime, stop: stop, direction: direction, size: size, completion: completion)
            }
        }
    }
    
    private func enterAtMarket(priceBarTime: Date,
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
            let orderRef = priceBarTime.generateOrderIdentifier(prefix: direction.description(short: true))
            var orderId: String?
            var stopOrderId: String?
            
            if let stop = stop {
                self.networkManager.placeBrackOrder(orderRef: orderRef,
                                                    stopPrice: stop,
                                                    direction: direction,
                                                    size: size)
                { result in
                    switch result {
                    case .success(let entryOrderConfirmations):
                        if entryOrderConfirmations.count > 1 {
                            let entryOrderConfirmation = entryOrderConfirmations.filter { confirmation -> Bool in
                                return confirmation.localOrderId != nil
                            }.first
                            let stopOrderConfirmation = entryOrderConfirmations.filter { confirmation -> Bool in
                                return confirmation.parentOrderId != nil
                            }.first
                            
                            if let entryOrderConfirmation = entryOrderConfirmation, let stopOrderConfirmation = stopOrderConfirmation {
                                orderId = entryOrderConfirmation.orderId
                                stopOrderId = stopOrderConfirmation.orderId
                            } else {
                                errorSoFar = .noOrderResponse
                            }
                        } else {
                            errorSoFar = .noOrderResponse
                        }
                    case .failure(let networkError):
                        if networkError != .orderAlreadyPlaced {
                            errorSoFar = networkError
                        }
                    }
                    semaphore.signal()
                }
                semaphore.wait()
            } else {
                self.networkManager.placeOrder(orderRef: orderRef,
                                               orderType: .market,
                                               direction: direction,
                                               size: size)
                { result in
                    switch result {
                    case .success(let response):
                        if let newOrderId = response.first?.orderId {
                            orderId = newOrderId
                        } else {
                            errorSoFar = .noOrderResponse
                        }
                    case .failure(let networkError):
                        if networkError != .orderAlreadyPlaced {
                            errorSoFar = networkError
                        }
                    }
                    semaphore.signal()
                }
                semaphore.wait()
            }
            
            if let errorSoFar = errorSoFar {
                DispatchQueue.main.async {
                    completion(.failure(errorSoFar))
                }
                return
            }
            
            self.networkManager.fetchTrades { result in
                switch result {
                case .success(let trades):
                    let matchingTrades = trades.filter { trade -> Bool in
                        return trade.orderRef == orderRef && trade.direction == direction && trade.size == size
                    }
                    if let recentTrade = matchingTrades.first,
                        let actualPrice = recentTrade.price.double,
                        let orderId = orderId {
                        
                        DispatchQueue.main.async {
                            let orderConfirmation = OrderConfirmation(price: actualPrice,
                                                                      time: recentTrade.tradeTime,
                                                                      orderId: orderId,
                                                                      orderRef: orderRef,
                                                                      stopOrderId: stopOrderId,
                                                                      commission: recentTrade.commission?.double ?? self.config.ibCommission)
                            completion(.success(orderConfirmation))
                        }
                    } else {
                        completion(.failure(.orderFailed))
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    private func deleteAllStopOrders(completion: @escaping (TradingError?) -> ()) {
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var foundError: TradingError?
            for order in self.stopOrders {
                if foundError != nil {
                    break
                }
                
                self.deleteStopOrder(stopOrderId: String(format: "%d", order.orderId)) { networkError in
                    if let networkError = networkError {
                        foundError = networkError
                    }
                    semaphore.signal()
                }
                semaphore.wait()
            }
            
            DispatchQueue.main.async {
                completion(foundError)
            }
        }
    }
    
    private func deleteStopOrder(stopOrderId: String, completion: @escaping (TradingError?) -> ()) {
        networkManager.deleteOrder(orderId: stopOrderId) { result in
            switch result {
            case .success(let success):
                if !success {
                    completion(.deleteOrderFailed)
                } else {
                    completion(nil)
                }
            case .failure(let error):
                completion(error)
            }
        }
    }
    
    private func modifyStopOrder(stopOrderId: String,
                                 stop: Double,
                                 quantity: Int,
                                 direction: TradeDirection,
                                 completion: @escaping (TradingError?) -> ()) {
        networkManager.modifyOrder(orderType: .stop(price: stop), direction: direction, price: stop, quantity: quantity, orderId: stopOrderId) { result in
            switch result {
            case .success:
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        }
    }
    
    private func verifyClosedPosition(closedPosition: Position,
                                      reason: ExitMethod,
                                      completion: @escaping (Swift.Result<OrderConfirmation?, TradingError>) -> Void) {
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var errorSoFar: TradingError?
            
            self.networkManager.fetchAccounts { accounts in
                if accounts == nil {
                    errorSoFar = .fetchAccountsFailed
                }
                semaphore.signal()
            }
            semaphore.wait()
            
            if let errorSoFar = errorSoFar {
                DispatchQueue.main.async {
                    completion(.failure(errorSoFar))
                }
                return
            }
            
            self.networkManager.fetchRelevantPositions { result in
                switch result {
                case .success(let response):
                    if response != nil {
                        errorSoFar = .positionNotClosed
                    }
                case .failure(let error):
                    errorSoFar = error
                }
                semaphore.signal()
            }
            semaphore.wait()
            
            if errorSoFar == .positionNotClosed {
                DispatchQueue.main.async {
                    completion(.success(nil))
                }
                return
            }
            
            if let errorSoFar = errorSoFar {
                DispatchQueue.main.async {
                    completion(.failure(errorSoFar))
                }
                return
            }
            
            self.networkManager.fetchTrades { result in
                switch result {
                case .success(let trades):
                    let matchingTrades = trades.filter { trade -> Bool in
                        return trade.tradeTime > closedPosition.entryTime &&
                            trade.direction != closedPosition.direction &&
                            trade.size == closedPosition.size &&
                            trade.position == "0"
                    }
                    if let closingTrade = matchingTrades.first, let closingPrice = closingTrade.price.double {
                        let orderConfirmation = OrderConfirmation(price: closingPrice,
                                                                  time: closingTrade.tradeTime,
                                                                  orderRef: closingTrade.orderRef ?? "STOPORDER",
                                                                  commission: closingTrade.commission?.double ?? self.config.ibCommission)
                        DispatchQueue.main.async {
                            completion(.success(orderConfirmation))
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
}
