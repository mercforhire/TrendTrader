//
//  NinjaTraderManager.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-01-11.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation
import Cocoa

class NinjaTraderManager {
    private let config = Config.shared
    private let accountId: String
    
    init(accountId: String) {
        self.accountId = accountId
    }
    
    func initialize() {
        do {
            let folderPath = config.ninjaTraderPath
            let paths = try FileManager.default.contentsOfDirectory(atPath: folderPath)
            for path in paths {
                try FileManager.default.removeItem(atPath: "\(folderPath)/\(path)")
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    // PLACE COMMAND
    // PLACE;<ACCOUNT>;<INSTRUMENT>;<ACTION>;<QTY>;<ORDER TYPE>;[LIMIT PRICE];[STOP PRICE];<TIF>;[OCO ID];[ORDER ID];[STRATEGY];[STRATEGY ID]
    func generatePlaceOrder(direction: TradeDirection, size: Int, orderType: OrderType, orderRef: String) {
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
        
        let orderString = "PLACE;\(accountId);\(config.ninjaTraderTicker);\(direction.tradeString());\(size);\(orderType.ninjaType());\(orderPrice);;GTC;\(orderRef);\(orderRef);;"
        writeTextToFile(text: orderString)
    }
    
    // REVERSEPOSITION COMMAND
    // REVERSEPOSITION;<ACCOUNT>;<INSTRUMENT>;<ACTION>;<QTY>;<ORDER TYPE>;[LIMIT PRICE];[STOP PRICE];<TIF>;[OCO ID];[ORDER ID];[STRATEGY];[STRATEGY ID]
    func reversePositionAndPlaceOrder(direction: TradeDirection, size: Int, orderType: OrderType, orderRef: String) {
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
        
        let orderString = "REVERSEPOSITION;\(accountId);\(config.ninjaTraderTicker);\(direction.tradeString());\(size);\(orderType.ninjaType());\(orderPrice);;GTC;\(orderRef);\(orderRef);;"
        writeTextToFile(text: orderString)
    }
    
    // CHANGE COMMAND
    // CHANGE;;;;<QUANTITY>;;<LIMIT PRICE>;<STOP PRICE>;;;<ORDER ID>;;[STRATEGY ID]
    func changeOrder(orderRef: String, size: Int, price: Double) {
        let orderPrice: Double = price.round(nearest: 0.25)
        let orderString = "CHANGE;;;;\(size);;\(orderPrice);\(orderPrice);;;\(orderRef);;"
        writeTextToFile(text: orderString)
    }
    
    // CLOSEPOSITION COMMAND
    // CLOSEPOSITION;<ACCOUNT>;<INSTRUMENT>;;;;;;;;;;
    func closePosition() {
        let orderString = "CLOSEPOSITION;\(accountId);\(config.ninjaTraderTicker);;;;;;;;;;"
        writeTextToFile(text: orderString)
    }
    
    var counter = 0
    private func writeTextToFile(text: String) {
        let dir = URL(fileURLWithPath: config.ninjaTraderPath)
        let fileURL = dir.appendingPathComponent("oif\(counter).txt")
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            counter += 1
        } catch(let error) {
            print(error)
        }
    }
}
