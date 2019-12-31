//
//  LiveTradingViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-30.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Cocoa

class LiveTradingViewController: NSViewController {

    @IBOutlet weak var systemTimeLabel: NSTextField!
    @IBOutlet weak var refreshDataButton: NSButton!
    @IBOutlet weak var latestDataTimeLabel: NSTextField!
    @IBOutlet weak var startButton: NSButton!
    @IBOutlet weak var pauseButton: NSButton!
    @IBOutlet weak var exitButton: NSButton!
    @IBOutlet weak var totalPLLabel: NSTextField!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var chartButton: NSButton!
    
    private var dataManager: ChartDataManager?
    private let dateFormatter = DateFormatter()
    private var timer: Timer!
    private var trader: TraderBot?
    private var listOfTrades: [TradeDisplayable]?
    private var realTimeChart: Chart? {
        didSet {
            if let chart = realTimeChart, let lastDate = chart.absLastBarDate {
                latestDataTimeLabel.stringValue = "Latest data time: " + dateFormatter.string(from: lastDate)
            } else {
                latestDataTimeLabel.stringValue = "Latest data time: --:--"
            }
        }
    }
    
    weak var delegate: DataManagerDelegate?
    private var latestProcessedTimeKey: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
}
