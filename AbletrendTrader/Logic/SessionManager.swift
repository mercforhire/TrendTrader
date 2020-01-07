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
    
    let live: Bool
    private(set) var currentPosition: Position?
    private(set) var trades: [Trade] = []
    
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
    
    init(live: Bool) {
        self.live = live
    }
    
    func resetSession() {
        trades = []
        currentPosition = nil
    }
    
    func refreshIBSession(completionHandler: ((Swift.Result<Bool, NetworkError>) -> Void)? ) {
        guard live else { return }
        
        networkManager.fetchRelevantPositions { [weak self] result in
            guard let self = self else {
                return
            }
            
            switch result {
            case .success(let response):
                if let ibPosition = response {
                    self.currentPosition = ibPosition.toPosition()
                    self.networkManager.fetchStopOrder { [weak self] result in
                        guard let self = self else {
                            return
                        }
                        
                        switch result {
                        case .success(let order):
                            if let order = order, let stopPrice = order.price {
                                self.currentPosition?.stopLoss = StopLoss(stop: stopPrice, source: .currentBar, stopOrder: order)
                            }
                            completionHandler?(.success(true))
                        case .failure(let error2):
                            completionHandler?(.failure(error2))
                        }
                    }
                } else {
                    self.currentPosition = nil
                    completionHandler?(.success(true))
                }
            case .failure(let error):
                completionHandler?(.failure(error))
            }
        }
    }
    
    func processActions(actions: [TradeActionType], completion: @escaping (NetworkError?) -> ()) {
        if live {
            for action in actions {
                switch action {
                case .openedPosition(let newPosition):
                    openNewPosition(newPosition: newPosition) { networkError in
                        completion(networkError)
                    }
                case .updatedStop(let newStop):
                    guard let stopOrder = currentPosition?.stopLoss?.stopOrder else {
                        completion(.modifyOrderFailed)
                        return
                    }
                    
                    modifyStopOrder(liveOrder: stopOrder, stop: newStop.stop) { networkError in
                        completion(networkError)
                    }
                case .forceClosePosition(_, _, _, _):
                    exitPositions { networkErrors in
                        completion(networkErrors.first)
                    }
                case .verifyPositionClosed(_, _, _, let reason):
                    verifyClosedPosition(reason: reason) { networkError in
                        completion(networkError)
                    }
                default:
                    break
                }
            }
        } else {
            for action in actions {
                switch action {
                case .openedPosition(let newPosition):
                    currentPosition = newPosition
                    currentPosition?.actualEntryPrice = newPosition.idealEntryPrice
                case .updatedStop(let newStop):
                    currentPosition?.stopLoss = newStop
                case .forceClosePosition(let closedPosition, let closingPrice, let closingTime, let reason):
                    let trade = Trade(direction: closedPosition.direction, entryPrice: closedPosition.idealEntryPrice, exitPrice: closingPrice, exitMethod: reason, entryTime: closedPosition.entryTime, exitTime: closingTime)
                    trades.append(trade)
                    currentPosition = nil
                case .verifyPositionClosed(let closedPosition, let closingPrice, let closingTime, let reason):
                    let trade = Trade(direction: closedPosition.direction, entryPrice: closedPosition.idealEntryPrice, exitPrice: closingPrice, exitMethod: reason, entryTime: closedPosition.entryTime, exitTime: closingTime)
                    trades.append(trade)
                    currentPosition = nil
                default:
                    break
                }
            }
            completion(nil)
        }
    }
    
    func exitPositions(completion: @escaping ([NetworkError]) -> ()) {
        let exitPositionsTask = DispatchGroup()
        var networkErrors: [NetworkError] = []
        
        // reverse current positions
        if let currentPosition = currentPosition {
            exitPositionsTask.enter()
            
            switch currentPosition.direction {
            case .long:
                self.sellMarket(size: currentPosition.size) { networkError in
                    if let networkError = networkError {
                        networkErrors.append(networkError)
                    }
                    
                    exitPositionsTask.leave()
                }
            case .short:
                self.buyMarket(size: currentPosition.size) { networkError in
                    if let networkError = networkError {
                        networkErrors.append(networkError)
                    }
                    
                    exitPositionsTask.leave()
                }
            }
        }
        
        if currentPosition?.stopLoss?.stopOrder != nil {
            // cancel all stop orders
            exitPositionsTask.enter()
            self.deleteStopOrder { networkError in
                if let networkError = networkError {
                    networkErrors.append(networkError)
                }
                
                exitPositionsTask.leave()
            }
        }
        
        exitPositionsTask.notify(queue: DispatchQueue.main) {
            self.refreshIBSession { result in
                switch result {
                case .failure(let error):
                    networkErrors.append(error)
                default:
                    break
                }
                
                completion(networkErrors)
            }
        }
    }
    
    func openNewPosition(newPosition: Position, completion: @escaping (NetworkError?) -> ()) {
        let handler: (NetworkError?) -> () = { networkError in
            if networkError == nil {
                self.currentPosition = newPosition
                self.currentPosition?.stopLoss = nil
                
                if let entryTime = newPosition.entryTime, let stopLoss = newPosition.stopLoss {
                    self.placeStopOrder(direction: newPosition.direction.reverse(), stop: stopLoss.stop, time: entryTime) { networkError2 in
                        if networkError2 == nil {
                            self.currentPosition?.stopLoss = stopLoss
                            completion(nil)
                        } else {
                            completion(networkError2)
                        }
                    }
                } else {
                    completion(nil)
                }
            } else {
                completion(networkError)
            }
        }
        
        if newPosition.direction == .long {
            buyMarket(size: config.positionSize , completion: handler)
        } else {
            sellMarket(size: config.positionSize, completion: handler)
        }
    }
    
    func deleteStopOrder(completion: @escaping (NetworkError?) -> ()) {
        guard let stopOrder = currentPosition?.stopLoss?.stopOrder else { return }
        
        self.networkManager.deleteOrder(order: stopOrder) { result in
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
    
    func getTotalPAndL() -> Double {
        var pAndL: Double = 0
        
        for trade in trades {
            pAndL = pAndL + (trade.profit ?? 0)
        }
        
        return pAndL
    }
    
    func listOfTrades() -> [TradesTableRowItem] {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = Date.DefaultTimeZone
        
        var tradesList: [TradesTableRowItem] = []
        
        if let currentPosition = currentPosition {
            tradesList.append(TradesTableRowItem(type: currentPosition.direction.description(),
                                                 entry: String(format: "%.2f", currentPosition.actualEntryPrice ?? currentPosition.idealEntryPrice),
                                           stop: String(format: "%.2f", currentPosition.stopLoss?.stop ?? -1),
                                           exit: "--",
                                           pAndL: "--",
                                           entryTime: currentPosition.entryTime != nil ? dateFormatter.string(from: currentPosition.entryTime!) : "--",
                                           exitTime: "--"))
        }
        
        for trade in trades.reversed() {
            tradesList.append(TradesTableRowItem(type: trade.direction.description(),
                                           entry: String(format: "%.2f", trade.entryPrice),
                                           stop: "--",
                                           exit: String(format: "%.2f", trade.exitPrice),
                                           pAndL: String(format: "%.2f", trade.profit ?? 0),
                                           entryTime: trade.entryTime != nil ? dateFormatter.string(from: trade.entryTime!) : "--",
                                           exitTime: dateFormatter.string(from: trade.exitTime)))
        }
        
        return tradesList
    }
    
    private func buyMarket(size: Int, completion: @escaping (NetworkError?) -> ()) {
        networkManager.placeOrder(orderType: .market, direction: .long, size: size, time: Date()) { [weak self] result in
            guard let self = self else {
                return
            }
            
            switch result {
            case .success(let questions):
                self.answerQuestions(questions: questions) { success in
                    if success {
                        completion(nil)
                    } else {
                        completion(.placeOrderFailed)
                    }
                }
            case .failure(let error):
                completion(error)
            }
        }
    }
    
    private func sellMarket(size: Int, completion: @escaping (NetworkError?) -> ()) {
        networkManager.placeOrder(orderType: .market, direction: .short, size: size, time: Date()) { [weak self] result in
            guard let self = self else {
                return
            }
            
            switch result {
            case .success(let questions):
                self.answerQuestions(questions: questions) { success in
                    if success {
                        completion(nil)
                    } else {
                        completion(.placeOrderFailed)
                    }
                }
            case .failure(let error):
                completion(error)
            }
        }
    }
    
    private func answerQuestions(questions: [Question], completion: @escaping (Bool) -> ()) {
        guard !questions.isEmpty else { return }
        
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var placeOrderReplyError = false
            
            for question in questions {
                if placeOrderReplyError {
                    semaphore.signal()
                    break
                }
                
                self.networkManager.placeOrderReply(question: question, answer: true) { result in
                    switch result {
                    case .success(let success):
                        placeOrderReplyError = !success
                    case .failure:
                        placeOrderReplyError = true
                    }
                    semaphore.signal()
                }
                
                semaphore.wait()
            }
            
            DispatchQueue.main.async {
                completion(!placeOrderReplyError)
            }
        }
    }
    
    private func placeStopOrder(direction: TradeDirection, stop: Double, time: Date, completion: @escaping (NetworkError?) -> ()) {
        guard let currentPosition = currentPosition else {
            completion(.noCurrentPositionToPlaceStopLoss)
            return
        }
        
        networkManager.placeOrder(orderType: .stop(price: stop), direction: direction, size: currentPosition.size, time: time) { [weak self] result in
            guard let self = self else {
                return
            }
            
            switch result {
            case .success(let questions):
                self.answerQuestions(questions: questions) { success in
                    if success {
                        completion(nil)
                    } else {
                        completion(.placeOrderFailed)
                    }
                }
            case .failure(let error):
                completion(error)
            }
        }
    }
    
    private func modifyStopOrder(liveOrder: LiveOrder, stop: Double, completion: @escaping (NetworkError?) -> ()) {
        networkManager.modifyOrder(orderType: .stop(price: stop), direction: liveOrder.direction, price: stop, quantity: liveOrder.remainingQuantity, order: liveOrder) { [weak self] result in
            guard let self = self else {
                return
            }
            
            switch result {
            case .success(let questions):
                self.answerQuestions(questions: questions) { success in
                    if success {
                        self.currentPosition?.stopLoss?.stop = stop
                        completion(nil)
                    } else {
                        completion(.modifyOrderFailed)
                    }
                }
            case .failure(let error):
                completion(error)
            }
        }
    }
    
    private func verifyClosedPosition(reason: ExitMethod, completion: @escaping (NetworkError?) -> ()) {
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var verifyClosedPositionError: NetworkError?
            
            self.networkManager.fetchRelevantPositions { [weak self] result in
                guard let _ = self else {
                    semaphore.signal()
                    return
                }
                
                switch result {
                case .success(let response):
                    if response != nil {
                        verifyClosedPositionError = .positionNotClosed
                    }
                case .failure(let error):
                    verifyClosedPositionError = error
                }
                
                semaphore.signal()
            }
            
            semaphore.wait()
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }
                
                if verifyClosedPositionError != nil {
                    completion(verifyClosedPositionError)
                    return
                }
                
                self.networkManager.fetchLatestTrade(completionHandler: { [weak self] result in
                    guard let self = self else {
                        return
                    }
                    
                    switch result {
                    case .success(let latestIBTrade):
                        if let currentPosition = self.currentPosition,
                            let entryPrice = currentPosition.actualEntryPrice,
                            let ibTrade = latestIBTrade, ibTrade.direction == currentPosition.direction.reverse(), ibTrade.position == 0,
                            let exitPrice = ibTrade.price.double {
                            
                            let justClosedTrade = Trade(direction: currentPosition.direction, entryPrice: entryPrice, exitPrice: exitPrice, exitMethod: reason, entryTime: currentPosition.entryTime, exitTime: ibTrade.tradeTime)
                            self.trades.append(justClosedTrade)
                            self.currentPosition = nil
                        } else {
                            verifyClosedPositionError = .verifyClosedPositionFailed
                        }
                    case .failure(let error):
                        verifyClosedPositionError = error
                    }
                    
                    completion(verifyClosedPositionError)
                })
            }
        }
    }
}
