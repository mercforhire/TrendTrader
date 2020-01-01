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
    
    private var liveOrders: [LiveOrder]?
    private var ibPosition: IBPosition?
    private var trades: [IBTrade]?
    
    func resetSession() {
        liveOrders = nil
        ibPosition = nil
        trades = nil
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
        
        fetchingSessionTask.enter()
        networkManager.fetchRelevantTrades { [weak self] result in
            guard let self = self else {
                fetchingSessionTask.leave()
                return
            }
            
            switch result {
            case .success(let response):
                self.trades = response
            case .failure(let error):
                fetchError = error
            }
            fetchingSessionTask.leave()
        }
        
        fetchingSessionTask.notify(queue: DispatchQueue.main) { [weak self] in
            if let fetchError = fetchError {
                completionHandler(.failure(fetchError))
            } else {
                completionHandler(.success(true))
            }
        }
    }
    
    func placeOrder(position: Position, priceBar: PriceBar) {
        var question: Question?
        networkManager.placeOrder(orderType: .Market, direction: .long, source: priceBar) { result in
            switch result {
            case .success(let response):
                question = response.first
            case .failure:
                break
            }
        }
    }
    
    func modifyOrder(liveOrder: LiveOrder, priceBar: PriceBar) {
        networkManager.fetchRelevantLiveOrders { result in
            switch result {
            case .success(let liveOrders):
                if let order = liveOrders.first {
                    self.networkManager.modifyOrder(orderType: .Limit, direction: .long, price: (order.price ?? 0.0) + 1, quantity: 1, order: order) { result in
                        switch result {
                        case .success(let questions):
                            break
                        case .failure:
                            break
                        }
                    }
                }
            case .failure:
                break
            }
        }
    }
    
    private func generateSession() -> Session {
        var session = Session()
        var onGoingTrade: IBTrade?
        
        // Have ongoing trades:
        if let ibPosition = ibPosition, let liveOrders = liveOrders, let trades = trades {
            let direction: TradeDirection = ibPosition.direction
            var entryTime: Date?
            var entryPrice: Double?
            let size: Int = abs(ibPosition.position)
            var stopLoss: StopLoss?
            
            // find the Stop Loss
            for order in liveOrders {
                if order.direction != direction, size == order.remainingQuantity, let price = order.price {
                    stopLoss = StopLoss(stop: price, source: .supportResistanceLevel)
                    break
                }
            }
            
            // find the entry
            for trade in trades {
                if trade.direction == direction, trade.size == size, let price = trade.price.double {
                    entryTime = trade.tradeTime
                    entryPrice = price
                    onGoingTrade = trade
                    break
                }
            }
            
            if let entryTime = entryTime, let entryPrice = entryPrice, let stopLoss = stopLoss {
                session.currentPosition = Position(direction: direction, entryTime: entryTime, entryPrice: entryPrice, size: size, stopLoss: stopLoss)
            }
        }
        
        return session
    }
}
