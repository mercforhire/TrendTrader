//
//  NTManager.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-01-11.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation
import Cocoa

protocol NTManagerDelegate: class {
    func connectionStateUpdated(connected: Bool)
}

class NTManager {
    private let maxTryTimes = 3
    private let config = Config.shared
    private let accountId: String
    
    var connected = false {
        didSet {
            if oldValue != connected {
                delegate?.connectionStateUpdated(connected: connected)
            }
        }
    }
    var delegate: NTManagerDelegate?
    
    private var timer: Timer?
    
    init(accountId: String) {
        self.accountId = accountId
    }
    
    func initialize() {
        cleanUp()
        startTimer()
    }
    
    func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(5.0),
                                     target: self,
                                     selector: #selector(refreshStatus),
                                     userInfo: nil,
                                     repeats: true)
    }

    func resetTimer() {
        timer?.invalidate()
        startTimer()
    }
    
    @objc
    func refreshStatus() {
        connected = readConnectionStatusFile()
    }
    
    // PLACE COMMAND
    // PLACE;<ACCOUNT>;<INSTRUMENT>;<ACTION>;<QTY>;<ORDER TYPE>;[LIMIT PRICE];[STOP PRICE];<TIF>;[OCO ID];[ORDER ID];[STRATEGY];[STRATEGY ID]
    func generatePlaceOrder(direction: TradeDirection,
                            size: Int,
                            orderType: OrderType,
                            orderRef: String,
                            completion: ((Swift.Result<OrderConfirmation, TradingError>) -> Void)? = nil) {
        
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
            
            var latestOrderResponse: NTOrderResponse?
            var filledOrderResponse: NTOrderResponse?
            for _ in 0...self.maxTryTimes {
                if let latestOrderResponseFilePath = self.getOrderResponsePaths()?.first,
                    let orderResponse = self.readOrderExecutionFile(filePath: latestOrderResponseFilePath) {
                    
                    latestOrderResponse = orderResponse
                    if orderResponse.status == .filled || orderResponse.status == .accepted {
                        filledOrderResponse = orderResponse
                        break
                    }
                }
                sleep(1)
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
                    self.resetTimer()
                }
            } else if let latestOrderResponse = latestOrderResponse {
                if latestOrderResponse.status == .rejected {
                    DispatchQueue.main.async {
                        completion?(.failure(.orderAlreadyPlaced))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion?(.failure(.orderFailed))
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion?(.failure(.noOrderResponse))
                }
            }
        }
    }
    
    // REVERSEPOSITION COMMAND
    // REVERSEPOSITION;<ACCOUNT>;<INSTRUMENT>;<ACTION>;<QTY>;<ORDER TYPE>;[LIMIT PRICE];[STOP PRICE];<TIF>;[OCO ID];[ORDER ID];[STRATEGY];[STRATEGY ID]
    func reversePositionAndPlaceOrder(direction: TradeDirection,
                                      size: Int,
                                      orderType: OrderType,
                                      orderRef: String,
                                      completion: ((Swift.Result<OrderConfirmation, TradingError>) -> Void)? = nil) {
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
            
            var latestOrderResponse: NTOrderResponse?
            var filledOrderResponse: NTOrderResponse?
            for _ in 0...self.maxTryTimes {
                if let latestOrderResponseFilePath = self.getOrderResponsePaths()?.first,
                    let orderResponse = self.readOrderExecutionFile(filePath: latestOrderResponseFilePath) {
                    latestOrderResponse = orderResponse
                    if orderResponse.status == .filled {
                        filledOrderResponse = orderResponse
                        break
                    }
                }
                sleep(1)
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
                    self.resetTimer()
                }
            } else if let latestOrderResponse = latestOrderResponse {
                if latestOrderResponse.status == .rejected {
                    DispatchQueue.main.async {
                        completion?(.failure(.orderAlreadyPlaced))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion?(.failure(.orderFailed))
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion?(.failure(.noOrderResponse))
                }
            }
        }
    }
    
    // CHANGE COMMAND
    // CHANGE;;;;<QUANTITY>;;<LIMIT PRICE>;<STOP PRICE>;;;<ORDER ID>;;[STRATEGY ID]
    func changeOrder(orderRef: String,
                     size: Int,
                     price: Double,
                     completion: ((Swift.Result<OrderConfirmation, TradingError>) -> Void)? = nil) {
        let orderPrice: Double = price.round(nearest: 0.25)
        let orderString = "CHANGE;;;;\(size);;\(orderPrice);\(orderPrice);;;\(orderRef);;"
        writeTextToFile(text: orderString)
        
        // wait for NT to return with a result file
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            var latestOrderResponse: NTOrderResponse?
            var filledOrderResponse: NTOrderResponse?
            for _ in 0...self.maxTryTimes {
                if let latestOrderResponseFilePath = self.getOrderResponsePaths()?.first,
                    let orderResponse = self.readOrderExecutionFile(filePath: latestOrderResponseFilePath) {
                    latestOrderResponse = orderResponse
                    if orderResponse.status == .filled {
                        filledOrderResponse = orderResponse
                        break
                    }
                }
                sleep(1)
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
                    completion?(.failure(.orderFailed))
                }
            } else {
                DispatchQueue.main.async {
                    completion?(.failure(.noOrderResponse))
                }
            }
        }
    }
    
    // CLOSEPOSITION COMMAND
    // CLOSEPOSITION;<ACCOUNT>;<INSTRUMENT>;;;;;;;;;;
    func closePosition(completion: ((Swift.Result<OrderConfirmation?, TradingError>) -> Void)? = nil) {

        let orderString = "CLOSEPOSITION;\(accountId);\(config.ntTicker);;;;;;;;;;"
        writeTextToFile(text: orderString)
        
        // wait for NT to return with a result file
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            var latestOrderResponse: NTOrderResponse?
            var filledOrderResponse: NTOrderResponse?
            outerLoop: for _ in 0...self.maxTryTimes {
                if let orderResponsePaths = self.getOrderResponsePaths(), !orderResponsePaths.isEmpty {
                    for orderResponsePath in orderResponsePaths {
                        guard let orderResponse = self.readOrderExecutionFile(filePath: orderResponsePath) else { continue }
                        
                        latestOrderResponse = orderResponse
                        if orderResponse.status == .filled {
                            filledOrderResponse = orderResponse
                        }
                    }
                }
                sleep(1)
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
                    self.resetTimer()
                }
            } else if let latestOrderResponse = latestOrderResponse {
                if latestOrderResponse.status == .rejected {
                    DispatchQueue.main.async {
                        completion?(.failure(.orderAlreadyPlaced))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion?(.failure(.orderFailed))
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion?(.failure(.noOrderResponse))
                }
            }
        }
    }
    
    func getLatestFilledOrderResponse() -> NTOrderResponse? {
        if let latestOrderResponseFilePath = self.getOrderResponsePaths()?.first,
            let orderResponse = self.readOrderExecutionFile(filePath: latestOrderResponseFilePath),
            orderResponse.status == .filled {
            return orderResponse
        }
        
        return nil
    }
    
    func readPositionStatusFile() -> PositionStatus? {
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
        
        text = text?.replacingOccurrences(of: "\r\n", with: "")
        var status: PositionStatus?
        if let components = text?.components(separatedBy: ";"),
            components.count == 3,
            let muliplier = components[0] == "LONG" ? 1 : -1,
            let size = components[1].int,
            let avgPrice = components[2].double {
            
            status = PositionStatus(position: muliplier * size, price: avgPrice)
        }
        return status
    }
    
    func cleanUpOrderResponseFiles() {
        guard let paths = getOrderResponsePaths() else { return }

        do {
            for path in paths {
                try FileManager.default.removeItem(atPath: path)
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    var counter = 0
    private func writeTextToFile(text: String) {
        let dir = URL(fileURLWithPath: config.ntBasePath)
        let dir2 = URL(fileURLWithPath: config.ntIncomingPath)
        let fileURL = dir.appendingPathComponent("oif\(counter).txt")
        let fileURL2 = dir2.appendingPathComponent("oif\(counter).txt")
        print(text)
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            try FileManager.default.copyItem(at: fileURL, to: fileURL2)
            try FileManager.default.removeItem(at: fileURL)
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
        
        text = text?.replacingOccurrences(of: "\r\n", with: "")
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
    
    private func readConnectionStatusFile() -> Bool {
        let dir = URL(fileURLWithPath: config.ntOutgoingPath)
        let fileURL = dir.appendingPathComponent("\(config.ntAccountLongName).txt")
        
        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            return text.starts(with: "CONNECTED")
        }
        catch {
            print(fileURL, "doesn't exist")
        }
        
        return false
    }
    
    private func getOrderResponsePaths() -> [String]? {
        do {
            let folderPath = config.ntOutgoingPath
            var fileNames = try FileManager.default.contentsOfDirectory(atPath: folderPath)
            fileNames = fileNames.filter { path -> Bool in
                return path.starts(with: accountId + "_")
            }
            
            if !fileNames.isEmpty {
                var paths: [String] = []
                for file in fileNames {
                    paths.append("\(folderPath)/\(file)")
                }
                return paths
            }
            
        } catch {
        }
        return nil
    }
    
    private func cleanUp() {
        do {
            let folderPath1 = config.ntIncomingPath
            let paths1 = try FileManager.default.contentsOfDirectory(atPath: folderPath1)
            for path in paths1 {
                try FileManager.default.removeItem(atPath: "\(folderPath1)/\(path)")
            }
        } catch {
            print(error.localizedDescription)
        }
    }
}
