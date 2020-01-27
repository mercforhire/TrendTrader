//
//  LiveTradingViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-30.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Cocoa

class LiveTradingViewController: NSViewController, NSWindowDelegate {
    private let config = Config.shared
    
    @IBOutlet weak var systemTimeLabel: NSTextField!
    @IBOutlet weak var refreshDataButton: NSButton!
    @IBOutlet weak var latestDataTimeLabel: NSTextField!
    @IBOutlet weak var startButton: NSButton!
    @IBOutlet weak var pauseButton: NSButton!
    @IBOutlet weak var exitButton: NSButton!
    @IBOutlet weak var totalPLLabel: NSTextField!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var chartButton: NSButton!
    @IBOutlet weak var buyButton: NSButton!
    @IBOutlet weak var sellButton: NSButton!
    @IBOutlet weak var positionStatusLabel: NSTextField!
    
    private var chartManager: ChartManager?
    private let dateFormatter = DateFormatter()
    private var systemClockTimer: Timer!
    private var trader: TraderBot?
    private var sessionManager: BaseSessionManager!
    private var listOfTrades: [TradesTableRowItem]?
    private var logViewController: TradingLogViewController?
    private var log: String = "" {
        didSet {
            DispatchQueue.main.async {
                self.logViewController?.log = self.log
            }
        }
    }
    
    weak var delegate: DataManagerDelegate?
    
    func setupUI() {
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = Date.DefaultTimeZone
        
        latestDataTimeLabel.stringValue = "Latest data time: --:--"
        systemTimeLabel.stringValue = "--:--"
        
        startButton.isEnabled = false
        pauseButton.isEnabled = false
        exitButton.isEnabled = false
        buyButton.isEnabled = false
        sellButton.isEnabled = false
        
        tableView.delegate = self
        tableView.dataSource = self
        
        view.window?.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        setupUI()
        systemClockTimer = Timer.scheduledTimer(timeInterval: TimeInterval(1.0),
                                                target: self,
                                                selector: #selector(updateSystemTimeLabel),
                                                userInfo: nil,
                                                repeats: true)
        chartManager = ChartManager(live: true)
        chartManager?.delegate = self
        switch config.liveTradingMode {
        case .interactiveBroker:
            sessionManager = IBSessionManager()
        case .ninjaTrader:
            sessionManager = NTSessionManager()
        }
        sessionManager.delegate = self
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        if chartManager?.monitoring ?? false {
            chartManager?.startMonitoring()
        }
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        chartManager?.stopMonitoring()
    }
    
    @objc func updateSystemTimeLabel() {
        systemTimeLabel.stringValue = dateFormatter.string(from: Date())
    }
    
    private func updateTradesList() {
        listOfTrades = sessionManager.listOfTrades()
        tableView.reloadData()
        totalPLLabel.stringValue = String(format: "Total P/L: %.2f, %@",
                                          sessionManager.getTotalPAndL(),
                                          sessionManager.getTotalPAndLDollar().currency(true, showPlusSign: false))
    }
    
    @IBAction
    private func refreshData(_ sender: NSButton) {
        chartManager?.stopMonitoring()
        sender.isEnabled = false
        chartManager?.fetchChart(completion: { [weak self] chart in
            guard let self = self else { return }
            
            sender.isEnabled = true
            if let chart = chart {
                self.trader = TraderBot(chart: chart, sessionManager: self.sessionManager)
                
                if self.chartManager?.monitoring ?? false {
                    self.startButton.isEnabled = false
                    self.pauseButton.isEnabled = true
                } else {
                    self.startButton.isEnabled = true
                    self.pauseButton.isEnabled = false
                }
                
                self.exitButton.isEnabled = true
                self.buyButton.isEnabled = true
                self.sellButton.isEnabled = true
                self.sessionManager.startLiveMonitoring()
            }
        })
    }
    
    @IBAction
    private func startTrading(_ sender: NSButton) {
        guard trader != nil, let realTimeChart = trader?.chart, !realTimeChart.timeKeys.isEmpty
        else { return }
        
        startButton.isEnabled = false
        pauseButton.isEnabled = true
        chartManager?.startMonitoring()
        sessionManager.startLiveMonitoring()
        updateTradesList()
    }
    
    @IBAction
    private func pauseTrading(_ sender: NSButton) {
        startButton.isEnabled = true
        pauseButton.isEnabled = false
        chartManager?.stopMonitoring()
        sessionManager.stopLiveMonitoring()
    }
    
