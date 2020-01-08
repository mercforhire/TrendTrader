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
                        self.currentPosition = ibPosition.toPosition()
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
            
            self.networkManager.fetchStopOrders { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let orders):
                    if let order = orders.first, let stopPrice = order.auxPrice?.double, order.direction != self.currentPositionDirection {
                        self.currentPosition?.stopLoss = StopLoss(stop: stopPrice, source: .currentBar, stopOrderId: String(format: "%d", order.orderId))
                    }
                    DispatchQueue.main.async {
                        completionHandler?(.success(true))
                    }
                case .failure(let error2):
                    DispatchQueue.main.async {
                        completionHandler?(.failure(error2))
                    }
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
//            print(Date().hourMinuteSecond() + ": Actions for " + priceBarId + " already processed")
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
                    case .openedPosition(let newPosition, _):
                        self.openNewPosition(newPosition: newPosition)
                        { result in
                            switch result {
                            case .success(let entryPriceEntryTimeStopOrderId):
                                self.currentPosition = newPosition
                                self.currentPosition?.actualEntryPrice = entryPriceEntryTimeStopOrderId.0
                                self.currentPosition?.entryTime = entryPriceEntryTimeStopOrderId.1
                                self.currentPosition?.stopLoss?.stopOrderId = entryPriceEntryTimeStopOrderId.2
                                completion(nil)
                            case .failure(let networkError):
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
                        
                        self.modifyStopOrder(stopOrderId: stopOrderId, stop: newStop.stop, quantity: size, direction: direction.reverse()) { networkError in
                            if networkError == nil {
                                self.currentPosition?.stopLoss?.stop = newStop.stop
                            }
                            DispatchQueue.main.async {
                                completion(networkError)
                            }
                            semaphore.signal()
                        }
                    case .forceClosePosition(_, let idealExitPrice, _, let reason, let closingChart):
                        self.exitPositions(priceBarTime: priceBarTime,
                                           idealExitPrice: idealExitPrice,
                                           exitReason: reason,
                                           closingChart: closingChart,
                                           completion:
                            { result in
                                switch result {
                                case .success:
                                    completion(nil)
                                case .failure(let networkError):
                                    completion(networkError)
                                }
                                semaphore.signal()
                        })
                    case .verifyPositionClosed(let closedPosition, let idealClosingPrice, let closingTime, let reason, let closingChart):
                        self.verifyClosedPosition(closedPosition: closedPosition, reason: reason) { result in
                            switch result {
                            case .success(let closingPrice):
                                var trade = Trade(direction: closedPosition.direction,
                                                  idealEntryPrice: closedPosition.idealEntryPrice,
                                                  actualEntryPrice: closedPosition.actualEntryPrice ?? closedPosition.idealEntryPrice,
                                                  idealExitPrice: idealClosingPrice,
                                                  actualExitPrice: closingPrice,
                                                  exitMethod: reason,
                                                  entryTime: closedPosition.entryTime,
                                                  exitTime: closingTime)
                                trade.entrySnapshot = closedPosition.entrySnapshot
                                trade.exitSnapshot = closingChart
                                self.trades.append(trade)
                                self.currentPosition = nil
                                DispatchQueue.main.async {
                                    completion(nil)
                                }
                            case .failure(let networkError):
                                DispatchQueue.main.async {
                                    completion(networkError)
                                }
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
                case .openedPosition(let newPosition, _):
                    currentPosition = newPosition
                    currentPosition?.actualEntryPrice = newPosition.idealEntryPrice
                case .updatedStop(let newStop):
                    currentPosition?.stopLoss = newStop
                case .forceClosePosition(let closedPosition, let closingPrice, let closingTime, let reason, let closingChart):
                    var trade = Trade(direction: closedPosition.direction,
                                      idealEntryPrice: closedPosition.idealEntryPrice,
                                      actualEntryPrice: closedPosition.idealEntryPrice,
                                      idealExitPrice: closingPrice,
                                      actualExitPrice: closingPrice,
                                      exitMethod: reason,
                                      entryTime: closedPosition.entryTime,
                                      exitTime: closingTime)
                    trade.entrySnapshot = closedPosition.entrySnapshot
                    trade.exitSnapshot = closingChart
                    trades.append(trade)
                    currentPosition = nil
                case .verifyPositionClosed(let closedPosition, let closingPrice, let closingTime, let reason, let closingChart):
                    var trade = Trade(direction: closedPosition.direction,
                                      idealEntryPrice: closedPosition.idealEntryPrice,
                                      actualEntryPrice: closedPosition.idealEntryPrice,
                                      idealExitPrice: closingPrice,
                                      actualExitPrice: closingPrice,
                                      exitMethod: reason,
                                      entryTime: closedPosition.entryTime,
                                      exitTime: closingTime)
                    trade.entrySnapshot = closedPosition.entrySnapshot
                    trade.exitSnapshot = closingChart
                    trades.append(trade)
                    currentPosition = nil
                default:
                    break
                }
            }
            completion(nil)
        }
    }
    
    func exitPositions(priceBarTime: Date,
                       idealExitPrice: Double,
                       exitReason: ExitMethod,
                       closingChart: Chart?,
                       completion: @escaping (Swift.Result<(Double, Date), NetworkError>) -> Void) {
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var errorSoFar: NetworkError?
            var exitPrice: Double?
            var exitTime: Date?
            // reverse current positions
            if let currentPosition = self.currentPosition {
                self.enterMarket(direction: currentPosition.direction.reverse(),
                                 size: currentPosition.size)
                { result in
                    switch result {
                    case .success(let exitPriceAndDate):
                        var trade = Trade(direction: currentPosition.direction,
                                          idealEntryPrice: currentPosition.idealEntryPrice,
                                          actualEntryPrice: currentPosition.actualEntryPrice ?? currentPosition.idealEntryPrice,
                                          idealExitPrice: idealExitPrice,
                                          actualExitPrice: exitPriceAndDate.0,
                                          exitMethod: exitReason,
                                          entryTime: currentPosition.entryTime,
                                          exitTime: exitPriceAndDate.1)
                        trade.entrySnapshot = currentPosition.entrySnapshot
                        trade.exitSnapshot = closingChart
                        self.trades.append(trade)
                        self.currentPosition = nil
                        exitPrice = exitPriceAndDate.0
                        exitTime = exitPriceAndDate.1
                    case .failure(let networkError):
                        errorSoFar = networkError
                    }
                    semaphore.signal()
                }
                
                semaphore.wait()
            }
            
            // cancel stop order
            self.deleteAllStopOrders { networkError in
                if let networkError = networkError {
                    errorSoFar = networkError
                }
                semaphore.signal()
            }
            
            semaphore.wait()
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }
                
                self.refreshIBSession { result in
                    if let networkError = errorSoFar {
                        completion(.failure(networkError))
                    } else if let exitPrice = exitPrice, let exitTime = exitTime {
                        completion(.success((exitPrice, exitTime)))
                    }
                }
            }
        }
    }
    
    func openNewPosition(newPosition: Position,
                         completion: @escaping (Swift.Result<(Double, Date, String?), NetworkError>) -> Void) {
        
        enterMarket(direction: newPosition.direction,
                    size: config.positionSize,
                    completion:
            { result in
                switch result {
                case .success(let entryPriceAndDate):
                    if let stopLoss = newPosition.stopLoss {
                        self.placeStopOrder(direction: newPosition.direction.reverse(),
                                            stopPrice: stopLoss.stop,
                                            size: newPosition.size)
                        { result in
                            switch result {
                            case .success(let orderId):
                                completion(.success((entryPriceAndDate.0, entryPriceAndDate.1, orderId)))
                            case .failure(let networkError2):
                                completion(.failure(networkError2))
                            }
                        }
                    } else {
                        completion(.success((entryPriceAndDate.0, entryPriceAndDate.1, nil)))
                    }
                case .failure(let networkError):
                    completion(.failure(networkError))
                }
        })
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
            let currentStop: String = currentPosition.stopLoss?.stop != nil ? String(format: "%.2f", currentPosition.stopLoss!.stop) : "--"
            
            tradesList.append(TradesTableRowItem(type: currentPosition.direction.description(),
                                                 iEntry: String(format: "%.2f", currentPosition.idealEntryPrice),
                                                 aEntry: String(format: "%.2f", currentPosition.actualEntryPrice ?? -1.0),
                                                 stop: currentStop,
                                                 iExit: "--",
                                                 aExit: "--",
                                                 pAndL: "--",
                                                 entryTime: dateFormatter.string(from: currentPosition.entryTime),
                                                 exitTime: "--"))
        }
        
        for trade in trades.reversed() {
            tradesList.append(TradesTableRowItem(type: trade.direction.description(),
                                                 iEntry: String(format: "%.2f", trade.idealEntryPrice),
                                                 aEntry: String(format: "%.2f", trade.actualEntryPrice),
                                                 stop: "--",
                                                 iExit: String(format: "%.2f", trade.idealExitPrice),
                                                 aExit: String(format: "%.2f", trade.actualExitPrice),
                                                 pAndL: String(format: "%.2f", trade.actualProfit ?? 0),
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
    
    private func enterMarket(direction: TradeDirection,
                             size: Int,
                             completion: @escaping (Swift.Result<(Double, Date), NetworkError>) -> Void) {
        
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var errorSoFar: NetworkError?
            
            self.networkManager.placeOrder(orderType: .market,
                                           direction: direction,
                                           size: size) { result in
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
            
            self.networkManager.fetchTrades { result in
                switch result {
                case .success(let trades):
                    let matchingTrades = trades.filter { trade -> Bool in
                        return trade.tradeTime.timeIntervalSinceNow < 0 &&
                        trade.direction == direction &&
                            trade.size == size
                        }
                    if let recentTrade = matchingTrades.first, let actualPrice = recentTrade.price.double {
                        DispatchQueue.main.async {
                            completion(.success((actualPrice, recentTrade.tradeTime)))
                        }
                    } else {
                        completion(.failure(.fetchTradesFailed))
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    private func placeStopOrder(direction: TradeDirection,
                                stopPrice: Double,
                                size: Int,
                                completion: @escaping (Swift.Result<String, NetworkError>) -> Void) {
        networkManager.placeOrder(orderType: .stop(price: stopPrice), direction: direction, size: size) { result in
            switch result {
            case .success(let response):
                completion(.success(response.orderId))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func modifyStopOrder(stopOrderId: String, stop: Double, quantity: Int, direction: TradeDirection, completion: @escaping (NetworkError?) -> ()) {
        networkManager.modifyOrder(orderType: .stop(price: stop), direction: direction, price: stop, quantity: quantity, orderId: stopOrderId) { result in
            
            switch result {
            case .success:
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        }
    }
    
    private func verifyClosedPosition(closedPosition: Position, reason: ExitMethod, completion: @escaping (Swift.Result<Double, NetworkError>) -> Void) {
        
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
                        DispatchQueue.main.async {
                            completion(.success(closingPrice))
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
