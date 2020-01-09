//
//  NetworkManager.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-28.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation
import Alamofire

enum OrderType {
    case market
    case limit(price: Double)
    case stop(price: Double)
    
    func typeString() -> String {
        switch self {
        case .market:
            return "MKT"
        case .limit:
            return "LMT"
        case .stop:
            return "STP"
        }
    }
}

enum NetworkError: Error {
    case ssoAuthenticationFailed
    case fetchAuthStatusFailed
    case tickleFailed
    case logoffFailed
    case fetchAccountsFailed
    case fetchTradesFailed
    case fetchPositionsFailed
    case fetchLiveOrdersFailed
    case orderReplyFailed
    case previewOrderFailed
    case orderAlreadyPlaced
    case placeOrderFailed
    case modifyOrderFailed
    case deleteOrderFailed
    case verifyClosedPositionFailed
    case noPositionToClose
    case noCurrentPositionToPlaceStopLoss
    case positionNotClosed
    case resetPortfolioPositionsFailed
    
    func displayMessage() -> String {
        switch self {
        case .ssoAuthenticationFailed:
            return "SSO authentication failed."
        case .fetchAuthStatusFailed:
            return "Fetch authentication status failed."
        case .tickleFailed:
            return "Ping server failed."
        case .logoffFailed:
            return "Log off failed."
        case .fetchAccountsFailed:
            return "Fetch accounts failed."
        case .fetchTradesFailed:
            return "Fetch trades failed."
        case .fetchPositionsFailed:
            return "Fetch positions failed."
        case .fetchLiveOrdersFailed:
             return "Fetch live orders failed."
        case .orderReplyFailed:
            return "Answer question failed."
        case .previewOrderFailed:
            return "{review order failed."
        case .orderAlreadyPlaced:
            return "Order already placed."
        case .placeOrderFailed:
            return "Place order failed."
        case .modifyOrderFailed:
            return "Place order failed."
        case .deleteOrderFailed:
            return "delete order failed."
        case .verifyClosedPositionFailed:
            return "verify closed position failed."
        case .noPositionToClose:
            return "No position to close."
        case .noCurrentPositionToPlaceStopLoss:
            return "No current position to place stop loss."
        case .positionNotClosed:
            return "Position not closed."
        case .resetPortfolioPositionsFailed:
            return "Reset portfolio positions failed."
        }
    }
    
    func showDialog() {
//        let a: NSAlert = NSAlert()
//        a.messageText = "Error"
//        a.informativeText = self.displayMessage()
//        a.addButton(withTitle: "Okay")
//        a.alertStyle = NSAlert.Style.warning
//        a.runModal()
        print(Date().hourMinuteSecond(), self.displayMessage(), "error encountered")
    }
}

class NetworkManager {
    static let shared = NetworkManager()
    
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
    func validateSSO(completionHandler: @escaping (Swift.Result<SSOToken, NetworkError>) -> Void) {
        afManager.request("https://localhost:5000/v1/portal/sso/validate").responseData { [weak self] response in
            guard let self = self else { return }
            
            if let data = response.data, let ssoToken = self.ssoTokenBuilder.buildSSOTokenFrom(data) {
                completionHandler(.success(ssoToken))
            } else {
                completionHandler(.failure(.ssoAuthenticationFailed))
            }
        }
    }
    
    // Authentication Status
    func fetchAuthenticationStatus(completionHandler: @escaping (Swift.Result<AuthStatus, NetworkError>) -> Void) {
        afManager.request("https://localhost:5000/v1/portal/iserver/auth/status", method: .post).responseData { [weak self] response in
            guard let self = self else { return }
            
            if let data = response.data, let authStatus = self.authStatusBuilder.buildAuthStatusFrom(data) {
                completionHandler(.success(authStatus))
            } else {
                completionHandler(.failure(.fetchAuthStatusFailed))
            }
        }
    }
    
    // Tries to re-authenticate to Brokerage
    func reauthenticate(completionHandler: @escaping (Swift.Result<Bool, NetworkError>) -> Void) {
        afManager.request("https://localhost:5000/v1/portal/iserver/reauthenticate", method: .post).responseData { response in
            
            if response.response?.statusCode == 200 {
                completionHandler(.success(true))
            } else {
                completionHandler(.failure(.tickleFailed))
            }
        }
    }
    
    // Ping the server to keep the session open
    func pingServer(completionHandler: @escaping (Swift.Result<Bool, NetworkError>) -> Void) {
        afManager.request("https://localhost:5000/v1/portal/tickle", method: .post).responseJSON { response in
            if response.response?.statusCode == 200 {
                completionHandler(.success(true))
            } else {
                completionHandler(.failure(.tickleFailed))
            }
        }
    }
    
