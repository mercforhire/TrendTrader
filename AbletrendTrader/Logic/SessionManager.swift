//
//  SessionManager.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-31.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class SessionManager {
    private let networkManager = NetworkManager.shared
    private let config = Config.shared
    private let liveUpdateFrequency: TimeInterval = 10
    
    let live: Bool
    private(set) var currentPosition: Position?
    private(set) var trades: [Trade] = []
    private var liveOrders: [LiveOrder] = []
    private var stopOrders: [LiveOrder] {
        return liveOrders.filter { liveOrder -> Bool in
            return liveOrder.orderType == "Stop" && liveOrder.status == "PreSubmitted"
        }
    }
    private var timer: Timer?
    private var monitoringLiveOrders = false
    
    var hasCurrentPosition: Bool {
        return currentPosition != nil
    }
    
    var currentPositionDirection: TradeDirection? {
        return currentPosition?.direction
    }
    
    var stopLoss: StopLoss? {
        return currentPosition?.stopLoss
    }
    
    var securedProfit: Double? {
        return currentPosition?.securedProfit
    }
    
    var currentPriceBarTime: Date?
    
    init(live: Bool) {
        self.live = live
    }
    
    func startMonitoringLiveOrders() {
        if monitoringLiveOrders {
            return
        }
        
        monitoringLiveOrders = true
        refreshLiveOrders()
    }
    
    func stopMonitoringLiveOrders() {
        monitoringLiveOrders = false    
        timer?.invalidate()
        timer = nil
    }
    
    func resetSession() {
        stopMonitoringLiveOrders()
        trades = []
        liveOrders = []
        currentPosition = nil
    }
    
    func refreshLiveOrders(completion: ((NetworkError?) -> ())? = nil) {
        if monitoringLiveOrders {
            timer?.invalidate()
        }
        
        self.networkManager.fetchLiveOrders { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let orders):
                self.liveOrders = orders
                completion?(nil)
            case .failure(let error):
                completion?(error)
                print(Date().hourMinuteSecond(), "Live orders update failed")
            }
            
            if self.monitoringLiveOrders {
                self.timer = Timer.scheduledTimer(timeInterval: self.liveUpdateFrequency,
                                                  target: self,
                                                  selector: #selector(self.refreshLiveOrdersTimerFunc),
                                                  userInfo: self,
                                                  repeats: false)
            }
        }
    }
    
    func refreshIBSession(completionHandler: ((Swift.Result<Bool, NetworkError>) -> Void)?) {
        guard live else { return }
        
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var errorSoFar: NetworkError?
            
            self.networkManager.fetchAccounts { result in
                switch result {
                case .failure(let error):
                    errorSoFar = error
                default:
                    break
                }
                semaphore.signal()
            }
            
            semaphore.wait()
            
            if let errorSoFar = errorSoFar {
                DispatchQueue.main.async {
                    completionHandler?(.failure(errorSoFar))
                }
                return
            }
            
            self.networkManager.fetchRelevantPositions { [weak self] result in
                guard let self = self else {
                    semaphore.signal()
                    return
                }
                
                switch result {
                case .success(let response):
                    if let ibPosition = response {
                        let position = ibPosition.toPosition()
                        if self.currentPosition == nil || self.currentPosition?.direction != position.direction {
                            self.currentPosition = position
                        }
                    } else {
                        self.currentPosition = nil
                    }
                case .failure(let error):
                    errorSoFar = error
                }
                
                semaphore.signal()
            }
            
            semaphore.wait()
            
            if let errorSoFar = errorSoFar {
                DispatchQueue.main.async {
                    completionHandler?(.failure(errorSoFar))
                }
                return
            }
            
            self.networkManager.fetchLiveOrders { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let orders):
                    self.liveOrders = orders
                    if let order = self.stopOrders.first,
                        let stopPrice = order.auxPrice?.double,
                        order.direction != self.currentPositionDirection {
                        self.currentPosition?.stopLoss = StopLoss(stop: stopPrice,
                                                                  source: .currentBar,
                                                                  stopOrderId: String(format: "%d", order.orderId))
                    }
                case .failure:
                    print(Date().hourMinuteSecond(), "Live orders update failed")
                }
                DispatchQueue.main.async {
                    completionHandler?(.success(true))
                }
            }
        }
    }
    
    func resetCurrentlyProcessingPriceBar() {
        currentPriceBarTime = nil
    }
    
    func processActions(priceBarTime: Date, actions: [TradeActionType], completion: @escaping (NetworkError?) -> ()) {
        if currentPriceBarTime?.isInSameMinute(date: priceBarTime) ?? false {
            // Actions for this bar already processed
            print(Date().hourMinuteSecond() + ": Actions for " + priceBarTime.hourMinuteSecond() + " already processed")
            return
        }
        currentPriceBarTime = priceBarTime
        
        
        if live {
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
                    
                    if retriedTimes >= self.config.maxActionRetryTimes {
                        print("Action have been retried more than", self.config.maxActionRetryTimes, "times, skipping...")
                        inProcessActionIndex += 1
                        retriedTimes = 1
                        continue
                    }
                    
                    print(action.description(actionBarTime: priceBarTime))
                    
                    switch action {
                    case .openedPosition(let newPosition, _):
                        self.enterAtMarket(priceBarTime: priceBarTime, stop: newPosition.stopLoss?.stop, direction: newPosition.direction, size: newPosition.size)
                        { result in
                            switch result {
                            case .success(let orderConfirmation):
                                self.currentPosition = newPosition
                                self.currentPosition?.actualEntryPrice = orderConfirmation.price
                                self.currentPosition?.entryTime = orderConfirmation.time
                                self.currentPosition?.entryOrderRef = orderConfirmation.orderRef
                                self.currentPosition?.stopLoss?.stopOrderId = orderConfirmation.stopOrderId
                                completion(nil)
                                inProcessActionIndex += 1
                            case .failure(let networkError):
                                completion(networkError)
                                retriedTimes += 1
                            }
                            
                            semaphore.signal()
                        }
                    case .reversedPosition(let oldPosition, let newPosition, _):
                        self.enterAtMarket(priceBarTime: priceBarTime, stop: newPosition.stopLoss?.stop, direction: newPosition.direction, size: oldPosition.size + newPosition.size)
                        { result in
                            switch result {
                            case .success(let orderConfirmation):
                                // closed old position
                                let trade = Trade(direction: oldPosition.direction,
                                                  entryTime: oldPosition.entryTime,
                                                  idealEntryPrice: oldPosition.idealEntryPrice,
                                                  actualEntryPrice: oldPosition.actualEntryPrice,
                                                  entryOrderRef: oldPosition.entryOrderRef,
                                                  exitTime: orderConfirmation.time,
                                                  idealExitPrice: newPosition.idealEntryPrice,
                                                  actualExitPrice: orderConfirmation.price,
                                                  exitOrderRef: orderConfirmation.orderRef)
                                self.trades.append(trade)
                                
                                // opened new position
                                self.currentPosition = newPosition
                                self.currentPosition?.actualEntryPrice = orderConfirmation.price
                                self.currentPosition?.entryTime = orderConfirmation.time
                                self.currentPosition?.entryOrderRef = orderConfirmation.orderRef
                                self.currentPosition?.stopLoss?.stopOrderId = orderConfirmation.stopOrderId
                                completion(nil)
                                inProcessActionIndex += 1
                            case .failure(let networkError):
                                completion(networkError)
                                retriedTimes += 1
                            }
                            
                            semaphore.signal()
                        }
                    case .updatedStop(let newStop):
                        guard let stopOrderId = self.currentPosition?.stopLoss?.stopOrderId,
                            let size = self.currentPosition?.size,
                            let direction = self.currentPositionDirection else {
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
                                self.currentPosition?.stopLoss?.stop = newStop.stop
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
                            { result in
                                switch result {
                                case .success:
                                    DispatchQueue.main.async {
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
                        })
                    case .verifyPositionClosed(let closedPosition, let idealClosingPrice, _, let reason):
                        self.verifyClosedPosition(closedPosition: closedPosition, reason: reason) { result in
                            switch result {
                            case .success(let orderConfirmation):
                                let trade = Trade(direction: closedPosition.direction,
                                                  entryTime: closedPosition.entryTime,
                                                  idealEntryPrice: closedPosition.idealEntryPrice,
                                                  actualEntryPrice: closedPosition.actualEntryPrice,
                                                  entryOrderRef: closedPosition.entryOrderRef,
                                                  exitTime: orderConfirmation.time,
                                                  idealExitPrice: idealClosingPrice,
                                                  actualExitPrice: orderConfirmation.price,
                                                  exitOrderRef: orderConfirmation.orderRef)
                                self.trades.append(trade)
                                self.currentPosition = nil
                                DispatchQueue.main.async {
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
                    
                    if actions.count > 1, inProcessActionIndex != actions.count - 1 {
                        print("Wait 1 second before executing the next consecutive order")
                        sleep(1)
                    }
                }
            }
        }
        
        // Simulation:
        
        else {
            for action in actions {
                
                switch action {
                case .noAction(let entryType):
                    if entryType == nil {
                        continue
                    }
                default:
                    print(action.description(actionBarTime: priceBarTime))
                }
                
                switch action {
                case .openedPosition(let newPosition, _):
                    currentPosition = newPosition
                    currentPosition?.actualEntryPrice = newPosition.idealEntryPrice
                case .reversedPosition(let oldPosition, let newPosition, _):
                    let trade = Trade(direction: oldPosition.direction,
                                      entryTime: oldPosition.entryTime,
                                      idealEntryPrice: oldPosition.idealEntryPrice,
                                      actualEntryPrice: oldPosition.idealEntryPrice,
                                      exitTime: newPosition.entryTime,
                                      idealExitPrice: newPosition.idealEntryPrice,
                                      actualExitPrice: newPosition.idealEntryPrice)
                    trades.append(trade)
                    
                    currentPosition = newPosition
                    currentPosition?.actualEntryPrice = newPosition.idealEntryPrice
                case .updatedStop(let newStop):
                    currentPosition?.stopLoss = newStop
                case .forceClosePosition(let closedPosition, let closingPrice, let closingTime, _):
                    let trade = Trade(direction: closedPosition.direction,
                                      entryTime: closedPosition.entryTime,
                                      idealEntryPrice: closedPosition.idealEntryPrice,
                                      actualEntryPrice: closedPosition.idealEntryPrice,
                                      exitTime: closingTime,
                                      idealExitPrice: closingPrice,
                                      actualExitPrice: closingPrice)
                    trades.append(trade)
                    currentPosition = nil
                case .verifyPositionClosed(let closedPosition, let closingPrice, let closingTime, _):
                    let trade = Trade(direction: closedPosition.direction,
                                      entryTime: closedPosition.entryTime,
                                      idealEntryPrice: closedPosition.idealEntryPrice,
                                      actualEntryPrice: closedPosition.idealEntryPrice,
                                      exitTime: closingTime,
                                      idealExitPrice: closingPrice,
                                      actualExitPrice: closingPrice)
                    trades.append(trade)
                    currentPosition = nil
                case .noAction(_):
                    break
                }
            }
            completion(nil)
        }
    }
    
    func exitPositions(priceBarTime: Date,
                       idealExitPrice: Double,
                       exitReason: ExitMethod,
                       completion: @escaping (Swift.Result<OrderConfirmation?, NetworkError>) -> Void) {
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var errorSoFar: NetworkError?
            var orderConfirmation: OrderConfirmation?
            
            // cancel stop order
            self.deleteAllStopOrders { networkError in
                if let networkError = networkError {
                    errorSoFar = networkError
                }
                semaphore.signal()
            }
            
            semaphore.wait()
            
            // reverse current position
            if let currentPosition = self.currentPosition {
                self.enterAtMarket(priceBarTime: priceBarTime,
                                   direction: currentPosition.direction.reverse(),
                                   size: currentPosition.size)
                { result in
                    switch result {
                    case .success(let exitOrderConfirmation):
                        let trade = Trade(direction: currentPosition.direction,
                                          entryTime: currentPosition.entryTime,
                                          idealEntryPrice: currentPosition.idealEntryPrice,
                                          actualEntryPrice: currentPosition.actualEntryPrice,
                                          entryOrderRef: currentPosition.entryOrderRef,
                                          exitTime: exitOrderConfirmation.time,
                                          idealExitPrice: idealExitPrice,
                                          actualExitPrice: exitOrderConfirmation.price,
                                          exitOrderRef: exitOrderConfirmation.orderRef)
                        self.trades.append(trade)
                        self.currentPosition = nil
                        orderConfirmation = exitOrderConfirmation
                    case .failure(let networkError):
                        errorSoFar = networkError
                    }
                    semaphore.signal()
                }
                
                semaphore.wait()
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }
                
                self.refreshIBSession { result in
                    if let networkError = errorSoFar {
                        completion(.failure(networkError))
                    } else if let orderConfirmation = orderConfirmation {
                        completion(.success(orderConfirmation))
                    } else {
                        completion(.success(nil))
                    }
                }
            }
        }
    }
    
    func getTotalPAndL() -> Double {
        var pAndL: Double = 0
        
        for trade in trades {
            pAndL = pAndL + (trade.actualProfit ?? 0)
        }
        
        return pAndL
    }
    
    func listOfTrades() -> [TradesTableRowItem] {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = Date.DefaultTimeZone
        
        var tradesList: [TradesTableRowItem] = []
        
        if let currentPosition = currentPosition {
            let currentStop: String = currentPosition.stopLoss?.stop != nil ? String(format: "%.3f", currentPosition.stopLoss!.stop) : "--"
            
            tradesList.append(TradesTableRowItem(type: currentPosition.direction.description(),
                                                 iEntry: String(format: "%.3f", currentPosition.idealEntryPrice),
                                                 aEntry: String(format: "%.3f", currentPosition.actualEntryPrice),
                                                 stop: currentStop,
                                                 iExit: "--",
                                                 aExit: "--",
                                                 pAndL: "--",
                                                 entryTime: dateFormatter.string(from: currentPosition.entryTime),
                                                 exitTime: "--"))
        }
        
        for trade in trades.reversed() {
            tradesList.append(TradesTableRowItem(type: trade.direction.description(),
                                                 iEntry: String(format: "%.3f", trade.idealEntryPrice),
                                                 aEntry: String(format: "%.3f", trade.actualEntryPrice),
                                                 stop: "--",
                                                 iExit: String(format: "%.3f", trade.idealExitPrice),
                                                 aExit: String(format: "%.3f", trade.actualExitPrice),
                                                 pAndL: String(format: "%.3f", trade.actualProfit ?? 0),
                                                 entryTime: trade.entryTime != nil ? dateFormatter.string(from: trade.entryTime!) : "--",
                                                 exitTime: dateFormatter.string(from: trade.exitTime)))
        }
        
        return tradesList
    }
    
    private func enterAtMarket(priceBarTime: Date,
                       stop: Double? = nil,
                       direction: TradeDirection,
                       size: Int,
                       completion: @escaping (Swift.Result<OrderConfirmation, NetworkError>) -> Void) {
        
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var errorSoFar: NetworkError?
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
                        if entryOrderConfirmations.count > 1,
                            let entryOrderConfirmation = entryOrderConfirmations.first,
                            let stopOrderConfirmation = entryOrderConfirmations.last {
                            
                            orderId = entryOrderConfirmation.orderId
                            stopOrderId = stopOrderConfirmation.orderId
                        } else {
                           errorSoFar = .noOrderIdReturned
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
                                               size: size) { result in
                    switch result {
                    case .success(let response):
                        if let newOrderId = response.first?.orderId {
                            orderId = newOrderId
                        } else {
                            errorSoFar = .noOrderIdReturned
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
                                                                      stopOrderId: stopOrderId)
                            completion(.success(orderConfirmation))
                        }
                    } else {
                        completion(.failure(.placeOrderFailed))
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    private func deleteAllStopOrders(completion: @escaping (NetworkError?) -> ()) {
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var foundNetworkError: NetworkError?
            for order in self.stopOrders {
                if foundNetworkError != nil {
                    break
                }
                
                self.deleteStopOrder(stopOrderId: String(format: "%d", order.orderId)) { networkError in
                    if let networkError = networkError {
                        foundNetworkError = networkError
                    }
                    semaphore.signal()
                }
                
                semaphore.wait()
            }
            
            DispatchQueue.main.async {
                completion(foundNetworkError)
            }
        }
    }
    
    private func deleteStopOrder(stopOrderId: String, completion: @escaping (NetworkError?) -> ()) {
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
                                 completion: @escaping (NetworkError?) -> ()) {
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
                                      completion: @escaping (Swift.Result<OrderConfirmation, NetworkError>) -> Void) {
        
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var errorSoFar: NetworkError?
            var unclosedIBPosition: IBPosition?
        
            self.networkManager.fetchAccounts { result in
                switch result {
                case .failure(let error):
                    errorSoFar = error
                default:
                    break
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
                        unclosedIBPosition = response
                    }
                case .failure(let error):
                    errorSoFar = error
                }
                semaphore.signal()
            }
            
            semaphore.wait()
            
            if errorSoFar == .positionNotClosed, let unclosedIBPosition = unclosedIBPosition {
                self.exitPositions(priceBarTime: Date(),
                                   idealExitPrice: unclosedIBPosition.mktPrice,
                                   exitReason: .manual)
                { result in
                    switch result {
                    case .success(_):
                        errorSoFar = nil
                    case .failure(let error):
                        errorSoFar = error
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
                        return trade.tradeTime > closedPosition.entryTime &&
                            trade.direction != closedPosition.direction &&
                            trade.size == closedPosition.size &&
                            trade.position == "0"
                        }
                    if let closingTrade = matchingTrades.first, let closingPrice = closingTrade.price.double {
                        let orderConfirmation = OrderConfirmation(price: closingPrice,
                                                                  time: closingTrade.tradeTime,
                                                                  orderRef: closingTrade.orderRef ?? "STOPORDER")
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
    
    @objc private func refreshLiveOrdersTimerFunc() {
        refreshLiveOrders()
    }
}
