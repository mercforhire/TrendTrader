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
    
    let live: Bool
    private(set) var currentPosition: Position?
    private(set) var trades: [Trade] = []
    
    private var stopOrder: LiveOrder?
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
    
    init(live: Bool) {
        self.live = live
    }
    
    func resetSession() {
        trades = []
        currentPosition = nil
        stopOrder = nil
        ibPosition = nil
    }
    
    func fetchSession(completionHandler: @escaping (Swift.Result<Bool, NetworkError>) -> Void) {
        guard live else { return }
        
        let fetchingSessionTask = DispatchGroup()
        var fetchError: NetworkError?
        
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
        
        fetchingSessionTask.enter()
        networkManager.fetchStopOrder { [weak self] result in
            guard let self = self else {
                fetchingSessionTask.leave()
                return
            }
            
            switch result {
            case .success(let order):
                self.stopOrder = order
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
    
    func processActions(actions: [TradeActionType], completion: @escaping (NetworkError?) -> ()) {
        if live {
            for action in actions {
                switch action {
                case .openedPosition(let newPosition):
                    openNewPosition(newPosition: newPosition) { [weak self] networkError in
                        guard let self = self else {
                            return
                        }
                        
                        if networkError == nil {
                            self.currentPosition = newPosition
                        }
                        completion(networkError)
                    }
                case .closedPosition(let closedTrade):
                    trades.append(closedTrade)
                    currentPosition = nil
                    syncCurrentPosition()
                case .updatedStop(let newStop):
                    guard let stopOrder = stopOrder else {
                        completion(.modifyOrderFailed)
                        return
                    }
                    
                    modifyStopLossOrder(liveOrder: stopOrder, stop: newStop.stop) { [weak self] networkError in
                        guard let self = self else { return }
                        
                        if networkError == nil {
                            self.currentPosition?.stopLoss = newStop
                        }
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
                case .closedPosition(let closedTrade):
                    trades.append(closedTrade)
                    currentPosition = nil
                case .updatedStop(let newStop):
                    currentPosition?.stopLoss = newStop
                default:
                    break
                }
            }
            completion(nil)
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
                self.stopOrder = nil
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
    
    func openNewPosition(newPosition: Position, completion: @escaping (NetworkError?) -> ()) {
        if newPosition.direction == .long {
            buyMarket(completion: completion)
        } else {
            sellMarket(completion: completion)
        }
    }
    
    func deleteAllOrders(completion: @escaping (NetworkError?) -> ()) {
        guard let stopOrder = stopOrder else { return }
        
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
    
    private func buyMarket(completion: @escaping (NetworkError?) -> ()) {
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
    
    private func sellMarket(completion: @escaping (NetworkError?) -> ()) {
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
    
    private func generateSession() {
        // Have ongoing trades:
        if let ibPosition = ibPosition {
            let direction: TradeDirection = ibPosition.direction
            var stopLoss: StopLoss?
            
            // find the Stop Loss
            if let stopOrder = stopOrder, stopOrder.direction != direction, let price = stopOrder.price {
                stopLoss = StopLoss(stop: price, source: .supportResistanceLevel)
            }
            
            if let stopLoss = stopLoss {
                currentPosition = Position(direction: direction, entryPrice: ibPosition.avgPrice, stopLoss: stopLoss)
            }
        }
    }
    
    private func syncCurrentPosition() {
        var position: Position?
        
        if let ibPosition = ibPosition {
            position = ibPosition.toPosition()
        }
        
        if position != nil, let stopOrder = stopOrder, stopOrder.direction != position!.direction, let stopPrice = stopOrder.price {
            position!.stopLoss = StopLoss(stop: stopPrice, source: .currentBar)
        }
        
        self.currentPosition = position
    }
}
