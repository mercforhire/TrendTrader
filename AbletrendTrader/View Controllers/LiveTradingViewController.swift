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
    @IBOutlet weak var buyButton: NSButton!
    @IBOutlet weak var sellButton: NSButton!
    
    private var dataManager: ChartManager?
    private let dateFormatter = DateFormatter()
    private var systemClockTimer: Timer!
    private var trader: TraderBot?
    private let sessionManager: SessionManager = SessionManager(live: true)
    private var listOfTrades: [TradesTableRowItem]?
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
    
    func setupUI() {
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = Date.DefaultTimeZone
        
        latestDataTimeLabel.stringValue = "Latest data time: --:--"
        systemTimeLabel.stringValue = "--:--"
        
        startButton.isEnabled = false
        pauseButton.isEnabled = false
        exitButton.isEnabled = false
        
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        setupUI()
        
        systemClockTimer = Timer.scheduledTimer(timeInterval: TimeInterval(1.0), target: self, selector: #selector(updateSystemTimeLabel), userInfo: nil, repeats: true)
        dataManager = ChartManager()
        dataManager?.delegate = self
    }
    
    @objc func updateSystemTimeLabel() {
        systemTimeLabel.stringValue = dateFormatter.string(from: Date())
    }
    
    private func updateTradesList() {
        listOfTrades = sessionManager.listOfTrades()
        tableView.reloadData()
        totalPLLabel.stringValue = String(format: "Total P/L: %.2f", sessionManager.getTotalPAndL())
    }
    
    @IBAction
    private func refreshData(_ sender: NSButton) {
        dataManager?.stopMonitoring()
        realTimeChart = nil
        sender.isEnabled = false
        
        let fetchingTask = DispatchGroup()
        
        fetchingTask.enter()
        dataManager?.fetchChart(completion: {  [weak self] chart in
            guard let self = self else { return }
            
            if let chart = chart {
                self.realTimeChart = chart
                self.trader = TraderBot(chart: chart, sessionManager: self.sessionManager)
            }
            
            fetchingTask.leave()
        })
        
        fetchingTask.enter()
        sessionManager.refreshIBSession(completionHandler: { result in
            fetchingTask.leave()
        })
        
        fetchingTask.notify(queue: DispatchQueue.main) { [weak self] in
            guard let self = self else { return }
            
            sender.isEnabled = true
        }
    }
    
    @IBAction
    private func startTrading(_ sender: NSButton) {
        guard trader != nil, let realTimeChart = realTimeChart, !realTimeChart.timeKeys.isEmpty
        else { return }
        
        startButton.isEnabled = false
        pauseButton.isEnabled = true
        dataManager?.startMonitoring()
    }
    
    @IBAction
    private func pauseTrading(_ sender: NSButton) {
        startButton.isEnabled = true
        pauseButton.isEnabled = false
        dataManager?.stopMonitoring()
    }
    
    @IBAction
    private func exitAllPosition(_ sender: NSButton) {
        sender.isEnabled = false
        sessionManager.exitPositions { success in
            sender.isEnabled = true
        }
    }
    
    @IBAction func buyPressed(_ sender: NSButton) {
        
    }
    
    @IBAction func sellPressed(_ sender: NSButton) {
        
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let chartVC = segue.destinationController as? ChartViewController {
            chartVC.chart = realTimeChart
            delegate = chartVC
        }
    }
}

extension LiveTradingViewController: DataManagerDelegate {
    func chartUpdated(chart: Chart) {
        realTimeChart = chart
        delegate?.chartUpdated(chart: chart)
        
        guard let realTimeChart = realTimeChart,
            !realTimeChart.timeKeys.isEmpty,
            let timeKey = realTimeChart.lastTimeKey else {
                return
        }
        
        trader?.chart = realTimeChart
        
        if let actions = trader?.decide(), latestProcessedTimeKey != realTimeChart.lastTimeKey {
            for action in actions {
                switch action {
                case .noAction:
                    print(String(format: "No action on %@", timeKey))
                case .openedPosition(let position):
                    let type: String = position.direction == .long ? "Long" : "Short"
                    print(String(format: "Opened %@ position on %@ at price %.2f with SL: %.2f", type, timeKey, position.entryPrice, position.stopLoss.stop))
                case .closedPosition(let trade):
                    let type: String = trade.direction == .long ? "Long" : "Short"
                    print(String(format: "Closed %@ position from %@ on %@ with P/L of %.2f", type, trade.entryTime?.generateShortDate() ?? "--", trade.exitTime.generateShortDate(), trade.profit ?? 0))
                case .updatedStop(let stoploss):
                    print(String(format: "Updated stop loss to %.2f", stoploss.stop))
                }
            }
            updateTradesList()
            latestProcessedTimeKey = realTimeChart.lastTimeKey
        }
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
            text = trade.entry
            cellIdentifier = .EntryCell
        } else if tableColumn == tableView.tableColumns[2] {
            text = trade.stop
            cellIdentifier = .StopCell
        } else if tableColumn == tableView.tableColumns[3] {
            text = trade.exit
            cellIdentifier = .ExitCell
        } else if tableColumn == tableView.tableColumns[4] {
            text = trade.pAndL
            cellIdentifier = .PAndLCell
        } else if tableColumn == tableView.tableColumns[5] {
            text = trade.entryTime
            cellIdentifier = .EntryTimeCell
        } else if tableColumn == tableView.tableColumns[6] {
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
