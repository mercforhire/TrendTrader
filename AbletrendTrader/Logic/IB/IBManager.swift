//
//  NetworkManager.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-28.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation
import Alamofire

class IBManager {
    static let shared = IBManager()
    
    private let afManager: Alamofire.SessionManager
    private let config = Config.shared
    private let ssoTokenBuilder: SSOTokenBuilder = SSOTokenBuilder()
    private let authStatusBuilder: AuthStatusBuilder = AuthStatusBuilder()
    private let accountsBuilder: AccountsBuilder = AccountsBuilder()
    private let ibTradesBuilder: IBTradesBuilder = IBTradesBuilder()
    private let liveOrdersResponseBuilder: LiveOrdersResponseBuilder = LiveOrdersResponseBuilder()
    private let orderQuestionsBuilder: OrderQuestionsBuilder = OrderQuestionsBuilder()
    private let errorResponseBuilder: ErrorResponseBuilder = ErrorResponseBuilder()
    private let ibPositionsBuilder: IBPositionsBuilder = IBPositionsBuilder()
    private let placedOrderResponseBuilder: PlacedOrderResponseBuilder = PlacedOrderResponseBuilder()
    
    var selectedAccount: Account?
    
    init() {
        afManager = Alamofire.SessionManager.default
        afManager.session.configuration.timeoutIntervalForRequest = 20
        afManager.delegate.sessionDidReceiveChallenge = { session, challenge in
            var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
            var credential: URLCredential?
            
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust, let trust = challenge.protectionSpace.serverTrust {
                disposition = URLSession.AuthChallengeDisposition.useCredential
                credential = URLCredential(trust: trust)
            } else {
                if challenge.previousFailureCount > 0 {
                    disposition = .cancelAuthenticationChallenge
                } else {
                    credential = self.afManager.session.configuration.urlCredentialStorage?.defaultCredential(for: challenge.protectionSpace)
                    if credential != nil {
                        disposition = .useCredential
                    }
                }
            }
            
            return (disposition, credential)
        }
    }
    
    // Validate SSO
    func validateSSO(completion: @escaping (SSOToken?) -> Void) {
        afManager.request("https://localhost:5000/v1/portal/sso/validate").responseData { [weak self] response in
            guard let self = self else { return }
            
            if let data = response.data, let ssoToken = self.ssoTokenBuilder.buildSSOTokenFrom(data) {
                completion(ssoToken)
            } else {
                completion(nil)
            }
        }
    }
    
    // Authentication Status
    func fetchAuthenticationStatus(completion: @escaping (AuthStatus?) -> Void) {
        afManager.request("https://localhost:5000/v1/portal/iserver/auth/status", method: .post).responseData { [weak self] response in
            guard let self = self else { return }
            
            if let data = response.data, let authStatus = self.authStatusBuilder.buildAuthStatusFrom(data) {
                completion(authStatus)
            } else {
                completion(nil)
            }
        }
    }
    
    // Tries to re-authenticate to Brokerage
    func reauthenticate(completion: @escaping (Bool) -> Void) {
        afManager.request("https://localhost:5000/v1/portal/iserver/reauthenticate", method: .post).responseData { response in
            
            if response.response?.statusCode == 200 {
                completion(true)
            } else {
                completion(false)
            }
        }
    }
    
    // Ping the server to keep the session open
    func pingServer(completion: @escaping (Bool) -> Void) {
        afManager.request("https://localhost:5000/v1/portal/tickle", method: .post).responseJSON { response in
            if response.response?.statusCode == 200 {
                completion(true)
            } else {
                completion(false)
            }
        }
    }
    
    // Portfolio Accounts
    func fetchAccounts(completion: @escaping ([Account]?) -> Void) {
        afManager.request("https://localhost:5000/v1/portal/portfolio/accounts").responseData
            { [weak self] response in
                guard let self = self else { return }
                
                if let data = response.data, let accounts = self.accountsBuilder.buildAccountsFrom(data) {
                    completion(accounts)
                } else {
                    completion(nil)
                }
        }
    }
    
    // List of Trades
    func fetchTrades(completion: @escaping (Swift.Result<[IBTrade], TradingError>) -> Void) {
        guard let selectedAccount = selectedAccount else {
            completion(.failure(.fetchTradesFailed))
            return
        }
        let url = "https://localhost:5000/v1/portal/iserver/account/trades"
        afManager.request(url).responseData { [weak self] response in
            guard let self = self else { return }
            
            if let data = response.data, let ibTrades = self.ibTradesBuilder.buildIBTradesFrom(data) {
                var relevantTrades: [IBTrade] = ibTrades.filter { trade -> Bool in
                    return trade.account == selectedAccount.accountId && trade.symbol == self.config.ticker
                }
                relevantTrades.sort { (left, right) -> Bool in
                    return left.tradeTime_r > right.tradeTime_r
                }
                completion(.success(relevantTrades))
            } else {
                completion(.failure(.fetchTradesFailed))
            }
        }
    }
    
