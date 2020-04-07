//
//  NTManager.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-01-11.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation

protocol NTManagerDelegate: class {
    func connectionStateUpdated(connected: Bool)
}

class NTManager {
    private let maxTryTimes = 10
    
    private let accountName: String
    private let commission: Double
    private let ticker: String
    private let exchange: String
    private let accountLongName: String
    private let basePath: String
    private let incomingPath: String
    private let outgoingPath: String
    
    var connected = false {
        didSet {
            if oldValue != connected {
                delegate?.connectionStateUpdated(connected: connected)
            }
        }
    }
    var delegate: NTManagerDelegate?
    
    private var timer: Timer?
    
    init(accountId: String,
         commission: Double,
         ticker: String,
         exchange: String,
         accountLongName: String,
         basePath: String,
         incomingPath: String,
         outgoingPath: String) {
        
        self.accountName = accountId
        self.commission = commission
        self.ticker = ticker
        self.exchange = exchange
        self.accountLongName = accountLongName
        self.basePath = basePath
        self.incomingPath = incomingPath
        self.outgoingPath = outgoingPath
    }
    
    func initialize() {
        startTimer()
    }
    
    func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(1.0),
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
        
        var orderString: String = ""
        switch orderType {
        case .market:
            orderString = "PLACE;\(accountName);\(ticker);\(direction.tradeString());\(size);\(orderType.ninjaType());;;GTC;\(orderRef);\(orderRef);;"
        case .stop:
            orderString = "PLACE;\(accountName);\(ticker);\(direction.tradeString());\(size);\(orderType.ninjaType());;\(orderPrice);GTC;\(orderRef);\(orderRef);;"
        default:
            orderString = "PLACE;\(accountName);\(ticker);\(direction.tradeString());\(size);\(orderType.ninjaType());\(orderPrice);;GTC;\(orderRef);\(orderRef);;"
        }
        
        // place the order to NT
        writeTextToFile(text: orderString)
        
        // wait for NT to return with a result file
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            var desiredStatus: NTOrderStatus = .filled
            switch orderType {
            case .stop:
                desiredStatus = .accepted
            case .limit:
                desiredStatus = .working
            default:
                desiredStatus = .filled
            }
            
            var latestOrderResponse: OrderResponse?
            var filledOrderResponse: OrderResponse?
            for _ in 0...self.maxTryTimes {
                sleep(1)
                if let orderResponse = self.getOrderResponse(orderId: orderRef) {
                    latestOrderResponse = orderResponse
                    if orderResponse.status == desiredStatus {
                        filledOrderResponse = orderResponse
                        break
                    } else if orderResponse.status == .rejected {
                        break
                    }
                }
            }
            
