//
//  LiveTradingViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-30.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Cocoa

class LiveTradingViewController: NSViewController, NSWindowDelegate {

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
    
    private var dataManager: ChartManager?
    private let dateFormatter = DateFormatter()
    private var systemClockTimer: Timer!
    private var trader: TraderBot?
    private let sessionManager: SessionManager = SessionManager(live: true)
    private var listOfTrades: [TradesTableRowItem]?
    
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
        
        systemClockTimer = Timer.scheduledTimer(timeInterval: TimeInterval(1.0), target: self, selector: #selector(updateSystemTimeLabel), userInfo: nil, repeats: true)
        dataManager = ChartManager(live: true)
        dataManager?.delegate = self
        sessionManager.initialize()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        if dataManager?.monitoring ?? false {
            dataManager?.startMonitoring()
        }
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        dataManager?.stopMonitoring()
    }
    
    @objc func updateSystemTimeLabel() {
        systemTimeLabel.stringValue = dateFormatter.string(from: Date())
    }
    
    private func updateLatestDataTimeLabel(chart: Chart?) {
        if let chart = chart, let lastDate = chart.absLastBarDate {
            latestDataTimeLabel.stringValue = "Latest data time: " + dateFormatter.string(from: lastDate)
        } else {
            latestDataTimeLabel.stringValue = "Latest data time: --:--"
        }
    }
    
    private func updateTradesList() {
        listOfTrades = sessionManager.listOfTrades()
        tableView.reloadData()
        totalPLLabel.stringValue = String(format: "Total P/L: %.2f", sessionManager.getTotalPAndL())
        
        if sessionManager.currentPosition != nil {
            self.buyButton.isEnabled = false
            self.sellButton.isEnabled = false
        } else {
            self.buyButton.isEnabled = true
            self.sellButton.isEnabled = true
        }
    }
    
    @IBAction
    private func refreshData(_ sender: NSButton) {
        dataManager?.stopMonitoring()
        updateLatestDataTimeLabel(chart: nil)
        sender.isEnabled = false
        
        let fetchingTask = DispatchGroup()
        
        fetchingTask.enter()
        dataManager?.fetchChart(completion: { [weak self] chart in
            fetchingTask.leave()
            
            guard let self = self else { return }
            
            sender.isEnabled = true
            
            if let chart = chart {
                self.updateLatestDataTimeLabel(chart: chart)
                self.trader = TraderBot(chart: chart, sessionManager: self.sessionManager)
                
                if self.dataManager?.monitoring ?? false {
                    self.startButton.isEnabled = false
                    self.pauseButton.isEnabled = true
                } else {
                    self.startButton.isEnabled = true
                    self.pauseButton.isEnabled = false
                }
                
                self.exitButton.isEnabled = true
                self.sessionManager.startMonitoringLiveOrders()
            }
        })
        
        if Config.shared.liveTradingMode == .interactiveBroker {
            fetchingTask.enter()
            sessionManager.refreshIBSession(completionHandler: { [weak self] result in
                fetchingTask.leave()
                
                guard let self = self else { return }
                
                switch result {
                case .success(let success):
                    if success {
                        self.updateTradesList()
                    }
                case .failure(let networkError):
                    networkError.showDialog()
                }
            })
        }
        
        fetchingTask.notify(queue: DispatchQueue.main) {
            sender.isEnabled = true
        }
    }
    
    @IBAction
    private func startTrading(_ sender: NSButton) {
        guard trader != nil, let realTimeChart = trader?.chart, !realTimeChart.timeKeys.isEmpty
        else { return }
        
        startButton.isEnabled = false
        pauseButton.isEnabled = true
        dataManager?.startMonitoring()
        sessionManager.startMonitoringLiveOrders()
    }
    
    @IBAction
    private func pauseTrading(_ sender: NSButton) {
        startButton.isEnabled = true
        pauseButton.isEnabled = false
        dataManager?.stopMonitoring()
        sessionManager.stopMonitoringLiveOrders()
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
                networkError?.showDialog()
            }
        }
    }
    
    @IBAction func buyPressed(_ sender: NSButton) {
        guard let action = trader?.buyAtMarket() else { return }
        
        sender.isEnabled = false
        sessionManager.resetCurrentlyProcessingPriceBar()
        sessionManager.processActions(priceBarTime: Date(), actions: [action]) { [weak self] networkError in
            guard let self = self else { return }
            
            sender.isEnabled = true
            
            if let networkError = networkError {
                networkError.showDialog()
            } else {
                self.updateTradesList()
            }
        }
    }
    
    @IBAction func sellPressed(_ sender: NSButton) {
        guard let action = trader?.sellAtMarket() else { return }
        
        sender.isEnabled = false
        sessionManager.resetCurrentlyProcessingPriceBar()
        sessionManager.processActions(priceBarTime: Date(), actions: [action]) { [weak self] networkError in
            guard let self = self else { return }
            
            sender.isEnabled = true
            
            if let networkError = networkError {
                print("Network Error: ", networkError)
            } else {
                self.updateTradesList()
            }
        }
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let chartVC = segue.destinationController as? ChartViewController, let chart = trader?.chart {
            chartVC.chart = chart
            delegate = chartVC
        }
    }
}

extension LiveTradingViewController: DataManagerDelegate {
    func chartUpdated(chart: Chart) {
        updateLatestDataTimeLabel(chart: chart)
        delegate?.chartUpdated(chart: chart)
        
        guard !chart.timeKeys.isEmpty,
            let lastBarTime = chart.lastBar?.time else {
                return
        }
        
        trader?.chart = chart
        
        if let actions = trader?.decide(), dataManager?.monitoring ?? false {
            sessionManager.processActions(priceBarTime: lastBarTime, actions: actions) { networkError in
                if let networkError = networkError {
                    networkError.showDialog()
                } else {
                    self.updateTradesList()
                }
            }
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
            text = trade.pAndL
            cellIdentifier = .PAndLCell
        } else if tableColumn == tableView.tableColumns[7] {
            text = trade.entryTime
            cellIdentifier = .EntryTimeCell
        } else if tableColumn == tableView.tableColumns[8] {
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
