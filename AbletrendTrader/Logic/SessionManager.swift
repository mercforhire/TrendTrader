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
    private var ninjaTraderManager: NinjaTraderManager?
    private let liveUpdateFrequency: TimeInterval = 20
    private let live: Bool
    private(set) var currentPosition: Position?
    private(set) var trades: [Trade] = []
    private var liveOrders: [LiveOrder] = []
    private var stopOrders: [LiveOrder] {
        return liveOrders.filter { liveOrder -> Bool in
            return liveOrder.orderType == "Stop" && liveOrder.status == "PreSubmitted"
        }
    }
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
    
    func initialize() {
        switch config.liveTradingMode {
        case .interactiveBroker:
            break
        case .ninjaTrader:
            ninjaTraderManager = NinjaTraderManager(accountId: config.ntAccountName)
            ninjaTraderManager?.initialize()
            ninjaTraderManager?.delegate = self
        }
    }
    
    func startMonitoringLiveOrders() {
        guard config.liveTradingMode == .interactiveBroker else { return }
        
        if monitoringLiveOrders {
            return
        }
        
        monitoringLiveOrders = true
        refreshLiveOrders()
    }
    
    func stopMonitoringLiveOrders() {
        guard config.liveTradingMode == .interactiveBroker else { return }
        
        monitoringLiveOrders = false
    }
    
    func resetSession() {
        stopMonitoringLiveOrders()
        trades = []
        liveOrders = []
        currentPosition = nil
    }
    
    func refreshLiveOrders(completion: ((NetworkError?) -> ())? = nil) {
        guard config.liveTradingMode == .interactiveBroker else { return }
        
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let semaphore = DispatchSemaphore(value: 0)
            
            self.networkManager.fetchAccounts { _ in
                semaphore.signal()
            }
            semaphore.wait()
            
            self.networkManager.fetchLiveOrders { [weak self] result in
                guard let self = self else { return }
                
                DispatchQueue.main.async { [weak self] in
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + self.liveUpdateFrequency) {
                            self.refreshLiveOrders()
                        }
                    }
                }
            }
        }
    }
    
    func refreshIBSession(completionHandler: ((Swift.Result<Bool, NetworkError>) -> Void)?) {
        guard config.liveTradingMode == .interactiveBroker, live else { return }
        
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
    
    func processActionsIB(priceBarTime: Date,
                          actions: [TradeActionType],
                          completion: @escaping (NetworkError?) -> ()) {
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
                
                if retriedTimes >= self.config.maxActionRetryTimes {
                    print("Action have been retried more than", self.config.maxActionRetryTimes, "times, skipping...")
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
                                self.currentPosition = newPosition
                                self.currentPosition?.actualEntryPrice = orderConfirmation.price
                                self.currentPosition?.entryTime = orderConfirmation.time
                                self.currentPosition?.entryOrderRef = orderConfirmation.orderRef
                                self.currentPosition?.stopLoss?.stopOrderId = orderConfirmation.stopOrderId
                                self.currentPosition?.commission = orderConfirmation.commission
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
                                self.currentPosition = newPosition
                                self.currentPosition?.actualEntryPrice = orderConfirmation.price
                                self.currentPosition?.entryTime = orderConfirmation.time
                                self.currentPosition?.entryOrderRef = orderConfirmation.orderRef
                                self.currentPosition?.stopLoss?.stopOrderId = orderConfirmation.stopOrderId
                                self.currentPosition?.commission = orderConfirmation.commission
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
                                    self.currentPosition = nil
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
    
    func processActionsNT(priceBarTime: Date,
                          actions: [TradeActionType],
                          completion: @escaping (NTError?) -> ()) {
        if currentPriceBarTime?.isInSameMinute(date: priceBarTime) ?? false {
            // Actions for this bar already processed
            print(Date().hourMinuteSecond() + ": Actions for " + priceBarTime.hourMinuteSecond() + " already processed")
            return
        }
        currentPriceBarTime = priceBarTime
        
        for action in actions {
            print(action.description(actionBarTime: priceBarTime))
            switch action {
            case .openPosition(let newPosition, _):
                let queue = DispatchQueue.global()
                queue.async { [weak self] in
                    guard let self = self else {
                        return
                    }
                    
                    let semaphore = DispatchSemaphore(value: 0)
                    var errorSoFar: NTError?
                    var orderConfirmation: OrderConfirmation?
                    var stopConfirmation: OrderConfirmation?
                    
                    // Buy/sell order:
                    let orderRef = priceBarTime.generateOrderIdentifier(prefix: newPosition.direction.description(short: true))
                    self.ninjaTraderManager?.generatePlaceOrder(direction: newPosition.direction,
                                                                size: newPosition.size,
                                                                orderType: .market,
                                                                orderRef: orderRef,
                                                                completion:
                    { result in
                        switch result {
                        case .success(let confirmation):
                            orderConfirmation = confirmation
                        case .failure(let ntError):
                            if ntError != .placedOrderRejected {
                                errorSoFar = ntError
                            }
                        }
                        semaphore.signal()
                    })
                    semaphore.wait()
                    
                    if let errorSoFar = errorSoFar {
                        DispatchQueue.main.async {
                            completion(errorSoFar)
                        }
                        return
                    }
                    
                    // Stop order:
                    let stopOrderId = priceBarTime.generateOrderIdentifier(prefix: newPosition.direction.reverse().description(short: true))
                    self.ninjaTraderManager?.generatePlaceOrder(direction: newPosition.direction.reverse(),
                                                           size: newPosition.size,
                                                           orderType: .stop(price: newPosition.stopLoss?.stop ?? 0),
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
                    
                    if let confirmation = orderConfirmation, let _ = stopConfirmation {
                        self.currentPosition = newPosition
                        self.currentPosition?.entryOrderRef = confirmation.orderRef
                        self.currentPosition?.entryTime = confirmation.time
                        self.currentPosition?.actualEntryPrice = confirmation.price
                        self.currentPosition?.commission = confirmation.commission
                        self.currentPosition?.stopLoss?.stopOrderId = stopOrderId
                    }
                    completion(errorSoFar)
                }
            case .reversePosition(let oldPosition, let newPosition, _):
                let queue = DispatchQueue.global()
                queue.async { [weak self] in
                    guard let self = self else {
                        return
                    }
                    
                    let semaphore = DispatchSemaphore(value: 0)
                    var errorSoFar: NTError?
                    var orderConfirmation: OrderConfirmation?
                    var stopConfirmation: OrderConfirmation?
                    
                    // Buy/sell order:
                    let orderRef = priceBarTime.generateOrderIdentifier(prefix: newPosition.direction.description(short: true))
                    self.ninjaTraderManager?.reversePositionAndPlaceOrder(direction: newPosition.direction,
                                                                     size: newPosition.size,
                                                                     orderType: .market,
                                                                     orderRef: orderRef,
                                                                     completion:
                    { result in
                        switch result {
                        case .success(let confirmation):
                            orderConfirmation = confirmation
                        case .failure(let ntError):
                            if ntError != .placedOrderRejected {
                                errorSoFar = ntError
                            }
                        }
                        semaphore.signal()
                    })
                    semaphore.wait()
                    
                    if let errorSoFar = errorSoFar {
                        DispatchQueue.main.async {
                            completion(errorSoFar)
                        }
                        return
                    }
                    
                    // Stop order:
                    let stopOrderId = Date().generateOrderIdentifier(prefix: newPosition.direction.reverse().description(short: true))
                    self.ninjaTraderManager?.generatePlaceOrder(direction: newPosition.direction.reverse(),
                                                                size: newPosition.size,
                                                                orderType: .stop(price: newPosition.stopLoss?.stop ?? 0),
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
                    
                    if let confirmation = orderConfirmation, let _ = stopConfirmation {
                        let trade = Trade(direction: oldPosition.direction,
                                          entryTime: oldPosition.entryTime,
                                          idealEntryPrice: oldPosition.idealEntryPrice,
                                          actualEntryPrice: oldPosition.actualEntryPrice,
                                          exitTime: confirmation.time,
                                          idealExitPrice: newPosition.idealEntryPrice,
                                          actualExitPrice: confirmation.price,
                                          commission: oldPosition.commission + confirmation.commission)
                        self.trades.append(trade)
                        
                        self.currentPosition = newPosition
                        self.currentPosition?.entryOrderRef = confirmation.orderRef
                        self.currentPosition?.entryTime = confirmation.time
                        self.currentPosition?.actualEntryPrice = confirmation.price
                        self.currentPosition?.commission = confirmation.commission
                        self.currentPosition?.stopLoss?.stopOrderId = stopOrderId
                    }
                    completion(errorSoFar)
                }
            case .updateStop(let newStop):
                currentPosition?.stopLoss = newStop
                
                guard let currentPosition = currentPosition, let stopOrderId = newStop.stopOrderId else { continue }
                
                ninjaTraderManager?.changeOrder(orderRef: stopOrderId, size: currentPosition.size, price: newStop.stop, completion:
                { result in
                    switch result {
                    case .success:
                        self.currentPosition?.stopLoss?.stop = newStop.stop
                        completion(nil)
                    case .failure(let error):
                        completion(error)
                    }
                })
            case .forceClosePosition(let closedPosition, let closingPrice, _, _):
                ninjaTraderManager?.closePosition(completion: { [weak self] result in
                    guard let self = self else {
                        return
                    }
                    
                    switch result {
                    case .success(let confirmation):
                        let trade = Trade(direction: closedPosition.direction,
                                          entryTime: closedPosition.entryTime,
                                          idealEntryPrice: closedPosition.idealEntryPrice,
                                          actualEntryPrice: closedPosition.actualEntryPrice,
                                          exitTime: confirmation.time,
                                          idealExitPrice: closingPrice,
                                          actualExitPrice: confirmation.price,
                                          commission: 4.0)
                        self.trades.append(trade)
                        self.currentPosition = nil
                        completion(nil)
                    case .failure(let error):
                        completion(error)
                    }
                })
            case .verifyPositionClosed(let closedPosition, let closingPrice, _, _):
                if let latestFilledOrderResponse = ninjaTraderManager?.getLatestFilledOrderResponse() {
                    let trade = Trade(direction: closedPosition.direction,
                                      entryTime: closedPosition.entryTime,
                                      idealEntryPrice: closedPosition.idealEntryPrice,
                                      actualEntryPrice: closedPosition.idealEntryPrice,
                                      exitTime: Date(),
                                      idealExitPrice: closingPrice,
                                      actualExitPrice: latestFilledOrderResponse.price,
                                      commission: 4.0)
                    trades.append(trade)
                    currentPosition = nil
                    completion(nil)
                } else {
                    completion(.positionNotClosed)
                }
            case .noAction(_):
                break
            }
        }
    }
    
    func processActionsSIM(priceBarTime: Date,
                           actions: [TradeActionType]) {
        if currentPriceBarTime?.isInSameMinute(date: priceBarTime) ?? false {
            // Actions for this bar already processed
            print(Date().hourMinuteSecond() + ": Actions for " + priceBarTime.hourMinuteSecond() + " already processed")
            return
        }
        currentPriceBarTime = priceBarTime
        
        for action in actions {
            print(action.description(actionBarTime: priceBarTime))
            switch action {
            case .openPosition(let newPosition, _):
                currentPosition = newPosition
                currentPosition?.actualEntryPrice = newPosition.idealEntryPrice
            case .reversePosition(let oldPosition, let newPosition, _):
                let trade = Trade(direction: oldPosition.direction,
                                  entryTime: oldPosition.entryTime,
                                  idealEntryPrice: oldPosition.idealEntryPrice,
                                  actualEntryPrice: oldPosition.idealEntryPrice,
                                  exitTime: newPosition.entryTime,
                                  idealExitPrice: newPosition.idealEntryPrice,
                                  actualExitPrice: newPosition.idealEntryPrice,
                                  commission: oldPosition.commission * 2)
                trades.append(trade)
                
                currentPosition = newPosition
                currentPosition?.actualEntryPrice = newPosition.idealEntryPrice
            case .updateStop(let newStop):
                currentPosition?.stopLoss = newStop
                
                guard let currentPosition = currentPosition, let stopOrderId = newStop.stopOrderId else { continue }
                
                ninjaTraderManager?.changeOrder(orderRef: stopOrderId, size: currentPosition.size, price: newStop.stop)
            case .forceClosePosition(let closedPosition, let closingPrice, let closingTime, _):
                let trade = Trade(direction: closedPosition.direction,
                                  entryTime: closedPosition.entryTime,
                                  idealEntryPrice: closedPosition.idealEntryPrice,
                                  actualEntryPrice: closedPosition.idealEntryPrice,
                                  exitTime: closingTime,
                                  idealExitPrice: closingPrice,
                                  actualExitPrice: closingPrice,
                                  commission: closedPosition.commission * 2)
                trades.append(trade)
                currentPosition = nil
            case .verifyPositionClosed(let closedPosition, let closingPrice, let closingTime, _):
                let trade = Trade(direction: closedPosition.direction,
                                  entryTime: closedPosition.entryTime,
                                  idealEntryPrice: closedPosition.idealEntryPrice,
                                  actualEntryPrice: closedPosition.idealEntryPrice,
                                  exitTime: closingTime,
                                  idealExitPrice: closingPrice,
                                  actualExitPrice: closingPrice,
                                  commission: closedPosition.commission * 2)
                trades.append(trade)
                currentPosition = nil
            case .noAction(_):
                break
            }
        }
    }
    
    func exitPositions(priceBarTime: Date,
                       idealExitPrice: Double,
                       exitReason: ExitMethod,
                       completion: @escaping (NetworkError?) -> Void) {
        switch config.liveTradingMode {
        case .interactiveBroker:
            let queue = DispatchQueue.global()
            queue.async { [weak self] in
                guard let self = self else {
                    return
                }
                
                let semaphore = DispatchSemaphore(value: 0)
                var errorSoFar: NetworkError?
                
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
                            if let currentPosition = self.currentPosition {
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
                                self.currentPosition = nil
                            }
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
                        completion(errorSoFar)
                    }
                }
            }
        case .ninjaTrader:
            ninjaTraderManager?.closePosition(completion: { [weak self] result in
                guard let self = self else {
                    return
                }
                switch result {
                case .success(let orderConfirmation):
                    if let currentPosition = self.currentPosition {
                        let trade = Trade(direction: currentPosition.direction,
                                          entryTime: currentPosition.entryTime,
                                          idealEntryPrice: currentPosition.idealEntryPrice,
                                          actualEntryPrice: currentPosition.idealEntryPrice,
                                          exitTime: orderConfirmation.time,
                                          idealExitPrice: idealExitPrice,
                                          actualExitPrice: orderConfirmation.price,
                                          commission: currentPosition.commission + orderConfirmation.commission)
                        self.trades.append(trade)
                        self.currentPosition = nil
                    }
                    completion(nil)
                case .failure:
                    completion(.positionNotClosed)
                }
            })
        }
    }
    
    func getTotalPAndL() -> Double {
        var pAndL: Double = 0
        
        for trade in trades {
            pAndL = pAndL + (trade.actualProfit ?? 0)
        }
        
        return pAndL
    }
    
    func getTotalPAndLDollar() -> Double {
        var pAndLDollar: Double = 0
        
        for trade in trades {
            pAndLDollar = pAndLDollar + (trade.actualProfitDollar ?? 0)
        }
        
        return pAndLDollar
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
                                                 exitTime: "--",
                                                 commission: currentPosition.commission.currency(true, showPlusSign: false)))
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
                                                 exitTime: dateFormatter.string(from: trade.exitTime),
                                                 commission: trade.commission.currency(true)))
        }
        
        return tradesList
    }
    
    // IB only functions:
    
    private func removeStopOrdersAndEnterAtMarket(priceBarTime: Date,
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
                                errorSoFar = .noOrderIdReturned
                            }
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
                                                                      stopOrderId: stopOrderId,
                                                                      commission: recentTrade.commission?.double ?? self.config.defaultCommission)
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
                                      completion: @escaping (Swift.Result<OrderConfirmation?, NetworkError>) -> Void) {
        
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
                                                                  commission: closingTrade.commission?.double ?? self.config.defaultCommission)
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

extension SessionManager: NinjaTraderManagerDelegate {
    func positionUpdated(position: Int, averagePrice: Double) {
        print("Current position:", position, "Avg price:", averagePrice)
    }
    
    func connectionStateUpdated(connected: Bool) {
        
    }
}
