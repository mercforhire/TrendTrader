//
//  AccountsBuilder.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-29.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class AccountsBuilder {
    func buildAccountsFrom(_ jsonData : Data) -> [Account]? {
        let decoder: JSONDecoder = JSONDecoder()
        do
        {
            let accounts: [Account]? = try decoder.decode([Account]?.self, from: jsonData)
            return accounts
        }
        catch(let error) {
            print(error)
        }
        return nil
    }
}