            if let orderResponse = filledOrderResponse {
                DispatchQueue.main.async {
                    let orderConfirmation = OrderConfirmation(price: orderResponse.price,
                                                              time: orderResponse.time,
                                                              orderId: orderRef,
                                                              orderRef: orderRef,
                                                              stopOrderId: nil,
                                                              commission: self.commission * Double(size))
                    completion?(.success(orderConfirmation))
                    self.resetTimer()
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
        
        let orderString = "REVERSEPOSITION;\(accountName);\(ticker);\(direction.tradeString());\(size);\(orderType.ninjaType());\(orderPrice);;GTC;\(orderRef);\(orderRef);;"
        writeTextToFile(text: orderString)
        
        // wait for NT to return with a result file
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            var desiredStatus: NTOrderStatus = .filled
            switch orderType {
            case .stop, .limit:
                    desiredStatus = .accepted
                default:
                    desiredStatus = .filled
            }
            
            var latestOrderResponse: OrderResponse?
            var filledOrderResponse: OrderResponse?
            for _ in 0...self.maxTryTimes {
                sleep(1)
                if let orderResponse = self.getOrderResponse(orderId: orderRef) {
                    latestOrderResponse = orderResponse
                    if orderResponse.status == desiredStatus {
                        filledOrderResponse = orderResponse
                        break
                    }
                }
            }
            
            if let orderResponse = filledOrderResponse {
                DispatchQueue.main.async {
                    let orderConfirmation = OrderConfirmation(price: orderResponse.price,
                                                              time: orderResponse.time,
                                                              orderId: orderRef,
                                                              orderRef: orderRef,
                                                              stopOrderId: nil,
                                                              commission: self.commission * Double(size))
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
        let orderString = "CHANGE;;;;\(size);;;\(orderPrice);;;\(orderRef);;"
        writeTextToFile(text: orderString)
        
        // wait for NT to return with a result file
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            var latestOrderResponse: OrderResponse?
            var filledOrderResponse: OrderResponse?
            for _ in 0...self.maxTryTimes {
                sleep(1)
                if let orderResponse = self.getOrderResponse(orderId: orderRef) {
                    latestOrderResponse = orderResponse
                    if orderResponse.status == .accepted || orderResponse.status == .changeSubmitted || orderResponse.status == .filled {
                        filledOrderResponse = orderResponse
                        break
                    } else if orderResponse.status == .rejected {
                        DispatchQueue.main.async {
                            completion?(.failure(.orderFailed))
                        }
                        return
                    }
                }
            }
            
            if let orderResponse = filledOrderResponse {
                DispatchQueue.main.async {
                    let orderConfirmation = OrderConfirmation(price: orderResponse.price,
                                                              time: orderResponse.time,
                                                              orderId: orderRef,
                                                              orderRef: orderRef,
                                                              stopOrderId: nil,
                                                              commission: self.commission * Double(size))
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
    
    func cancelAllOrders() {
        let orderString = "CANCELALLORDERS;;;;;;;;;;;;"
        writeTextToFile(text: orderString)
    }
    
    func flatEverything() {
        let orderString = "FLATTENEVERYTHING;;;;;;;;;;;;"
        writeTextToFile(text: orderString)
    }
    
    func getOrderResponse(orderId: String) -> OrderResponse? {
        let path = "\(outgoingPath)/\(accountName)_\(orderId).txt"
        if let orderResponse = self.readOrderExecutionFile(filePath: path) {
            return orderResponse
        }
        return nil
    }
    
    func deleteOrderResponse(orderId: String) -> Bool {
        let path = "\(outgoingPath)/\(accountName)_\(orderId).txt"
        do {
            try FileManager.default.removeItem(atPath: path)
            return true
        } catch {
            print(path, "doesn't exist, already deleted")
            
        }
        return false
    }
    
    func readPositionStatusFile() -> PositionStatus {
        let dir = URL(fileURLWithPath: outgoingPath)
        let fileURL = dir.appendingPathComponent("\(ticker) \(exchange)_\(accountName)_position.txt")
        var text: String?
        do {
            text = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            return PositionStatus(position: 0, price: 0)
        }
        
        text = text?.replacingOccurrences(of: "\r\n", with: "")
        if let components = text?.components(separatedBy: ";"),
            components.count == 3,
            let muliplier = components[0] == "LONG" ? 1 : -1,
            let size = components[1].int,
            let avgPrice = components[2].double {
            
            return PositionStatus(position: muliplier * size, price: avgPrice)
        }
        
        return PositionStatus(position: 0, price: 0)
    }
    
    var counter = 0
    private func writeTextToFile(text: String) {
        let dir = URL(fileURLWithPath: basePath)
        let dir2 = URL(fileURLWithPath: incomingPath)
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
    
    private func readOrderExecutionFile(filePath: String, deleteAfterRead: Bool = false) -> OrderResponse? {
        let fileURL = URL(fileURLWithPath: filePath)
        var text: String?
        do {
            text = try String(contentsOf: fileURL, encoding: .utf8)
            if deleteAfterRead {
                try FileManager.default.removeItem(at: fileURL)
            }
        }
        catch {
            print(fileURL, "doesn't exist")
            return nil
        }
        
        text = text?.replacingOccurrences(of: "\r\n", with: "")
        var orderResponse: OrderResponse?
        if let components = text?.components(separatedBy: ";"),
            components.count == 3,
            let orderState = NTOrderStatus(rawValue: components[0]),
            let size = components[1].int,
            let filledPrice = components[2].double,
            let lastModifiedDate = getLastModifiedDate(url: fileURL) {
            
            orderResponse = OrderResponse(status: orderState,
                                            size: size,
                                            price: filledPrice,
                                            time: lastModifiedDate)
        }
        
        return orderResponse
    }
    
    private func readConnectionStatusFile() -> Bool {
        let dir = URL(fileURLWithPath: outgoingPath)
        let fileURL = dir.appendingPathComponent("\(accountLongName).txt")
        
        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            return text.starts(with: "CONNECTED")
        }
        catch {
//            print(fileURL, "doesn't exist")
        }
        
        return false
    }
    
    private func getLastModifiedDate(url: URL) -> Date? {
        if let attr = try? url.resourceValues(forKeys: [URLResourceKey.contentModificationDateKey]) {
            return attr.contentModificationDate
        }
        
        return nil
    }
}
