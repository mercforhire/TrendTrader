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
        
        networkManager.fetchAccounts { [weak self] result in
            guard let self = self else {
                return
            }
            
            self.networkManager.fetchRelevantPositions { [weak self] result in
                guard let self = self else {
                    return
                }
                
                switch result {
                case .success(let response):
                    if let ibPosition = response {
                        self.currentPosition = ibPosition.toPosition()
                        self.networkManager.fetchStopOrders { [weak self] result in
                            guard let self = self else {
                                return
                            }
                            
                            switch result {
                            case .success(let orders):
                                if let order = orders.first, let stopPrice = order.auxPrice?.double {
                                    self.currentPosition?.stopLoss = StopLoss(stop: stopPrice, source: .currentBar, stopOrderId: String(format: "%d", order.orderId))
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
    }
    
    var currentlyProcessingPriceBar: String?
    
    func resetCurrentlyProcessingPriceBar() {
        currentlyProcessingPriceBar = nil
    }
    
    func processActions(priceBarId: String, priceBarTime: Date, actions: [TradeActionType], completion: @escaping (NetworkError?) -> ()) {
        if currentlyProcessingPriceBar == priceBarId {
            // Actions for this bar already processed
            return
        }
        
        currentlyProcessingPriceBar = priceBarId
        for action in actions {
            print(action.description(actionBarTime: priceBarTime))
        }
        
        if live {
            let queue = DispatchQueue.global()
            queue.async { [weak self] in
                guard let self = self else {
                    return
                }
                let semaphore = DispatchSemaphore(value: 0)
                for action in actions {
                    switch action {
                    case .openedPosition(let newPosition):
                        self.openNewPosition(newPosition: newPosition) { networkError in
                            DispatchQueue.main.async {
                                completion(networkError)
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
                            semaphore.signal()
                            return
                        }
                        
                        self.modifyStopOrder(stopOrderId: stopOrderId, stop: newStop.stop, quantity: size, direction: direction) { networkError in
                            DispatchQueue.main.async {
                                completion(networkError)
                            }
                            semaphore.signal()
                        }
                    case .forceClosePosition(_, _, _, _):
                        self.exitPositions { networkErrors in
                            DispatchQueue.main.async {
                                completion(networkErrors.first)
                            }
                            semaphore.signal()
                        }
                    case .verifyPositionClosed(_, _, _, let reason):
                        self.verifyClosedPosition(reason: reason) { networkError in
                            DispatchQueue.main.async {
                                completion(networkError)
                            }
                            semaphore.signal()
                        }
                    default:
                        semaphore.signal()
                    }
                    
                    semaphore.wait()
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
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var networkErrors: [NetworkError] = []
            
            // reverse current positions
            if let currentPosition = self.currentPosition {
                switch currentPosition.direction {
                case .long:
                    self.sellMarket(size: currentPosition.size) { networkError in
                        if let networkError = networkError {
                            networkErrors.append(networkError)
                        }
                        semaphore.signal()
                    }
                case .short:
                    self.buyMarket(size: currentPosition.size) { networkError in
                        if let networkError = networkError {
                            networkErrors.append(networkError)
                        }
                        semaphore.signal()
                    }
                }
                semaphore.wait()
            }
            
            // cancel stop order
            self.deleteAllStopOrders { networkError in
                if let networkError = networkError {
                    networkErrors.append(networkError)
                } else {
                    self.currentPosition?.stopLoss = nil
                }
                semaphore.signal()
            }
            
            semaphore.wait()
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }
                
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
    }
    
    func openNewPosition(newPosition: Position, completion: @escaping (NetworkError?) -> ()) {
        let handler: (NetworkError?) -> () = { networkError in
            if networkError == nil {
                self.currentPosition = newPosition
                self.currentPosition?.stopLoss = nil
                if let entryTime = newPosition.entryTime, let stopLoss = newPosition.stopLoss {
                    self.placeStopOrder(direction: newPosition.direction.reverse(),
                                        newStop: stopLoss,
                                        time: entryTime)
                    { networkError2 in
                        completion(networkError2)
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
    
    func deleteAllStopOrders(completion: @escaping (NetworkError?) -> ()) {
        networkManager.fetchStopOrders { [weak self] result in
            guard let self = self else {
                return
            }
            
            switch result {
            case .success(let orders):
                let queue = DispatchQueue.global()
                queue.async { [weak self] in
                    guard let self = self else {
                        return
                    }
                    
                    let semaphore = DispatchSemaphore(value: 0)
                    var foundNetworkError: NetworkError?
                    for order in orders {
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
            case .failure(let networkError):
                completion(networkError)
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
            let currentStop: String = currentPosition.stopLoss?.stop != nil ? String(format: "%.2f", currentPosition.stopLoss!.stop) : "--"
            
            tradesList.append(TradesTableRowItem(type: currentPosition.direction.description(),
                                                 entry: String(format: "%.2f", currentPosition.actualEntryPrice ?? currentPosition.idealEntryPrice),
                                           stop: currentStop,
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
    
    private func deleteStopOrder(stopOrderId: String, completion: @escaping (NetworkError?) -> ()) {
        self.networkManager.deleteOrder(orderId: stopOrderId) { result in
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
    
    private func buyMarket(size: Int, completion: @escaping (NetworkError?) -> ()) {
        networkManager.placeOrder(orderType: .market, direction: .long, size: size, time: Date()) { result in
            switch result {
            case .success:
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        }
    }
    
    private func sellMarket(size: Int, completion: @escaping (NetworkError?) -> ()) {
        networkManager.placeOrder(orderType: .market, direction: .short, size: size, time: Date()) { result in
            switch result {
            case .success:
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        }
    }
    
    private func placeStopOrder(direction: TradeDirection, newStop: StopLoss, time: Date, completion: @escaping (NetworkError?) -> ()) {
        guard let currentPosition = currentPosition else {
            completion(.noCurrentPositionToPlaceStopLoss)
            return
        }
        
        networkManager.placeOrder(orderType: .stop(price: newStop.stop), direction: direction, size: currentPosition.size, time: time) { [weak self] result in
            guard let self = self else {
                return
            }
            
            switch result {
            case .success(let response):
                self.currentPosition?.stopLoss = newStop
                self.currentPosition?.stopLoss?.stopOrderId = response.orderId
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        }
    }
    
    private func modifyStopOrder(stopOrderId: String, stop: Double, quantity: Int, direction: TradeDirection, completion: @escaping (NetworkError?) -> ()) {
        networkManager.modifyOrder(orderType: .stop(price: stop), direction: direction, price: stop, quantity: quantity, orderId: stopOrderId) { [weak self] result in
            guard let self = self else {
                return
            }
            
            switch result {
            case .success:
                self.currentPosition?.stopLoss?.stop = stop
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        }
    }
    
    private func verifyClosedPosition(reason: ExitMethod, completion: @escaping (NetworkError?) -> ()) {
        networkManager.fetchAccounts { [weak self] result in
            guard let self = self else {
                return
            }
            
            self.networkManager.fetchRelevantPositions { [weak self] result in
                guard let _ = self else {
                    return
                }
                
                switch result {
                case .success(let response):
                    if response != nil {
                        completion(.positionNotClosed)
                    } else {
                        completion(nil)
                    }
                case .failure(let error):
                    completion(error)
                }
            }
        }
    }
}
