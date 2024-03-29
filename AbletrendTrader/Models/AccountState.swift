//
//  AccountState.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-05-24.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation

struct AccountState: Codable, Equatable {
    var simMode = false
    
    var modelBalance: Double = 0.0
    var accBalance: Double = 0.0
    
    var modelPeak: Double = 0.0
    var accPeak: Double = 0.0
    
    var latestTrough: Double = 0.0
    // probationMode true when account just come out of sim mode and have not yet set a new high in account balance
    var probationMode = false
    
    var modelDrawdown: Double {
        return modelPeak - modelBalance
    }
    
    var accDrawdown: Double {
        return accPeak - accBalance
    }
    
    func description() -> String {
        var output = "In sim mode: \(simMode ? "true" : "false")"
        
        output.append(", Model balance: \(String(format: "%.2f", modelBalance))")
        output.append(", Acc balance: \(String(format: "%.2f", accBalance))")
        output.append(", Model peak: \(String(format: "%.2f", modelPeak))")
        output.append(", Acc peak: \(String(format: "%.2f", accPeak))")
        output.append(", Latest trough: \(String(format: "%.2f", latestTrough))")
        output.append(", Probation mode: \(probationMode ? "true" : "false")")
        
        return output
    }
    
    static func == (lhs: AccountState, rhs: AccountState) -> Bool {
        return
            lhs.simMode == rhs.simMode &&
            lhs.modelBalance == rhs.modelBalance &&
            lhs.accBalance == rhs.accBalance &&
            lhs.modelPeak == rhs.modelPeak &&
            lhs.accPeak == rhs.accPeak &&
            lhs.latestTrough == rhs.latestTrough &&
            lhs.probationMode == rhs.probationMode
    }
}
