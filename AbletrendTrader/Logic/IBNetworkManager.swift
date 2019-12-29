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

class IBNetworkManager {
    private let afManager: Alamofire.SessionManager
    
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
//    {
//    "USER_ID": 43778794,
//    "USER_NAME": "feiyan598",
//    "RESULT": true,
//    "SF_ENABLED": false,
//    "IS_FREE_TRIAL": false,
//    "IP": "70.52.163.235",
//    "EXPIRES": 230411,
//    "lastAccessed": 1577567825252,
//    "loginType": 2,
//    "PAPER_USER_NAME": "feiyan598"
//    }
    func validateSSO() {
        afManager.request("https://localhost:5000/v1/portal/sso/validate").responseJSON { response in
            debugPrint("Response: \(response)")
        }
    }
    
    // Authentication Status
    // https://localhost:5000/v1/portal/iserver/auth/status
//    {
//    "authenticated": true,
//    "competing": false,
//    "connected": true,
//    "message": "",
//    "MAC": "98:F2:B3:23:2E:68",
//    "fail": ""
//    }
    func authenticationStatus() {
        afManager.request("https://localhost:5000/v1/portal/iserver/auth/status", method: .post).responseJSON { response in
            debugPrint("Response: \(response)")
        }
    }
    
    // Tries to re-authenticate to Brokerage
    // https://localhost:5000/v1/portal/iserver/reauthenticate
    func reauthenticate() {
        afManager.request("https://localhost:5000/v1/portal/iserver/reauthenticate", method: .post).responseJSON { response in
            debugPrint("Response: \(response)")
        }
    }
    
    // Ping the server to keep the session open
    // https://localhost:5000/v1/portal/tickle
    func pingServer() {
        afManager.request("https://localhost:5000/v1/portal/tickle", method: .post).responseJSON { response in
            debugPrint("Response: \(response)")
        }
    }
    
    // Ends the current session
    // https://localhost:5000/v1/portal/logout
    func logOut() {
        afManager.request("https://localhost:5000/v1/portal/logout", method: .post).responseJSON { response in
            debugPrint("Response: \(response)")
        }
    }
    
    // Portfolio Accounts
    // https://localhost:5000/v1/portal/portfolio/accounts
//    [
//      {
//        "id": "string",
//        "accountId": "string",
//        "accountVan": "string",
//        "accountTitle": "string",
//        "displayName": "string",
//        "accountAlias": "string",
//        "accountStatus": 0,
//        "currency": "string",
//        "type": "string",
//        "tradingType": "string",
//        "faclient": true,
//        "parent": "string",
//        "desc": "string",
//        "covestor": true,
//        "master": {
//          "title": "string",
//          "officialTitle": "string"
//        }
//      }
//    ]
    func fetchAccounts() {
        afManager.request("https://localhost:5000/v1/portal/portfolio/accounts").responseJSON { response in
            debugPrint("Response: \(response)")
        }
    }
    
    // List of Trades
    // https://localhost:5000/v1/portal/iserver/account/trades
//    [
//      {
//        "execution_id": "string",
//        "symbol": "string",
//        "side": "string",
//        "order_description": "string",
//        "trade_time": "string",
//        "trade_time_r": 0,
//        "size": "string",
//        "price": "string",
//        "submitter": "string",
//        "exchange": "string",
//        "comission": 0,
//        "net_amount": 0,
//        "account": "string",
//        "company_name": "string",
//        "contract_description_1": "string",
//        "sec_type": "string",
//        "conidex": "string",
//        "position": "string",
//        "clearing_id": "string",
//        "clearing_name": "string",
//        "order_ref": "string"
//      }
//    ]
    func fetchTrades() {
        afManager.request("https://localhost:5000/v1/portal/iserver/account/trades").responseJSON { response in
            debugPrint("Response: \(response)")
        }
    }
    
    // Live Orders
    // https://localhost:5000/v1/portal/iserver/account/orders
    func fetchLiveOrders() {
        afManager.request("https://localhost:5000/v1/portal/iserver/account/orders").responseJSON { response in
            debugPrint("Response: \(response)")
        }
    }
    
    // Place Order
    func replaceOrder(accountId: String, orderType: OrderType, direction: TradeDirection, price: Double? = nil, orderId: String) {
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
                          parameters: parameters).responseJSON { response in
            debugPrint("Response: \(response)")
        }
    }
    
    
    // Place Order Reply
    
    
    // Modify Order
    func modifyOrder(accountId: String, orderType: OrderType, direction: TradeDirection, price: Double, orderId: String) {
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
            debugPrint("Response: \(response)")
        }
    }
    
    // Delete Order
    func deleteOrder(accountId: String, orderId: String) {
        afManager.request("https://localhost:5000/v1/portal/iserver/account/" + accountId + "/order/" + orderId,
                          method: .delete).responseJSON { response in
            debugPrint("Response: \(response)")
        }
    }
}
