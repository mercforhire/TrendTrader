//
//  AccountState.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-05-24.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Foundation

struct AccountState: Codable {
    var startInSimMode = false
    
    var modelBalance: Double = 0.0
    var accBalance: Double = 0.0
    
    var peakModelBalance: Double = 0.0
    var peakAccBalance: Double = 0.0
    
    var modelMaxDD: Double = 0.0
    
    var modelDrawdown: Double {
        return peakModelBalance - modelBalance
    }
    
    var accDrawdown: Double {
        return peakAccBalance - accBalance
    }
}
