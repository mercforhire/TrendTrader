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
    
    private(set) var currentPosition: Position?
    private(set) var trades: [Trade] = []
    
    private var liveOrders: [LiveOrder] = []
    private var ibPosition: IBPosition?
    
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
    
    func resetSession() {
        trades = []
        currentPosition = nil
        liveOrders = []
        ibPosition = nil
    }
    
    func fetchSession(completionHandler: @escaping (Swift.Result<Bool, NetworkError>) -> Void) {
        let fetchingSessionTask = DispatchGroup()
        var fetchError: NetworkError?
        
        fetchingSessionTask.enter()
        networkManager.fetchRelevantLiveOrders { [weak self] result in
            guard let self = self else {
                fetchingSessionTask.leave()
                return
            }
            
            switch result {
            case .success(let response):
                self.liveOrders = response
            case .failure(let error):
                fetchError = error
            }
            fetchingSessionTask.leave()
        }
        
        fetchingSessionTask.enter()
        networkManager.fetchRelevantPositions { [weak self] result in
            guard let self = self else {
                fetchingSessionTask.leave()
                return
            }
            
            switch result {
            case .success(let response):
                self.ibPosition = response
            case .failure(let error):
                fetchError = error
            }
            fetchingSessionTask.leave()
        }
        
        fetchingSessionTask.notify(queue: DispatchQueue.main) {
            if let fetchError = fetchError {
                completionHandler(.failure(fetchError))
            } else {
                completionHandler(.success(true))
            }
        }
    }
    
    func modifyStopLossOrder(liveOrder: LiveOrder, stop: Double, completion: @escaping (NetworkError?) -> ()) {
        networkManager.modifyOrder(orderType: .Stop, direction: liveOrder.direction, price: stop, quantity: liveOrder.remainingQuantity, order: liveOrder) { [weak self] result in
            guard let self = self else {
                return
            }
            
            switch result {
            case .success(let questions):
                self.answerQuestions(questions: questions) { success in
                    if success {
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
    
    func exitPositions(completion: @escaping (Bool) -> ()) {
        let exitPositionsTask = DispatchGroup()
        var networkErrors: [NetworkError] = []
        
        // reverse current positions
        if let ibPosition = self.ibPosition {
            exitPositionsTask.enter()
            
            switch ibPosition.direction {
            case .long:
                self.sellMarket { networkError in
                    if let networkError = networkError {
                        networkErrors.append(networkError)
                    } else {
                        self.ibPosition = nil
                    }
                    
                    exitPositionsTask.leave()
                }
            case .short:
                self.buyMarket { networkError in
                    if let networkError = networkError {
                        networkErrors.append(networkError)
                    } else {
                        self.ibPosition = nil
                    }
                    
                    exitPositionsTask.leave()
                }
            }
        }
        
        // cancel all stop orders
        exitPositionsTask.enter()
        self.deleteAllOrders { networkError in
            if let networkError = networkError {
                networkErrors.append(networkError)
            } else {
                self.liveOrders.removeAll()
            }
            
            exitPositionsTask.leave()
        }
        
        exitPositionsTask.notify(queue: DispatchQueue.main) {
            if networkErrors.isEmpty {
                completion(true)
            } else {
                completion(false)
            }
        }
    }
    
    func buyMarket(completion: @escaping (NetworkError?) -> ()) {
        networkManager.placeOrder(orderType: .Market, direction: .long, time: Date()) { [weak self] result in
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
    
    func sellMarket(completion: @escaping (NetworkError?) -> ()) {
        networkManager.placeOrder(orderType: .Market, direction: .short, time: Date()) { [weak self] result in
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
    
    func answerQuestions(questions: [Question], completion: @escaping (Bool) -> ()) {
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
    
    func deleteAllOrders(completion: @escaping (NetworkError?) -> ()) {
        guard !liveOrders.isEmpty else { return }
        
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var deleteAllOrdersError: NetworkError?
            
            for liveOrder in self.liveOrders {
                if deleteAllOrdersError != nil {
                    semaphore.signal()
                    break
                }
                
                self.networkManager.deleteOrder(order: liveOrder) { result in
                    switch result {
                    case .success(let success):
                        if !success {
                            deleteAllOrdersError = .deleteOrderFailed
                        }
                    case .failure(let error):
                        deleteAllOrdersError = error
                    }
                    
                    semaphore.signal()
                }
                
                semaphore.wait()
            }
            
            DispatchQueue.main.async {
                completion(deleteAllOrdersError)
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
                                           entry: String(format: "%.2f", currentPosition.entryPrice),
                                           stop: String(format: "%.2f", currentPosition.stopLoss.stop),
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
    
    private func generateSession() {
        // Have ongoing trades:
        if let ibPosition = ibPosition {
            let direction: TradeDirection = ibPosition.direction
            let size: Int = abs(ibPosition.position)
            var stopLoss: StopLoss?
            
            // find the Stop Loss
            for order in liveOrders {
                if order.direction != direction, size == order.remainingQuantity, let price = order.price {
                    stopLoss = StopLoss(stop: price, source: .supportResistanceLevel)
                    break
                }
            }
            
            if let stopLoss = stopLoss {
                currentPosition = Position(direction: direction, entryPrice: ibPosition.mktPrice, size: size, stopLoss: stopLoss)
            }
        }
    }
}
