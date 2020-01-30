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
    
    override func processActions(priceBarTime: Date,
                                 action: TradeActionType,
                                 completion: @escaping (TradingError?) -> ()) {
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
            
            var actionCompleted: Bool = false
            var retriedTimes: Int = 1
            while !actionCompleted {
                if retriedTimes >= self.config.maxIBActionRetryTimes {
                    self.delegate?.newLogAdded(log: "Action have been retried more than \(self.config.maxIBActionRetryTimes) times, skipping...")
                    break
                }
                
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
                            if let networkError = error {
                                skip = true
                                DispatchQueue.main.async {
                                    completion(networkError)
                                }
                            } else {
                                self.pos = nil
                            }
                            semaphore.signal()
                        }
                        semaphore.wait()
                    }
                    
                    if skip {
                        retriedTimes += 1
                        continue
                    }
                    
                    self.enterAtMarket(priceBarTime: priceBarTime,
                                       stop: newPosition.stopLoss?.stop,
                                       direction: newPosition.direction,
                                       size: newPosition.size)
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
                            actionCompleted = true
                        case .failure(let networkError):
                            DispatchQueue.main.async {
                                completion(networkError)
                            }
                            retriedTimes += 1
                        }
                        semaphore.signal()
                    }
                    semaphore.wait()
                case .reversePosition(let oldPosition, let newPosition, _):
                    self.reversePosition(priceBarTime: priceBarTime,
                                         ideaExitPrice: newPosition.idealEntryPrice,
                                         stop: newPosition.stopLoss?.stop,
                                         direction: newPosition.direction,
                                         size: oldPosition.size)
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
                            actionCompleted = true
                        case .failure(let networkError):
                            DispatchQueue.main.async {
                                completion(networkError)
                            }
                            retriedTimes += 1
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
                        self.modifyStopOrder(stopOrderId: stopOrderId,
                                             stop: newStop.stop,
                                             quantity: currentPosition.size,
                                             direction: currentPosition.direction.reverse())
                        { networkError in
                            if networkError == nil {
                                self.pos?.stopLoss?.stop = newStop.stop
                            }
                            DispatchQueue.main.async {
                                completion(networkError)
                            }
                            if networkError == nil {
                                actionCompleted = true
                            } else {
                                retriedTimes += 1
                            }
                            semaphore.signal()
                        }
                    } else {
                        let stopOrderId = priceBarTime.generateOrderIdentifier(prefix: currentPosition.direction.reverse().description(short: true))
                        self.networkManager.placeOrder(orderRef: stopOrderId,
                                                       orderType: .stop(price: newStop.stop),
                                                       direction: currentPosition.direction.reverse(),
                                                       size: currentPosition.size)
                        { result in
                            switch result {
                            case .success:
                                self.pos?.stopLoss = newStop
                                self.pos?.stopLoss?.stopOrderId = stopOrderId
                                DispatchQueue.main.async {
                                    completion(nil)
                                }
                                actionCompleted = true
                            case .failure(let networkError):
                                DispatchQueue.main.async {
                                    completion(networkError)
                                }
                                retriedTimes += 1
                            }
                            semaphore.signal()
                        }
                    }
                    semaphore.wait()
                case .forceClosePosition(_, let idealExitPrice, _, let reason):
                    self.exitPositions(priceBarTime: priceBarTime,
                                       idealExitPrice: idealExitPrice,
                                       exitReason: reason)
                    { networkError in
                        DispatchQueue.main.async {
                            completion(networkError)
                        }
                        
                        if networkError != nil {
                            retriedTimes += 1
                        } else {
                            actionCompleted = true
                        }
                        
                        semaphore.signal()
                    }
                    semaphore.wait()
                case .verifyPositionClosed(let closedPosition, let idealClosingPrice, _, let reason):
                    self.verifyClosedPosition(closedPosition: closedPosition, reason: reason)
                    { result in
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
                            actionCompleted = true
                        case .failure(let networkError):
                            DispatchQueue.main.async {
                                completion(networkError)
                            }
                            retriedTimes += 1
                        }
                        semaphore.signal()
                    }
                    semaphore.wait()
                case .noAction(_):
                    actionCompleted = true
                }
            }
        }
    }
    
    override func exitPositions(priceBarTime: Date,
                                idealExitPrice: Double,
                                exitReason: ExitMethod,
                                completion: @escaping (TradingError?) -> Void) {
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
            } else if let outdatedPosition = self.pos {
                self.networkManager.fetchTrades { result in
                    switch result {
                    case .success(let trades):
                        let matchingTrades = trades.filter { trade -> Bool in
                            return trade.tradeTime > outdatedPosition.entryTime &&
                                trade.direction != outdatedPosition.direction &&
                                trade.size == outdatedPosition.size &&
                                trade.position == "0"
                        }
                        if let closingTrade = matchingTrades.first, let closingPrice = closingTrade.price.double {
                            let trade = Trade(direction: outdatedPosition.direction,
                                              entryTime: outdatedPosition.entryTime,
                                              idealEntryPrice: outdatedPosition.idealEntryPrice,
                                              actualEntryPrice: outdatedPosition.actualEntryPrice,
                                              entryOrderRef: outdatedPosition.entryOrderRef,
                                              exitTime: closingTrade.tradeTime,
                                              idealExitPrice: outdatedPosition.stopLoss?.stop ?? closingPrice,
                                              actualExitPrice: closingPrice,
                                              exitOrderRef: closingTrade.orderRef ?? "STOPORDER",
                                              commission: outdatedPosition.commission * 2)
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
    
    override func updateCurrentPositionToBeClosed() {
        if let closedPosition = self.pos {
            self.delegate?.newLogAdded(log: "Detected position closed")
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
                        let trade = Trade(direction: closedPosition.direction,
                                          entryTime: closedPosition.entryTime,
                                          idealEntryPrice: closedPosition.idealEntryPrice,
                                          actualEntryPrice: closedPosition.actualEntryPrice,
                                          exitTime: closingTrade.tradeTime,
                                          idealExitPrice: closingPrice,
                                          actualExitPrice: closingPrice,
                                          commission: closedPosition.commission + (closingTrade.commission?.double ?? closedPosition.commission))
                        self.trades.append(trade)
                        self.pos = nil
                        self.delegate?.positionStatusChanged()
                    }
                case .failure(let error):
                    error.printError()
                }
            }
        }
    }
    
    private func reversePosition(priceBarTime: Date,
                                 ideaExitPrice: Double,
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
            
            self.exitPositions(priceBarTime: priceBarTime,
                               idealExitPrice: ideaExitPrice,
                               exitReason: .signalReversed)
            { error in
                errorSoFar = error
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
                self.enterAtMarket(priceBarTime: priceBarTime,
                                   stop: stop,
                                   direction: direction,
                                   size: size,
                                   completion: completion)
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
        networkManager.modifyOrder(orderType: .stop(price: stop),
                                   direction: direction,
                                   price: stop,
                                   quantity: quantity,
                                   orderId: stopOrderId)
        { result in
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
