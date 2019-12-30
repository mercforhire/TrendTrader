//
//  IBNetworkManager.swift
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
    case fetchLiveOrdersFailed
    case orderReplyFailed
    case placeOrderFailed
    case modifyOrderFailed
    case deleteOrderFailed
}

class IBNetworkManager {
    static let shared = IBNetworkManager()
    
    private let afManager: Alamofire.SessionManager
    private let ssoTokenBuilder: SSOTokenBuilder = SSOTokenBuilder()
    private let authStatusBuilder: AuthStatusBuilder = AuthStatusBuilder()
    private let accountsBuilder: AccountsBuilder = AccountsBuilder()
    private let ibTradesBuilder: IBTradesBuilder = IBTradesBuilder()
    private let liveOrdersResponseBuilder: LiveOrdersResponseBuilder = LiveOrdersResponseBuilder()
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
    func fetchTrades(completionHandler: @escaping (Swift.Result<[IBTrade], NetworkError>) -> Void) {
        afManager.request("https://localhost:5000/v1/portal/iserver/account/trades").responseData { [weak self] response in
            guard let self = self else { return }
            
            if let data = response.data, let ibTrades = self.ibTradesBuilder.buildIBTradesFrom(data) {
                completionHandler(.success(ibTrades))
            } else {
                completionHandler(.failure(.fetchTradesFailed))
            }
        }
    }
    
    // Live Orders
    // https://localhost:5000/v1/portal/iserver/account/orders
    func fetchLiveOrders(completionHandler: @escaping (Swift.Result<LiveOrdersResponse, NetworkError>) -> Void) {
        afManager.request("https://localhost:5000/v1/portal/iserver/account/orders").responseData { [weak self] response in
            guard let self = self else { return }
            
            if let data = response.data, let liveOrdersResponse = self.liveOrdersResponseBuilder.buildAccountsFrom(data) {
                completionHandler(.success(liveOrdersResponse))
            } else {
                completionHandler(.failure(.fetchLiveOrdersFailed))
            }
        }
    }
    
    // Place Order
    func placeOrder(accountId: String, orderType: OrderType, direction: TradeDirection, price: Double? = nil, orderId: String, completionHandler: @escaping (Swift.Result<PlacedOrderResponse, NetworkError>) -> Void) {
        let parameters: [String : Any] = ["conid": Config.shared.ConId,
                                          "secType": "FUT",
                                          "orderType": orderType.typeString(),
                                          "cOID": orderId,
                                          "outsideRTH": true,
                                          "side": direction.ibTradeString(),
                                          "ticker": Config.shared.Ticker,
                                          "tif": "DAY",
                                          "quantity": Config.shared.PositionSize,
                                          "useAdaptive": false]
        
        afManager.request("https://localhost:5000/v1/portal/iserver/account/" + accountId + "/order",
                          method: .post,
                          parameters: parameters).responseData { [weak self] response in
                            guard let self = self else { return }
                            
                            if let data = response.data, let orderResponse = self.placedOrderResponseBuilder.buildAccountsFrom(data) {
                                completionHandler(.success(orderResponse))
                            } else {
                                completionHandler(.failure(.placeOrderFailed))
                            }
        }
    }
    
    
    // Place Order Reply
    // https://localhost:5000/v1/portal/iserver/reply/{replyid}
    func placeOrderReply(replyId: String, answer: Bool, completionHandler: @escaping (Swift.Result<Bool, NetworkError>) -> Void) {
        let parameters: [String : Any] = ["confirmed": answer]
        
        afManager.request("https://localhost:5000/v1/portal/iserver/reply/" + replyId,
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
    func modifyOrder(accountId: String,
                     orderType: OrderType,
                     direction: TradeDirection,
                     price: Double,
                     orderId: String,
                     completionHandler: @escaping (Swift.Result<Bool, NetworkError>) -> Void) {
        let parameters: [String : Any] = [
            "acctId": accountId,
            "conid": Config.shared.ConId,
            "orderId": orderId,
            "orderType": orderType.typeString(),
            "outsideRTH": true,
            "price": price,
            "side": direction.ibTradeString(),
            "ticker": Config.shared.Ticker,
            "tif": "DAY",
            "quantity": Config.shared.PositionSize]
        
        afManager.request("https://localhost:5000/v1/portal/iserver/account/" + accountId + "/order/" + orderId,
                          method: .post,
                          parameters: parameters).responseJSON { response in
                            if response.response?.statusCode == 200 {
                                completionHandler(.success(true))
                            } else {
                                completionHandler(.failure(.modifyOrderFailed))
                            }
        }
    }
    
    // Delete Order
    func deleteOrder(accountId: String,
                     orderId: String,
                     completionHandler: @escaping (Swift.Result<Bool, NetworkError>) -> Void) {
        afManager.request("https://localhost:5000/v1/portal/iserver/account/" + accountId + "/order/" + orderId,
                          method: .delete).responseJSON { response in
                            if response.response?.statusCode == 200 {
                                completionHandler(.success(true))
                            } else {
                                completionHandler(.failure(.deleteOrderFailed))
                            }
        }
    }
}