    @IBAction
    private func exitAllPosition(_ sender: NSButton) {
        guard let latestPrice = trader?.chart.absLastBar?.candleStick.close else { return }
        
        sender.isEnabled = false
        sessionManager.resetCurrentlyProcessingPriceBar()
        sessionManager.exitPositions(priceBarTime: Date(),
                                     idealExitPrice: latestPrice,
                                     exitReason: .manual)
        { [weak self] networkError in
            guard let self = self else { return }
            
            sender.isEnabled = true
            
            if networkError == nil {
                self.updateTradesList()
            } else {
                networkError?.printError()
            }
        }
    }
    
    private func processActions(time: Date = Date(), actions: [TradeActionType], completion: Action? = nil) {
        sessionManager.processActions(priceBarTime: time, actions: actions) { [weak self] networkError in
            guard let self = self else { return }
            
            if let networkError = networkError {
                networkError.printError()
            } else {
                self.updateTradesList()
            }
            
            completion?()
        }
    }
    
    @IBAction func buyPressed(_ sender: NSButton) {
        guard let action = trader?.buyAtMarket() else { return }
        
        sender.isEnabled = false
        sessionManager.resetCurrentlyProcessingPriceBar()
        processActions(actions: [action]) {
            sender.isEnabled = true
        }
    }
    
    @IBAction func sellPressed(_ sender: NSButton) {
        guard let action = trader?.sellAtMarket() else { return }
        
        sender.isEnabled = false
        sessionManager.resetCurrentlyProcessingPriceBar()
        processActions(actions: [action]) {
            sender.isEnabled = true
        }
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let chartVC = segue.destinationController as? ChartViewController, let chart = trader?.chart {
            chartVC.chart = chart
            delegate = chartVC
        } else if let logVc = segue.destinationController as? TradingLogViewController {
            self.logViewController = logVc
            self.logViewController?.log = log
        }
    }
}

extension LiveTradingViewController: DataManagerDelegate {
    func chartStatusChanged(statusText: String) {
        latestDataTimeLabel.stringValue = statusText
    }
    
    func chartUpdated(chart: Chart) {
        delegate?.chartUpdated(chart: chart)
        
        guard !chart.timeKeys.isEmpty,
            let lastBarTime = chart.lastBar?.time else {
                return
        }
        
        trader?.chart = chart
        
        if let actions = trader?.decide(), chartManager?.monitoring ?? false {
            processActions(time: lastBarTime, actions: actions)
        }
    }
    
    func requestStopMonitoring() {
        pauseTrading(self.pauseButton)
    }
}

extension LiveTradingViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let listOfTrades = listOfTrades else { return nil }
        
        var text: String = ""
        var cellIdentifier: NSUserInterfaceItemIdentifier = .TypeCell
         
        let trade: TradesTableRowItem = listOfTrades[row]
        
        if tableColumn == tableView.tableColumns[0] {
            text = trade.type
            cellIdentifier = .TypeCell
        } else if tableColumn == tableView.tableColumns[1] {
            text = trade.iEntry
            cellIdentifier = .IdealEntryCell
        } else if tableColumn == tableView.tableColumns[2] {
            text = trade.aEntry
            cellIdentifier = .ActualEntryCell
        } else if tableColumn == tableView.tableColumns[3] {
            text = trade.stop
            cellIdentifier = .StopCell
        } else if tableColumn == tableView.tableColumns[4] {
            text = trade.iExit
            cellIdentifier = .IdealExitCell
        } else if tableColumn == tableView.tableColumns[5] {
            text = trade.aExit
            cellIdentifier = .ActualExitCell
        } else if tableColumn == tableView.tableColumns[6] {
            text = trade.commission
            cellIdentifier = .CommissionCell
        } else if tableColumn == tableView.tableColumns[7] {
            text = trade.pAndL
            cellIdentifier = .PAndLCell
        } else if tableColumn == tableView.tableColumns[8] {
            text = trade.entryTime
            cellIdentifier = .EntryTimeCell
        } else if tableColumn == tableView.tableColumns[9] {
            text = trade.exitTime
            cellIdentifier = .ExitTimeCell
        }
        
        if let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        }
        
        return nil
    }
}

extension LiveTradingViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return listOfTrades?.count ?? 0
    }
}

extension LiveTradingViewController: SessionManagerDelegate {
    func newLogAdded(log: String) {
        if self.log.count == 0 {
            self.log = log
        } else {
            self.log = "\(log)\n\(self.log)"
        }
    }
    
    func positionStatusChanged() {
        updateTradesList()
        positionStatusLabel.stringValue = sessionManager.status?.status() ?? "Position: --"
    }
}
