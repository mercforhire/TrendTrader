//
//  NinjaTraderManager.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-01-11.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation
import Cocoa

protocol NinjaTraderManagerDelegate: class {
    func positionUpdated(position: Int, averagePrice: Double)
    func connectionStateUpdated(connected: Bool)
}

class NinjaTraderManager {
    private let maxTryTimes = 10
    private let config = Config.shared
    private let accountId: String
    
    var connected = false {
        didSet {
            if oldValue != connected {
                delegate?.connectionStateUpdated(connected: connected)
            }
        }
    }
    var currentPosition: NTPositionUpdate? {
        didSet {
            if let currentPosition = currentPosition {
                delegate?.positionUpdated(position: currentPosition.position, averagePrice: currentPosition.price)
            }
        }
    }
    var delegate: NinjaTraderManagerDelegate?
    
    private var timer: Timer?
    
    init(accountId: String) {
        self.accountId = accountId
    }
    
    func initialize() {
        do {
            let folderPath = config.ntIncomingPath
            let paths = try FileManager.default.contentsOfDirectory(atPath: folderPath)
            for path in paths {
                try FileManager.default.removeItem(atPath: "\(folderPath)/\(path)")
            }
        } catch {
            print(error.localizedDescription)
        }
        
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(1.0),
                                     target: self,
                                     selector: #selector(refreshStatus),
                                     userInfo: nil,
                                     repeats: true)
    }
    
    @objc
    func refreshStatus() {
        connected = readConnectionStatusFile()
        
        if connected, let position = readPositionStatusFile() {
            self.currentPosition = position
        }
    }
    
    // PLACE COMMAND
    // PLACE;<ACCOUNT>;<INSTRUMENT>;<ACTION>;<QTY>;<ORDER TYPE>;[LIMIT PRICE];[STOP PRICE];<TIF>;[OCO ID];[ORDER ID];[STRATEGY];[STRATEGY ID]
    func generatePlaceOrder(direction: TradeDirection,
                            size: Int,
                            orderType: OrderType,
                            orderRef: String,
                            completion: ((Swift.Result<OrderConfirmation, NTError>) -> Void)? = nil) {
        var orderPrice: Double = 0
        switch orderType {
        case .bracket(let price):
            orderPrice = price
        case .limit(let price):
            orderPrice = price
        case .stop(let price):
            orderPrice = price
        default:
            break
        }
        orderPrice = orderPrice.round(nearest: 0.25)
        
        let orderString = "PLACE;\(accountId);\(config.ntTicker);\(direction.tradeString());\(size);\(orderType.ninjaType());\(orderPrice);;GTC;\(orderRef);\(orderRef);;"
        
        // place the order to NT
        writeTextToFile(text: orderString)
        
        // wait for NT to return with a result file
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var latestOrderResponse: NTOrderResponse?
            var filledOrderResponse: NTOrderResponse?
            for _ in 0...10 {
                if let latestOrderResponseFilePath = self.getLatestOrderResponsePath(),
                    let orderResponse = self.readOrderExecutionFile(filePath: latestOrderResponseFilePath) {
                    latestOrderResponse = orderResponse
                    if orderResponse.status == .filled {
                        filledOrderResponse = orderResponse
                        break
                    }
                }
                
                semaphore.signal()
            }
            
            if let orderResponse = filledOrderResponse {
                DispatchQueue.main.async {
                    let orderConfirmation = OrderConfirmation(price: orderResponse.price,
                                                              time: Date(),
                                                              orderId: orderRef,
                                                              orderRef: orderRef,
                                                              stopOrderId: nil,
                                                              commission: self.config.ntCommission)
                    completion?(.success(orderConfirmation))
                }
            } else if let _ = latestOrderResponse {
                DispatchQueue.main.async {
                    completion?(.failure(.placedOrderFailed))
                }
            } else {
                DispatchQueue.main.async {
                    completion?(.failure(.orderResultNotFound))
                }
            }
            semaphore.wait()
            sleep(1)
        }
    }
    
    // REVERSEPOSITION COMMAND
    // REVERSEPOSITION;<ACCOUNT>;<INSTRUMENT>;<ACTION>;<QTY>;<ORDER TYPE>;[LIMIT PRICE];[STOP PRICE];<TIF>;[OCO ID];[ORDER ID];[STRATEGY];[STRATEGY ID]
    func reversePositionAndPlaceOrder(direction: TradeDirection,
                                      size: Int,
                                      orderType: OrderType,
                                      orderRef: String,
                                      completion: ((Swift.Result<OrderConfirmation, NTError>) -> Void)? = nil) {
        var orderPrice: Double = 0
        switch orderType {
        case .bracket(let price):
            orderPrice = price
        case .limit(let price):
            orderPrice = price
        case .stop(let price):
            orderPrice = price
        default:
            break
        }
        orderPrice = orderPrice.round(nearest: 0.25)
        
        let orderString = "REVERSEPOSITION;\(accountId);\(config.ntTicker);\(direction.tradeString());\(size);\(orderType.ninjaType());\(orderPrice);;GTC;\(orderRef);\(orderRef);;"
        writeTextToFile(text: orderString)
        
        // wait for NT to return with a result file
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var latestOrderResponse: NTOrderResponse?
            var filledOrderResponse: NTOrderResponse?
            for _ in 0...self.maxTryTimes {
                if let latestOrderResponseFilePath = self.getLatestOrderResponsePath(),
                    let orderResponse = self.readOrderExecutionFile(filePath: latestOrderResponseFilePath) {
                    latestOrderResponse = orderResponse
                    if orderResponse.status == .filled {
                        filledOrderResponse = orderResponse
                        break
                    }
                }
                
                semaphore.signal()
            }
            
            if let orderResponse = filledOrderResponse {
                DispatchQueue.main.async {
                    let orderConfirmation = OrderConfirmation(price: orderResponse.price,
                                                              time: Date(),
                                                              orderId: orderRef,
                                                              orderRef: orderRef,
                                                              stopOrderId: nil,
                                                              commission: self.config.ntCommission)
                    completion?(.success(orderConfirmation))
                }
            } else if let _ = latestOrderResponse {
                DispatchQueue.main.async {
                    completion?(.failure(.placedOrderFailed))
                }
            } else {
                DispatchQueue.main.async {
                    completion?(.failure(.orderResultNotFound))
                }
            }
            semaphore.wait()
            sleep(1)
        }
    }
    
    // CHANGE COMMAND
    // CHANGE;;;;<QUANTITY>;;<LIMIT PRICE>;<STOP PRICE>;;;<ORDER ID>;;[STRATEGY ID]
    func changeOrder(orderRef: String,
                     size: Int,
                     price: Double,
                     completion: ((Swift.Result<OrderConfirmation, NTError>) -> Void)? = nil) {
        let orderPrice: Double = price.round(nearest: 0.25)
        let orderString = "CHANGE;;;;\(size);;\(orderPrice);\(orderPrice);;;\(orderRef);;"
        writeTextToFile(text: orderString)
        
        // wait for NT to return with a result file
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var latestOrderResponse: NTOrderResponse?
            var filledOrderResponse: NTOrderResponse?
            for _ in 0...self.maxTryTimes {
                if let latestOrderResponseFilePath = self.getLatestOrderResponsePath(),
                    let orderResponse = self.readOrderExecutionFile(filePath: latestOrderResponseFilePath) {
                    latestOrderResponse = orderResponse
                    if orderResponse.status == .filled {
                        filledOrderResponse = orderResponse
                        break
                    }
                }
                
                semaphore.signal()
            }
            
            if let orderResponse = filledOrderResponse {
                DispatchQueue.main.async {
                    let orderConfirmation = OrderConfirmation(price: orderResponse.price,
                                                              time: Date(),
                                                              orderId: orderRef,
                                                              orderRef: orderRef,
                                                              stopOrderId: nil,
                                                              commission: self.config.ntCommission)
                    completion?(.success(orderConfirmation))
                }
            } else if let _ = latestOrderResponse {
                DispatchQueue.main.async {
                    completion?(.failure(.placedOrderFailed))
                }
            } else {
                DispatchQueue.main.async {
                    completion?(.failure(.orderResultNotFound))
                }
            }
            semaphore.wait()
            sleep(1)
        }
    }
    
    // CLOSEPOSITION COMMAND
    // CLOSEPOSITION;<ACCOUNT>;<INSTRUMENT>;;;;;;;;;;
    func closePosition(completion: ((Swift.Result<OrderConfirmation?, NTError>) -> Void)? = nil) {
        if currentPosition?.position == 0 {
            completion?(.success(nil))
            return
        }
        
        let orderString = "CLOSEPOSITION;\(accountId);\(config.ntTicker);;;;;;;;;;"
        writeTextToFile(text: orderString)
        
        // wait for NT to return with a result file
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var latestOrderResponse: NTOrderResponse?
            var filledOrderResponse: NTOrderResponse?
            for _ in 0...self.maxTryTimes {
                if let latestOrderResponseFilePath = self.getLatestOrderResponsePath(),
                    let orderResponse = self.readOrderExecutionFile(filePath: latestOrderResponseFilePath) {
                    latestOrderResponse = orderResponse
                    if orderResponse.status == .filled {
                        filledOrderResponse = orderResponse
                        break
                    }
                }
                
                semaphore.signal()
            }
            
            if let orderResponse = filledOrderResponse {
                DispatchQueue.main.async {
                    let orderConfirmation = OrderConfirmation(price: orderResponse.price,
                                                              time: Date(),
                                                              orderId: "",
                                                              orderRef: "",
                                                              stopOrderId: nil,
                                                              commission: self.config.ntCommission)
                    completion?(.success(orderConfirmation))
                }
            } else if let _ = latestOrderResponse {
                DispatchQueue.main.async {
                    completion?(.failure(.placedOrderFailed))
                }
            } else {
                DispatchQueue.main.async {
                    completion?(.failure(.orderResultNotFound))
                }
            }
            semaphore.wait()
            sleep(1)
        }
    }
    
    func getLatestFilledOrderResponse() -> NTOrderResponse? {
        if let latestOrderResponseFilePath = self.getLatestOrderResponsePath(),
            let orderResponse = self.readOrderExecutionFile(filePath: latestOrderResponseFilePath),
            orderResponse.status == .filled {
            return orderResponse
        }
        
        return nil
    }
    
    var counter = 0
    private func writeTextToFile(text: String) {
        let dir = URL(fileURLWithPath: config.ntIncomingPath)
        let fileURL = dir.appendingPathComponent("oif\(counter).txt")
        print(text)
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            counter += 1
        } catch(let error) {
            print(error)
        }
    }
    
    private func readOrderExecutionFile(filePath: String) -> NTOrderResponse? {
        let fileURL = URL(fileURLWithPath: filePath)
        var text: String?
        do {
            text = try String(contentsOf: fileURL, encoding: .utf8)
            try? FileManager.default.removeItem(at: fileURL)
        }
        catch {
            print(fileURL, "doesn't exist")
            return nil
        }
        
        var orderResponse: NTOrderResponse?
        if let components = text?.components(separatedBy: ";"),
            components.count == 3,
            let orderState = NTOrderStatus(rawValue: components[0]),
            let size = components[1].int,
            let filledPrice = components[2].double {
            orderResponse = NTOrderResponse(status: orderState,
                                            size: size,
                                            price: filledPrice)
        }
        
        return orderResponse
    }
    
    private func readPositionStatusFile() -> NTPositionUpdate? {
        let dir = URL(fileURLWithPath: config.ntOutgoingPath)
        let fileURL = dir.appendingPathComponent("\(config.ntTicker) \(config.ntName)_\(accountId)_position.txt")
        var text: String?
        do {
            text = try String(contentsOf: fileURL, encoding: .utf8)
        }
        catch {
            print(fileURL, "doesn't exist")
            return nil
        }
        
        var positionUpdate: NTPositionUpdate?
        if let components = text?.components(separatedBy: ";"),
            components.count == 3,
            let status = NTPositionStatus(rawValue: components[0]),
            let size = components[1].int,
            let avgPrice = components[2].double {
            positionUpdate = NTPositionUpdate(status: status,
                                              position: size,
                                              price: avgPrice)
        }
        return positionUpdate
    }
    
    private func readConnectionStatusFile() -> Bool {
        let dir = URL(fileURLWithPath: config.ntOutgoingPath)
        let fileURL = dir.appendingPathComponent("\(config.ntAccountLongName).txt")
        
        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            return text == "CONNECTED"
        }
        catch {
            print(fileURL, "doesn't exist")
        }
        
        return false
    }
    
    private func getLatestOrderResponsePath() -> String? {
        do {
            let folderPath = config.ntOutgoingPath
            let paths = try FileManager.default.contentsOfDirectory(atPath: folderPath)
            let orderPaths = paths.filter { path -> Bool in
                return path.starts(with: accountId + "_")
            }
            return orderPaths.first
        } catch {
            print("Error: Latest order response file not found")
        }
        return nil
    }
}
