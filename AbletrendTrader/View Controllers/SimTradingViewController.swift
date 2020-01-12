//
//  SimTradingViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-19.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Cocoa

class SimTradingViewController: NSViewController {
    private let config = Config.shared
    
    @IBOutlet weak var systemTimeLabel: NSTextField!
    @IBOutlet weak var refreshDataButton: NSButton!
    @IBOutlet weak var latestDataTimeLabel: NSTextField!
    @IBOutlet weak var simTimeLabel: NSTextField!
    @IBOutlet weak var beginningButton: NSButton!
    @IBOutlet weak var startButton: NSButton!
    @IBOutlet weak var endButton: NSButton!
    @IBOutlet weak var totalPLLabel: NSTextField!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var chartButton: NSButton!
    
    private var dataManager: ChartManager?
    private let dateFormatter = DateFormatter()
    private var systemClockTimer: Timer!
    private var trader: TraderBot?
    private let sessionManager = SessionManager(live: false)
    private var listOfTrades: [TradesTableRowItem]?
    
    weak var delegate: DataManagerDelegate?
    
    func setupUI() {
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = Date.DefaultTimeZone
        
        latestDataTimeLabel.stringValue = "Latest data time: --:--"
        systemTimeLabel.stringValue = "--:--"
        simTimeLabel.stringValue = "--:--"
        
        beginningButton.isEnabled = false
        startButton.isEnabled = false
        endButton.isEnabled = false
        
        tableView.delegate = self
        tableView.dataSource = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupUI()
        
        systemClockTimer = Timer.scheduledTimer(timeInterval: TimeInterval(1.0), target: self, selector: #selector(updateSystemTimeLabel), userInfo: nil, repeats: true)
        dataManager = ChartManager(live: false)
        dataManager?.delegate = self
        sessionManager.initialize()
    }
    
    @objc
    private func updateSystemTimeLabel() {
        systemTimeLabel.stringValue = dateFormatter.string(from: Date())
    }
    
    private func updateLatestDataTimeLabel(chart: Chart?) {
        if let chart = chart, let lastDate = chart.absLastBarDate {
            latestDataTimeLabel.stringValue = "Latest data time: " + dateFormatter.string(from: lastDate)
        } else {
            latestDataTimeLabel.stringValue = "Latest data time: --:--"
        }
    }
    
    @IBAction
    private func refreshChartData(_ sender: NSButton) {
        dataManager?.stopMonitoring()
        updateLatestDataTimeLabel(chart: nil)
        sender.isEnabled = false
        
        dataManager?.fetchChart(completion: {  [weak self] chart in
            guard let self = self else { return }
            
            if let chart = chart {
                self.updateLatestDataTimeLabel(chart: chart)
                self.sessionManager.resetSession()
                self.trader = TraderBot(chart: chart, sessionManager: self.sessionManager)
                self.endButton.isEnabled = true
                self.startButton.isEnabled = self.config.simulateTimePassage
            }
            
            sender.isEnabled = true
        })
    }
    
    @IBAction
    private func startMonitoring(_ sender: NSButton) {
        beginningButton.isEnabled = true
        startButton.isEnabled = false
        dataManager?.startMonitoring()
    }
    
    @IBAction
    private func restartSimulation(_ sender: Any) {
        dataManager?.stopMonitoring()
        dataManager?.resetSimTime()
        sessionManager.resetSession()
        listOfTrades?.removeAll()
        simTimeLabel.stringValue = "--:--"
        totalPLLabel.stringValue = "Total P/L: --"
        beginningButton.isEnabled = false
        endButton.isEnabled = true
        startButton.isEnabled = config.simulateTimePassage
        tableView.reloadData()
    }
    
    @IBAction
    private func goToEndOfDay(_ sender: Any) {
        guard trader != nil, let completedChart = dataManager?.chart, !completedChart.timeKeys.isEmpty
        else { return }
        
        beginningButton.isEnabled = true
        endButton.isEnabled = false
        startButton.isEnabled = config.simulateTimePassage
        
        dataManager?.stopMonitoring()
        updateLatestDataTimeLabel(chart: completedChart)
        trader?.chart = completedChart
        trader?.generateSimSession(completion: { [weak self] in
            guard let self = self else { return }
            
            self.updateTradesList()
            self.delegate?.chartUpdated(chart: completedChart)
        })
    }
    
    private func updateTradesList() {
        listOfTrades = sessionManager.listOfTrades()
        tableView.reloadData()
        totalPLLabel.stringValue = String(format: "Total P/L: %.2f", sessionManager.getTotalPAndL())
        
        if let lastSimTime = trader?.chart.lastBar?.time {
            simTimeLabel.stringValue = dateFormatter.string(from: lastSimTime)
        }
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let chartVC = segue.destinationController as? ChartViewController, let chart = trader?.chart {
            chartVC.chart = chart
            delegate = chartVC
        }
    }
}

extension SimTradingViewController: DataManagerDelegate {
    func chartUpdated(chart: Chart) {
        updateLatestDataTimeLabel(chart: chart)
        delegate?.chartUpdated(chart: chart)
        
        guard !chart.timeKeys.isEmpty,
            let lastBarTime = chart.lastBar?.time else {
                return
        }
        
        trader?.chart = chart
        
        if let actions = trader?.decide() {
            sessionManager.processActions(priceBarTime: lastBarTime, actions: actions) { networkError in
                self.updateTradesList()
            }
        }
    }
    
    func requestStopMonitoring() {
        startButton.isEnabled = true
    }
}

extension SimTradingViewController: NSTableViewDelegate {
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
            text = trade.stop
            cellIdentifier = .StopCell
        } else if tableColumn == tableView.tableColumns[3] {
            text = trade.iExit
            cellIdentifier = .IdealExitCell
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

extension SimTradingViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return listOfTrades?.count ?? 0
    }
}

extension NSUserInterfaceItemIdentifier {
    static let TypeCell = NSUserInterfaceItemIdentifier("TypeCellID")
    static let IdealEntryCell = NSUserInterfaceItemIdentifier("IdealEntryCellID")
    static let ActualEntryCell = NSUserInterfaceItemIdentifier("ActualEntryCellID")
    static let StopCell = NSUserInterfaceItemIdentifier("StopCellID")
    static let IdealExitCell = NSUserInterfaceItemIdentifier("IdealExitCellID")
    static let ActualExitCell = NSUserInterfaceItemIdentifier("ActualExitCellID")
    static let PAndLCell = NSUserInterfaceItemIdentifier("PAndLCellID")
    static let EntryTimeCell = NSUserInterfaceItemIdentifier("EntryCellID")
    static let ExitTimeCell = NSUserInterfaceItemIdentifier("ExitTimeCellID")
}
