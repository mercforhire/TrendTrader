//
//  PriceBar.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-20.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

struct PriceBar {
    var identifier: String
    var candleStick: CandleStick
    var signals: [Signal]
    
    func getOneMinSignal() -> Signal? {
        for signal in signals {
            if signal.inteval == .oneMin {
                return signal
            }
        }
        
        return nil
    }
    
    func getBarColor() -> SignalColor {
        return getOneMinSignal()?.color ?? .green
    }
}
