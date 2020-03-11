//
//  NTSettingsViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-03-08.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Cocoa

class NTSettingsViewController: NSViewController {
    let ntCommission = 1.60
    let ntTicker = "NQ 03-20"
    let ntName = "Globex"
    let ntAccountLongName = "NinjaTrader Continuum (Demo)"
    var ntBasePath = "/Users/lchen/Downloads/NinjaTrader/"
    var ntIncomingPath = "/Users/lchen/Downloads/NinjaTrader/incoming"
    var ntOutgoingPath = "/Users/lchen/Downloads/NinjaTrader/outgoing"
    var ntAccountName = "Sim101"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
}