    func fetchLiveStopOrders(completion: @escaping (Swift.Result<[LiveOrder], TradingError>) -> Void) {
        guard let selectedAccount = selectedAccount else {
            completion(.failure(.fetchOrdersFailed))
            return
        }
        
        afManager.request("https://localhost:5000/v1/portal/iserver/account/orders").responseData { [weak self] response in
            guard let self = self else { return }
            
            if let data = response.data,
                let liveOrdersResponse = self.liveOrdersResponseBuilder.buildAccountsFrom(data),
                let orders = liveOrdersResponse.orders {
                var relevantOrders: [LiveOrder] = orders.filter { liveOrder -> Bool in
                    return liveOrder.status == "PreSubmitted" && liveOrder.conid == self.config.conId && liveOrder.acct == selectedAccount.accountId && liveOrder.orderType == "Stop"
                }
                relevantOrders.sort { (left, right) -> Bool in
                    return left.lastExecutionTime_r > right.lastExecutionTime_r
                }
                completion(.success(relevantOrders))
            } else {
                print("Fetch Live Orders Failed:")
                print(String(data: response.data!, encoding: .utf8)!)
                completion(.failure(.fetchOrdersFailed))
            }
        }
    }
    
    // Portfolio Positions
    func fetchRelevantPositions(completion: @escaping (Swift.Result<IBPosition?, TradingError>) -> Void) {
        guard let selectedAccount = selectedAccount else {
            completion(.failure(.fetchPositionsFailed))
            return
            
        }
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var networkErrors: [TradingError] = []
            
            self.resetPositionsCache { success in
                if !success {
                    networkErrors.append(.fetchPositionsFailed)
                }
                semaphore.signal()
            }
            
            semaphore.wait()
            
            
            if !networkErrors.isEmpty {
                DispatchQueue.main.async {
                    completion(.failure(.fetchPositionsFailed))
                }
                return
            }
            
            let url = "https://localhost:5000/v1/portal/portfolio/\(selectedAccount.accountId)/position/\(self.config.conId)"
            self.afManager.request(url).responseData { [weak self] response in
                guard let self = self else { return }
                
                if let data = response.data, let positions = self.ibPositionsBuilder.buildIBPositionsResponseFrom(data) {
                    let relevantPositions: [IBPosition] = positions.filter { position -> Bool in
                        return position.acctId == selectedAccount.accountId && position.conid == self.config.conId && position.position != 0
                    }
                    DispatchQueue.main.async {
                        completion(.success(relevantPositions.first))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(.fetchPositionsFailed))
                    }
                }
            }
        }
    }
    
    // Place Order
    func placeOrder(orderRef: String,
                    orderType: OrderType,
                    direction: TradeDirection,
                    size: Int,
                    completion: @escaping (Swift.Result<[PlacedOrderResponse], TradingError>) -> Void) {
        guard let selectedAccount = selectedAccount,
            let url: URL = URL(string: "https://localhost:5000/v1/portal/iserver/account/" + selectedAccount.accountId + "/order") else {
                completion(.failure(.orderFailed))
            return
        }
        
        var orderPrice: Double = 0
        switch orderType {
        case .limit(let price):
            orderPrice = price
        case .stop(let price):
            orderPrice = price
        default:
            break
        }
        orderPrice = orderPrice.round(nearest: 0.25)
        
        print(String(format: "%@ - %@: %@ %@ Order called at %@",
                     Date().hourMinuteSecond(),
                     orderRef,
                     direction.description(),
                     orderType.typeString(),
                     orderPrice == 0 ? "Market" : String(format: "%.2f", orderPrice)))
        
        let bodyString = String(format: "{ \"acctId\": \"%@\", \"conid\": %d, \"secType\": \"FUT\", \"cOID\": \"%@\", \"orderType\": \"%@\", \"listingExchange\": \"GLOBEX\", \"outsideRTH\": false, \"side\": \"%@\", \"price\": %.2f, \"ticker\": \"%@\", \"tif\": \"GTC\", \"quantity\": %d, \"useAdaptive\": false}", selectedAccount.accountId, config.conId, orderRef, orderType.typeString(), direction.tradeString(), orderPrice, config.ticker, size)
        if var request = try? URLRequest(url: url, method: .post, headers: ["Content-Type": "text/plain"]),
            let httpBody: Data = bodyString.data(using: .utf8) {
            request.httpBody = httpBody
            afManager.request(request).responseData { [weak self] response in
                guard let self = self else { return }
                
                if let data = response.data, let question = self.orderQuestionsBuilder.buildQuestionsFrom(data)?.first {
                    self.placeOrderReply(question: question, answer: true) { result in
                        switch result {
                        case .success(let response) :
                            completion(.success(response))
                        case .failure(let networkError):
                            completion(.failure(networkError))
                        }
                    }
                } else if let data = response.data, let errorResponse = self.errorResponseBuilder.buildErrorResponseFrom(data) {
                    if errorResponse.error == "Order couldn't be submitted:Local order ID=\(orderRef) is already registered." {
                        completion(.failure(.orderAlreadyPlaced))
                    } else {
                        completion(.failure(.orderFailed))
                    }
                } else if response.response?.statusCode == 200 {
                    print("Warning: order placed successfully but no response body")
                    completion(.success([PlacedOrderResponse(orderId: "", orderStatus: "")]))
                } else {
                    print("PlaceOrder failed:")
                    print(String(data: response.data!, encoding: .utf8)!)
                    completion(.failure(.orderFailed))
                }
            }
        } else {
            completion(.failure(.orderFailed))
        }
    }
    
    // Place Bracket Order
    func placeBrackOrder(orderRef: String,
                         stopPrice: Double,
                         direction: TradeDirection,
                         size: Int,
                         completion: @escaping (Swift.Result<[PlacedOrderResponse], TradingError>) -> Void) {
        guard let selectedAccount = selectedAccount,
            let url: URL = URL(string: "https://localhost:5000/v1/portal/iserver/account/" + selectedAccount.accountId + "/orders") else {
            completion(.failure(.orderFailed))
            return
        }
        
        let stopPrice: Double = stopPrice.round(nearest: 0.25)
        
        print(String(format: "%@ - %@: %@ Bracket Order called with stop at %@",
                     Date().hourMinuteSecond(),
                     orderRef,
                     direction.description(),
                     String(format: "%.2f", stopPrice)))
        
        let bodyString = "{ \"orders\": [ { \"acctId\": \"\(selectedAccount.accountId)\", \"conid\": \(config.conId), \"secType\": \"FUT\", \"cOID\": \"\(orderRef)\", \"orderType\": \"MKT\", \"listingExchange\": \"GLOBEX\", \"outsideRTH\": false, \"side\": \"\(direction.tradeString())\", \"ticker\": \"\(config.ticker)\", \"tif\": \"GTC\", \"quantity\": \(config.positionSize), \"useAdaptive\": false }, { \"acctId\": \"\(selectedAccount.accountId)\", \"conid\": \(config.conId), \"secType\": \"FUT\", \"parentId\": \"\(orderRef)\", \"orderType\": \"STP\", \"listingExchange\": \"GLOBEX\", \"outsideRTH\": false, \"side\": \"\(direction.reverse().tradeString())\", \"price\": \(stopPrice), \"ticker\": \"\(config.ticker)\", \"tif\": \"GTC\", \"quantity\": \(config.positionSize), \"useAdaptive\": false } ]}"
        if var request = try? URLRequest(url: url, method: .post, headers: ["Content-Type": "text/plain"]),
            let httpBody: Data = bodyString.data(using: .utf8) {
            request.httpBody = httpBody
            afManager.request(request).responseData { [weak self] response in
                guard let self = self else { return }
                
                if let data = response.data, let question = self.orderQuestionsBuilder.buildQuestionsFrom(data)?.first {
                    self.placeOrderReply(question: question, answer: true) { result in
                        switch result {
                        case .success(let response) :
                            completion(.success(response))
                        case .failure(let networkError):
                            completion(.failure(networkError))
                        }
                    }
                } else if let data = response.data, let errorResponse = self.errorResponseBuilder.buildErrorResponseFrom(data) {
                    if errorResponse.error?.contains("is already registered") ?? false {
                        completion(.failure(.orderAlreadyPlaced))
                    } else {
                        completion(.failure(.orderFailed))
                    }
                } else if response.response?.statusCode == 200 {
                    print("Warning: order placed successfully but no response body")
                    completion(.success([PlacedOrderResponse(orderId: "", orderStatus: "")]))
                } else {
                    print("PlaceOrder failed:")
                    print(String(data: response.data!, encoding: .utf8)!)
                    completion(.failure(.orderFailed))
                }
            }
        } else {
            completion(.failure(.orderFailed))
        }
    }
    
    // Modify Order
    func modifyOrder(orderType: OrderType,
                     direction: TradeDirection,
                     price: Double,
                     quantity: Int,
                     orderId: String,
                     completion: @escaping (Swift.Result<PlacedOrderResponse, TradingError>) -> Void) {
        
        guard let selectedAccount = selectedAccount,
            let url: URL = URL(string: String(format: "https://localhost:5000/v1/portal/iserver/account/%@/order/%@", selectedAccount.accountId, orderId)) else {
                completion(.failure(.modifyOrderFailed))
            return
        }
        
        let price = price.round(nearest: 0.25)
        
        print(String(format: "%@ - Modify %@ %@ Order %@ to %@ called",
                     Date().hourMinuteSecond(),
                     direction.description(),
                     orderType.typeString(),
                     orderId,
                     String(format: "%.2f", price)))
        
        let bodyString = String(format: "{ \"acctId\": \"%@\", \"conid\": %d, \"orderType\": \"%@\", \"outsideRTH\": false, \"side\": \"%@\", \"price\": %.2f, \"ticker\": \"%@\", \"tif\": \"GTC\", \"quantity\": %d, \"orderId\": %d}", selectedAccount.accountId, config.conId, orderType.typeString(), direction.tradeString(), price, config.ticker, config.positionSize, orderId)
        if var request = try? URLRequest(url: url, method: .post, headers: ["Content-Type": "text/plain"]),
            let httpBody: Data = bodyString.data(using: .utf8) {
            request.httpBody = httpBody
            afManager.request(request).responseData { [weak self] response in
                guard let self = self else { return }
                
                if let data = response.data, let question = self.orderQuestionsBuilder.buildQuestionsFrom(data)?.first {
                    self.placeOrderReply(question: question, answer: true) { result in
                        switch result {
                        case .success(let response) :
                            completion(.success(response.first!))
                        case .failure(let networkError):
                            completion(.failure(networkError))
                        }
                    }
                } else if let data = response.data,
                    let placedOrderResponse = self.placedOrderResponseBuilder.buildPlacedOrderResponseFrom(data)?.first {
                    completion(.success(placedOrderResponse))
                } else if response.response?.statusCode == 200 {
                    completion(.success(PlacedOrderResponse(orderId: "", orderStatus: "")))
                } else {
                    print("ModifyOrder Failed:")
                    print(String(data: response.data!, encoding: .utf8)!)
                    completion(.failure(.modifyOrderFailed))
                }
            }
        } else {
            completion(.failure(.modifyOrderFailed))
        }
    }
    
    // Delete Order
    func deleteOrder(orderId: String, completion: @escaping (Swift.Result<Bool, TradingError>) -> Void) {
        guard let selectedAccount = selectedAccount else {
            completion(.failure(.deleteOrderFailed))
            return
        }
        
        print("DeleteOrder " + orderId + " called")
        
        afManager.request(String(format: "https://localhost:5000/v1/portal/iserver/account/%@/order/%@", selectedAccount.accountId, orderId), method: .delete).responseData { response in
            if response.response?.statusCode == 200 {
                completion(.success(true))
            } else {
                completion(.failure(.deleteOrderFailed))
            }
        }
    }
    
    // Place Order Reply
    private func placeOrderReply(question: Question, answer: Bool, completion: @escaping (Swift.Result<[PlacedOrderResponse], TradingError>) -> Void) {

        guard let url: URL = URL(string: "https://localhost:5000/v1/portal/iserver/reply/" + question.identifier) else {
            completion(.failure(.orderReplyFailed))
            return
        }
        
        let bodyString = String(format: "{ \"confirmed\": %@}", answer ? "true" : "false")
        if var request = try? URLRequest(url: url, method: .post, headers: ["Content-Type": "text/plain"]),
            let httpBody: Data = bodyString.data(using: .utf8) {
            request.httpBody = httpBody
            afManager.request(request).responseData { response in
                
                if let data = response.data, let placedOrderResponses = self.placedOrderResponseBuilder.buildPlacedOrderResponseFrom(data) {
                    completion(.success(placedOrderResponses))
                } else if let data = response.data, let question = self.orderQuestionsBuilder.buildQuestionsFrom(data)?.first {
                    self.placeOrderReply(question: question, answer: true, completion: completion)
                } else if response.response?.statusCode == 200 {
                    completion(.success([PlacedOrderResponse(orderId: "", orderStatus: "")]))
                } else {
                    print("PlaceOrderReply Failed:")
                    print(String(data: response.data!, encoding: .utf8)!)
                    completion(.failure(.orderReplyFailed))
                }
            }
        } else {
            completion(.failure(.orderReplyFailed))
        }
    }
    
    // Reset Portfolio Positions Cache
    private func resetPositionsCache(completion: @escaping (Bool) -> Void) {
        guard let selectedAccount = selectedAccount else {
            completion(false)
            return
        }
        let url = "https://localhost:5000/v1/portal/portfolio/" + selectedAccount.accountId + "/positions/invalidate)"
        afManager.request(url).responseData
            { response in
                if response.response?.statusCode == 200 {
                    completion(true)
                } else {
                    completion(false)
                }
        }
    }
}