    // Ends the current session
    func logOut(completionHandler: @escaping (Swift.Result<Bool, NetworkError>) -> Void) {
        afManager.request("https://localhost:5000/v1/portal/logout", method: .post).responseJSON { response in
            if response.response?.statusCode == 200 {
                completionHandler(.success(true))
            } else {
                completionHandler(.failure(.logoffFailed))
            }
        }
    }
    
    // Portfolio Accounts
    func fetchAccounts(completionHandler: @escaping (Swift.Result<[Account], NetworkError>) -> Void) {
        afManager.request("https://localhost:5000/v1/portal/portfolio/accounts").responseData { [weak self] response in
            guard let self = self else { return }
            
            if let data = response.data, let accounts = self.accountsBuilder.buildAccountsFrom(data) {
                completionHandler(.success(accounts))
            } else {
                completionHandler(.failure(.fetchAccountsFailed))
            }
        }
    }
    
    // List of Trades
    func fetchTrades(completionHandler: @escaping (Swift.Result<[IBTrade], NetworkError>) -> Void) {
        guard let selectedAccount = selectedAccount else {
            completionHandler(.failure(.previewOrderFailed))
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
                completionHandler(.success(relevantTrades))
            } else {
                completionHandler(.failure(.fetchTradesFailed))
            }
        }
    }
    
    // All Live Orders
    func fetchLiveOrders(completionHandler: @escaping (Swift.Result<[LiveOrder], NetworkError>) -> Void) {
        guard let selectedAccount = selectedAccount else {
            completionHandler(.failure(.previewOrderFailed))
            return
        }
        
        afManager.request("https://localhost:5000/v1/portal/iserver/account/orders").responseData { [weak self] response in
            guard let self = self else { return }
            
            if let data = response.data,
                let liveOrdersResponse = self.liveOrdersResponseBuilder.buildAccountsFrom(data),
                let orders = liveOrdersResponse.orders {
                let relevantOrders: [LiveOrder] = orders.filter { liveOrder -> Bool in
                    return (liveOrder.status == "PreSubmitted" || liveOrder.status == "Filled") && liveOrder.conid == self.config.conId && liveOrder.acct == selectedAccount.accountId
                }
                completionHandler(.success(relevantOrders))
            } else {
                print("Fetch Live Orders Failed:")
                print(String(data: response.data!, encoding: .utf8)!)
                completionHandler(.failure(.fetchLiveOrdersFailed))
            }
        }
    }
    
    // Reset Portfolio Positions Cache
    private func resetPositionsCache(completionHandler: @escaping (Swift.Result<Bool, NetworkError>) -> Void) {
        guard let selectedAccount = selectedAccount else {
            completionHandler(.failure(.previewOrderFailed))
            return
        }
        let url = "https://localhost:5000/v1/portal/portfolio/" + selectedAccount.accountId + "/positions/invalidate)"
        afManager.request(url).responseData
            { response in
                if response.response?.statusCode == 200 {
                    completionHandler(.success(true))
                } else {
                    completionHandler(.failure(.resetPortfolioPositionsFailed))
                }
        }
    }
    
    // Portfolio Positions
    func fetchRelevantPositions(completionHandler: @escaping (Swift.Result<IBPosition?, NetworkError>) -> Void) {
        guard let selectedAccount = selectedAccount else {
            completionHandler(.failure(.previewOrderFailed))
            return
            
        }
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var networkErrors: [NetworkError] = []
            
            self.resetPositionsCache { result in
                switch result {
                case .failure(let networkError):
                    networkErrors.append(networkError)
                default:
                    break
                }
                semaphore.signal()
            }
            
            semaphore.wait()
            
            
            if !networkErrors.isEmpty {
                DispatchQueue.main.async {
                    completionHandler(.failure(.fetchPositionsFailed))
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
                        completionHandler(.success(relevantPositions.first))
                    }
                } else {
                    DispatchQueue.main.async {
                        completionHandler(.failure(.fetchPositionsFailed))
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
                    completionHandler: @escaping (Swift.Result<PlacedOrderResponse, NetworkError>) -> Void) {
        guard let selectedAccount = selectedAccount,
            let url: URL = URL(string: "https://localhost:5000/v1/portal/iserver/account/" + selectedAccount.accountId + "/order") else {
            completionHandler(.failure(.placeOrderFailed))
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
        
        print(String(format: "%@: %@ %@ Order called at %@",
                     orderRef,
                     direction.description(),
                     orderType.typeString(),
                     orderPrice == 0 ? "Market" : String(format: "%.2f", orderPrice)))
        
        let bodyString = String(format: "{ \"acctId\": \"%@\", \"conid\": %d, \"secType\": \"FUT\", \"cOID\": \"%@\", \"orderType\": \"%@\", \"listingExchange\": \"GLOBEX\", \"outsideRTH\": false, \"side\": \"%@\", \"price\": %.2f, \"ticker\": \"%@\", \"tif\": \"GTC\", \"quantity\": %d, \"useAdaptive\": false}", selectedAccount.accountId, config.conId, orderRef, orderType.typeString(), direction.ibTradeString(), orderPrice, config.ticker, size)
        if var request = try? URLRequest(url: url, method: .post, headers: ["Content-Type": "text/plain"]),
            let httpBody: Data = bodyString.data(using: .utf8) {
            request.httpBody = httpBody
            afManager.request(request).responseData { [weak self] response in
                guard let self = self else { return }
                
                if let data = response.data, let question = self.orderQuestionsBuilder.buildQuestionsFrom(data)?.first {
                    self.placeOrderReply(question: question, answer: true) { result in
                        switch result {
                        case .success(let response) :
                            completionHandler(.success(response))
                        case .failure(let networkError):
                            completionHandler(.failure(networkError))
                        }
                    }
                } else if let data = response.data, let _ = self.errorResponseBuilder.buildErrorResponseFrom(data) {
                    completionHandler(.failure(.orderAlreadyPlaced))
                } else if response.response?.statusCode == 200 {
                    completionHandler(.success(PlacedOrderResponse(orderId: "", orderStatus: "")))
                } else {
                    print("PlaceOrder failed:")
                    print(String(data: response.data!, encoding: .utf8)!)
                    completionHandler(.failure(.placeOrderFailed))
                }
            }
        } else {
            completionHandler(.failure(.placeOrderFailed))
        }
    }
    
    
    // Place Order Reply
    // https://localhost:5000/v1/portal/iserver/reply/{replyid}
    func placeOrderReply(question: Question, answer: Bool, completionHandler: @escaping (Swift.Result<PlacedOrderResponse, NetworkError>) -> Void) {

        guard let url: URL = URL(string: "https://localhost:5000/v1/portal/iserver/reply/" + question.identifier) else {
            completionHandler(.failure(.orderReplyFailed))
            return
        }
        
        let bodyString = String(format: "{ \"confirmed\": %@}", answer ? "true" : "false")
        if var request = try? URLRequest(url: url, method: .post, headers: ["Content-Type": "text/plain"]),
            let httpBody: Data = bodyString.data(using: .utf8) {
            request.httpBody = httpBody
            afManager.request(request).responseData { response in
                
                if let data = response.data, let placedOrderResponse = self.placedOrderResponseBuilder.buildPlacedOrderResponseFrom(data)?.first {
                    completionHandler(.success(placedOrderResponse))
                } else if let data = response.data, let question = self.orderQuestionsBuilder.buildQuestionsFrom(data)?.first {
                    self.placeOrderReply(question: question, answer: true, completionHandler: completionHandler)
                } else if response.response?.statusCode == 200 {
                    completionHandler(.success(PlacedOrderResponse(orderId: "", orderStatus: "")))
                } else {
                    print("PlaceOrderReply Failed:")
                    print(String(data: response.data!, encoding: .utf8)!)
                    completionHandler(.failure(.orderReplyFailed))
                }
            }
        } else {
            completionHandler(.failure(.orderReplyFailed))
        }
    }
    
    // Modify Order
    func modifyOrder(orderType: OrderType,
                     direction: TradeDirection,
                     price: Double,
                     quantity: Int,
                     orderId: String,
                     completionHandler: @escaping (Swift.Result<PlacedOrderResponse, NetworkError>) -> Void) {
        
        guard let selectedAccount = selectedAccount,
            let url: URL = URL(string: String(format: "https://localhost:5000/v1/portal/iserver/account/%@/order/%@", selectedAccount.accountId, orderId)) else {
                completionHandler(.failure(.modifyOrderFailed))
            return
        }
        
        let price = price.round(nearest: 0.25)
        
        print(String(format: "Modify %@ %@ Order %@ to %@ called",
                     direction.description(),
                     orderType.typeString(),
                     orderId,
                     String(format: "%.2f", price)))
        
        let bodyString = String(format: "{ \"acctId\": \"%@\", \"conid\": %d, \"orderType\": \"%@\", \"outsideRTH\": false, \"side\": \"%@\", \"price\": %.2f, \"ticker\": \"%@\", \"tif\": \"GTC\", \"quantity\": %d, \"orderId\": %d}", selectedAccount.accountId, config.conId, orderType.typeString(), direction.ibTradeString(), price, config.ticker, config.positionSize, orderId)
        if var request = try? URLRequest(url: url, method: .post, headers: ["Content-Type": "text/plain"]),
            let httpBody: Data = bodyString.data(using: .utf8) {
            request.httpBody = httpBody
            afManager.request(request).responseData { [weak self] response in
                guard let self = self else { return }
                
                if let data = response.data, let question = self.orderQuestionsBuilder.buildQuestionsFrom(data)?.first {
                    self.placeOrderReply(question: question, answer: true) { result in
                        switch result {
                        case .success(let response) :
                            completionHandler(.success(response))
                        case .failure(let networkError):
                            completionHandler(.failure(networkError))
                        }
                    }
                } else if let data = response.data,
                    let placedOrderResponse = self.placedOrderResponseBuilder.buildPlacedOrderResponseFrom(data)?.first {
                    completionHandler(.success(placedOrderResponse))
                } else if response.response?.statusCode == 200 {
                    completionHandler(.success(PlacedOrderResponse(orderId: "", orderStatus: "")))
                } else {
                    print("ModifyOrder Failed:")
                    print(String(data: response.data!, encoding: .utf8)!)
                    completionHandler(.failure(.modifyOrderFailed))
                }
            }
        } else {
            completionHandler(.failure(.modifyOrderFailed))
        }
    }
    
    // Delete Order
    func deleteOrder(orderId: String, completionHandler: @escaping (Swift.Result<Bool, NetworkError>) -> Void) {
        guard let selectedAccount = selectedAccount else {
            completionHandler(.failure(.deleteOrderFailed))
            return
        }
        
        print("DeleteOrder " + orderId + " called")
        
        afManager.request(String(format: "https://localhost:5000/v1/portal/iserver/account/%@/order/%@", selectedAccount.accountId, orderId), method: .delete).responseData { response in
            if response.response?.statusCode == 200 {
                completionHandler(.success(true))
            } else {
                completionHandler(.failure(.deleteOrderFailed))
            }
        }
    }
    
    func downloadData(from url: String, fileName: String, completion: @escaping (String?, URLResponse?, Error?) -> ()) {
        let destination: DownloadRequest.DownloadFileDestination = { _, _ in
            var documentsURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            documentsURL = documentsURL.appendingPathComponent(fileName)
            return (documentsURL, [.removePreviousFile])
        }

        Alamofire.download(url, to: destination).responseData { response in
            if let destinationUrl = response.destinationURL, let string = try? String(contentsOf: destinationUrl, encoding: .utf8) {
               completion(string, nil, nil)
            } else {
                completion(nil, nil, nil)
            }
        }
    }
    
    func fetchLatestAvailableUrl(interval: SignalInteval, completion: @escaping (String?) -> ()) {
        let queue = DispatchQueue.global()
        queue.async {
            let semaphore = DispatchSemaphore(value: 0)
            var existUrl: String?
            
            while existUrl == nil {
                let now = Date()
                let currentSecond = now.second() - 1
                
                if currentSecond < 5 {
                    sleep(1)
                    continue
                }
                
                for i in stride(from: currentSecond, through: 0, by: -1) {
                    if existUrl != nil {
                        break
                    }
                    
                    let urlString: String = String(format: "%@%@_%02d-%02d-%02d-%02d-%02d.txt", self.config.dataServerURL, interval.text(), now.month(), now.day(), now.hour(), now.minute(), i)
                    
                    Alamofire.SessionManager.default.request(urlString).validate().response { response in
                        if response.response?.statusCode == 200 {
                            existUrl = urlString
                        }
                        semaphore.signal()
                    }
                    
                    semaphore.wait()
                }
                
                DispatchQueue.main.async {
                    if let existUrl = existUrl {
                        completion(existUrl)
                    }
                }
            }
        }
    }
    
    func fetchFirstAvailableUrlInMinute(time: Date, interval: SignalInteval, completion: @escaping (String?) -> ()) {
        let queue = DispatchQueue.global()
        queue.async {
            let semaphore = DispatchSemaphore(value: 0)
            var existUrl: String?
            
            for second in 0...59 {
                if existUrl != nil {
                    break
                }
                
                let urlString: String = String(format: "%@%@_%02d-%02d-%02d-%02d-%02d.txt", self.config.dataServerURL, interval.text(), time.month(), time.day(), time.hour(), time.minute(), second)
                
                Alamofire.SessionManager.default.request(urlString).validate().response { response in
                    if response.response?.statusCode == 200 {
                        existUrl = urlString
                    }
                    semaphore.signal()
                }
                
                semaphore.wait()
            }
            
            DispatchQueue.main.async {
                completion(existUrl)
            }
        }
    }
}
