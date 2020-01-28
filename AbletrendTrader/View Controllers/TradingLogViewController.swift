//
//  TradingLogViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-01-22.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Cocoa

class TradingLogViewController: NSViewController {
    @IBOutlet var logTextView: NSTextView!
    
    var log: String = "" {
        didSet {
            if logTextView != nil {
                logTextView.string = log
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        logTextView.string = log
    }
}
