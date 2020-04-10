//
//  PriceBar.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-20.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation
import Charts

struct PriceBar {
    var identifier: String
    var candleStick: CandleStick
    var signals: [Signal]
    var time: Date {
        return candleStick.time
    }
    var oneMinSignal: Signal? {
        for signal in signals {
            if signal.inteval == .oneMin {
                return signal
            }
        }
        
        return nil
    }
    
    var twoMinSignal: Signal? {
        for signal in signals {
            if signal.inteval == .twoMin {
                return signal
            }
        }
        
        return nil
    }
    
    var threeMinSignal: Signal? {
        for signal in signals {
            if signal.inteval == .threeMin {
                return signal
            }
        }
        
        return nil
    }
    
    var barColor: SignalColor {
        return oneMinSignal?.color ?? .green
    }
    
    func getCandleStickData(x: Double) -> CandleChartDataEntry {
        return CandleChartDataEntry(x: x, shadowH: candleStick.high, shadowL: candleStick.low, open: candleStick.open, close: candleStick.close)
    }
}
