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
    case Market
    case Limit
    case Stop
    
    func typeString() -> String {
        switch self {
        case .Market:
            return "MKT"
        case .Limit:
            return "LMT"
        case .Stop:
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
    private let previewResponseBuilder: PreviewResponseBuilder = PreviewResponseBuilder()
    
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
    // https://localhost:5000/v1/portal/sso/validate
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
    // https://localhost:5000/v1/portal/iserver/auth/status
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
    // https://localhost:5000/v1/portal/iserver/reauthenticate
    func reauthenticate(completionHandler: @escaping (Swift.Result<AuthStatus, NetworkError>) -> Void) {
        afManager.request("https://localhost:5000/v1/portal/iserver/reauthenticate", method: .post).responseData { [weak self] response in
            guard let self = self else { return }
            
            if let data = response.data, let authStatus = self.authStatusBuilder.buildAuthStatusFrom(data) {
                completionHandler(.success(authStatus))
            } else {
                completionHandler(.failure(.fetchAuthStatusFailed))
            }
        }
    }
    
    // Ping the server to keep the session open
    // https://localhost:5000/v1/portal/tickle
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
    // https://localhost:5000/v1/portal/logout
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
    // https://localhost:5000/v1/portal/portfolio/accounts
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
    // https://localhost:5000/v1/portal/iserver/account/trades
    func fetchLatestTrade(completionHandler: @escaping (Swift.Result<IBTrade?, NetworkError>) -> Void) {
        guard let selectedAccount = selectedAccount else {
            completionHandler(.failure(.previewOrderFailed))
            return
        }
        
        afManager.request("https://localhost:5000/v1/portal/iserver/account/trades").responseData { [weak self] response in
            guard let self = self else { return }
            
            if let data = response.data, let ibTrades = self.ibTradesBuilder.buildIBTradesFrom(data) {
                var relevantTrades: [IBTrade] = ibTrades.filter { trade -> Bool in
                    return trade.account == selectedAccount.accountId && trade.symbol == self.config.ticker
                }
                relevantTrades.sort { (left, right) -> Bool in
                    return left.tradeTime_r > right.tradeTime_r
                }
                completionHandler(.success(relevantTrades.first))
            } else {
                completionHandler(.failure(.fetchTradesFailed))
            }
        }
    }
    
    // Live Orders
    // https://localhost:5000/v1/portal/iserver/account/orders
    // Only fetch orders this bot trades
    func fetchStopOrder(completionHandler: @escaping (Swift.Result<LiveOrder?, NetworkError>) -> Void) {
        afManager.request("https://localhost:5000/v1/portal/iserver/account/orders").responseData { [weak self] response in
            guard let self = self else { return }
            
            if let data = response.data,
                let liveOrdersResponse = self.liveOrdersResponseBuilder.buildAccountsFrom(data),
                let orders = liveOrdersResponse.orders {
                let relevantOrders: [LiveOrder] = orders.filter { liveOrder -> Bool in
                    return liveOrder.status == "Submitted" && liveOrder.conid == self.config.conId && liveOrder.orderType == "STP"
                }
                completionHandler(.success(relevantOrders.first))
            } else {
                completionHandler(.failure(.fetchLiveOrdersFailed))
            }
        }
    }
    
    // Portfolio Positions
    // https://localhost:5000/v1/portal/portfolio/{accountId}/positions/{pageId}
    func fetchRelevantPositions(completionHandler: @escaping (Swift.Result<IBPosition?, NetworkError>) -> Void) {
        guard let selectedAccount = selectedAccount else {
            completionHandler(.failure(.previewOrderFailed))
            return
        }
        
        afManager.request("https://localhost:5000/v1/portal/portfolio/" + selectedAccount.accountId + "/positions/0").responseData { [weak self] response in
            guard let self = self else { return }
            
            if let data = response.data, let positions = self.ibPositionsBuilder.buildErrorResponseFrom(data) {
                let relevantPositions: [IBPosition] = positions.filter { position -> Bool in
                    return position.acctId == selectedAccount.accountId && position.conid == self.config.conId
                }
                completionHandler(.success(relevantPositions.first))
            } else {
                completionHandler(.failure(.fetchLiveOrdersFailed))
            }
        }
    }
    
    // Preview Order
    // https://localhost:5000/v1/portal/iserver/account/{accountId}/order/whatif
    func previewOrder(orderType: OrderType, direction: TradeDirection, price: Double = 0, time: Date, completionHandler: @escaping (Swift.Result<PreviewResponse, NetworkError>) -> Void) {
        guard let selectedAccount = selectedAccount else {
            completionHandler(.failure(.previewOrderFailed))
            return
        }
        
        let url = "https://localhost:5000/v1/portal/iserver/account/" + selectedAccount.accountId + "/order/whatif"
        let bodyString = String(format: "{ \"acctId\": \"%@\", \"conid\": %d, \"secType\": \"FUT\", \"cOID\": \"%@\", \"orderType\": \"%@\", \"listingExchange\": \"GLOBEX\", \"outsideRTH\": false, \"side\": \"%@\", \"price\": %.2f, \"ticker\": \"%@\", \"tif\": \"GTC\", \"quantity\": %d, \"useAdaptive\": false}", selectedAccount.accountId, config.conId, generateOrderIdentifier(direction: direction, time: time), orderType.typeString(), direction.ibTradeString(),  price, config.ticker, config.positionSize)
        if var request = try? URLRequest(url: url, method: .post, headers: ["Content-Type": "text/plain"]),
            let httpBody: Data = bodyString.data(using: .utf8) {
            request.httpBody = httpBody
            afManager.request(request).responseData { [weak self] response in
                guard let self = self else { return }
                
                if let data = response.data, let previewResponse = self.previewResponseBuilder.buildPreviewResponseFrom(data) {
                    completionHandler(.success(previewResponse))
                } else {
                    completionHandler(.failure(.previewOrderFailed))
                }
            }
        } else {
            completionHandler(.failure(.previewOrderFailed))
        }
    }
    
    // Place Order
    func placeOrder(orderType: OrderType,
                    direction: TradeDirection,
                    price: Double = 0,
                    time: Date,
                    completionHandler: @escaping (Swift.Result<[Question], NetworkError>) -> Void) {
        
        guard let selectedAccount = selectedAccount,
            let url: URL = URL(string: "https://localhost:5000/v1/portal/iserver/account/" + selectedAccount.accountId + "/order") else {
            completionHandler(.failure(.placeOrderFailed))
            return
        }
        
        let bodyString = String(format: "{ \"acctId\": \"%@\", \"conid\": %d, \"secType\": \"FUT\", \"cOID\": \"%@\", \"orderType\": \"%@\", \"listingExchange\": \"GLOBEX\", \"outsideRTH\": true, \"side\": \"%@\", \"price\": %.2f, \"ticker\": \"%@\", \"tif\": \"DAY\", \"quantity\": %d, \"useAdaptive\": false}", selectedAccount.accountId, config.conId, generateOrderIdentifier(direction: direction, time: time), orderType.typeString(), direction.ibTradeString(), price, config.ticker, config.positionSize)
        if var request = try? URLRequest(url: url, method: .post, headers: ["Content-Type": "text/plain"]),
            let httpBody: Data = bodyString.data(using: .utf8) {
            request.httpBody = httpBody
            afManager.request(request).responseData { [weak self] response in
                guard let self = self else { return }
                
                if let data = response.data, let questions = self.orderQuestionsBuilder.buildQuestionsFrom(data) {
                    completionHandler(.success(questions))
                } else if let data = response.data, let _ = self.errorResponseBuilder.buildErrorResponseFrom(data) {
                    completionHandler(.failure(.orderAlreadyPlaced))
                } else {
                    completionHandler(.failure(.placeOrderFailed))
                }
            }
        } else {
            completionHandler(.failure(.placeOrderFailed))
        }
    }
    
    
    // Place Order Reply
    // https://localhost:5000/v1/portal/iserver/reply/{replyid}
    func placeOrderReply(question: Question, answer: Bool, completionHandler: @escaping (Swift.Result<Bool, NetworkError>) -> Void) {
        let parameters: [String : Any] = ["confirmed": answer]
        
        afManager.request("https://localhost:5000/v1/portal/iserver/reply/" + question.identifier,
                          method: .post,
                          parameters: parameters).responseJSON { response in
                            if response.response?.statusCode == 200 {
                                completionHandler(.success(true))
                            } else {
                                completionHandler(.failure(.orderReplyFailed))
                            }
        }
    }
    
    // Modify Order
    func modifyOrder(orderType: OrderType,
                     direction: TradeDirection,
                     price: Double,
                     quantity: Int,
                     order: LiveOrder,
                     completionHandler: @escaping (Swift.Result<[Question], NetworkError>) -> Void) {
        
        guard let selectedAccount = selectedAccount,
            let url: URL = URL(string: String(format: "https://localhost:5000/v1/portal/iserver/account/%@/order/%d", selectedAccount.accountId, order.orderId)) else {
            completionHandler(.failure(.placeOrderFailed))
            return
        }
        
        let bodyString = String(format: "{ \"acctId\": \"%@\", \"conid\": %d, \"orderType\": \"%@\", \"outsideRTH\": true, \"side\": \"%@\", \"price\": %.2f, \"ticker\": \"%@\", \"tif\": \"DAY\", \"quantity\": %d, \"orderId\": %d}", selectedAccount.accountId, config.conId, orderType.typeString(), direction.ibTradeString(), price, config.ticker, config.positionSize, order.orderId)
        if var request = try? URLRequest(url: url, method: .post, headers: ["Content-Type": "text/plain"]),
            let httpBody: Data = bodyString.data(using: .utf8) {
            request.httpBody = httpBody
            afManager.request(request).responseData { [weak self] response in
                guard let self = self else { return }
                
                if let data = response.data, let questions = self.orderQuestionsBuilder.buildQuestionsFrom(data) {
                    completionHandler(.success(questions))
                } else {
                    completionHandler(.failure(.modifyOrderFailed))
                }
            }
        } else {
            completionHandler(.failure(.modifyOrderFailed))
        }
    }
    
    // Delete Order
    func deleteOrder(order: LiveOrder, completionHandler: @escaping (Swift.Result<Bool, NetworkError>) -> Void) {
        guard let selectedAccount = selectedAccount else {
            completionHandler(.failure(.deleteOrderFailed))
            return
        }
        
        afManager.request(String(format: "https://localhost:5000/v1/portal/iserver/account/%@/order/%d", selectedAccount.accountId, order.orderId),
                          method: .delete).responseData { response in
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
                    
                    let urlString: String = String(format: "%@%@_%02d-%02d-%02d.txt", self.config.dataServerURL, interval.text(), now.hour(), now.minute(), i)
                    
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
    
    // Private:
    private func generateOrderIdentifier(direction: TradeDirection, time: Date) -> String {
        return direction.description() + "-" + time.generateShortDate()
    }
}
