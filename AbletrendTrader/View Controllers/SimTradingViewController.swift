//
//  SimTradingViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-19.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Cocoa

class SimTradingViewController: NSViewController, NSTextFieldDelegate, NSWindowDelegate {
    private let config = ConfigurationManager.shared
    
    @IBOutlet weak var server1MinURLField: NSTextField!
    @IBOutlet weak var server2MinAnd3MinURLField: NSTextField!
    @IBOutlet weak var systemTimeLabel: NSTextField!
    @IBOutlet weak var refreshDataButton: NSButton!
    @IBOutlet weak var latestDataTimeLabel: NSTextField!
    @IBOutlet weak var simTimeLabel: NSTextField!
    @IBOutlet weak var beginningButton: NSButton!
    @IBOutlet weak var startButton: NSButton!
    @IBOutlet weak var endButton: NSButton!
    @IBOutlet weak var totalPLLabel: NSTextField!
    @IBOutlet weak var tableView: NSTableView!
    
    private var server1minURL: String = "" {
        didSet {
            chartManager?.serverUrls[SignalInteval.oneMin] = server1minURL
        }
    }
    private var server2minURL: String = "" {
        didSet {
            chartManager?.serverUrls[SignalInteval.twoMin] = server2minURL
        }
    }
    private var server3minURL: String = "" {
        didSet {
            chartManager?.serverUrls[SignalInteval.threeMin] = server3minURL
        }
    }
    
    private var chartManager: ChartManager?
    private let dateFormatter = DateFormatter()
    private var systemClockTimer: Timer!
    private var trader: TraderBot?
    private let sessionManager = SimSessionManager()
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
        simTimeLabel.stringValue = "--:--"
        
        beginningButton.isEnabled = false
        startButton.isEnabled = false
        endButton.isEnabled = false
        
        tableView.delegate = self
        tableView.dataSource = self
        server1MinURLField.delegate = self
        server2MinAnd3MinURLField.delegate = self
        
        server1minURL = config.server1MinURL
        server2minURL = config.server2MinURL
        server3minURL = config.server3MinURL
        server1MinURLField.stringValue = server1minURL
        server2MinAnd3MinURLField.stringValue = server2minURL
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupUI()
        systemClockTimer = Timer.scheduledTimer(timeInterval: TimeInterval(1.0),
                                                target: self,
                                                selector: #selector(updateSystemTimeLabel),
                                                userInfo: nil,
                                                repeats: true)
        
        var serverUrls: [SignalInteval: String] = [:]
        serverUrls[SignalInteval.oneMin] = server1minURL
        serverUrls[SignalInteval.twoMin] = server2minURL
        serverUrls[SignalInteval.threeMin] = server3minURL
        chartManager = ChartManager(live: false, serverUrls: serverUrls)
        chartManager?.delegate = self
        sessionManager.delegate = self
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        view.window?.delegate = self
    }
    
    @objc
    private func updateSystemTimeLabel() {
        systemTimeLabel.stringValue = dateFormatter.string(from: Date())
    }
    
    @IBAction
    private func refreshChartData(_ sender: NSButton) {
        chartManager?.stopMonitoring()
        sender.isEnabled = false
        
        chartManager?.fetchChart(completion: {  [weak self] chart in
            guard let self = self else { return }
            
            if let chart = chart {
                self.trader = TraderBot(chart: chart, sessionManager: self.sessionManager, commmission: 2.0)
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
        chartManager?.startMonitoring()
    }
    
    @IBAction
    private func restartSimulation(_ sender: Any) {
        chartManager?.stopMonitoring()
        chartManager?.resetSimTime()
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
        guard trader != nil, let completedChart = chartManager?.chart, !completedChart.timeKeys.isEmpty
        else { return }
        
        beginningButton.isEnabled = true
        endButton.isEnabled = false
        startButton.isEnabled = config.simulateTimePassage
        
        chartManager?.stopMonitoring()
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
        
        var currentPL = 0.0
        for trade in sessionManager.trades {
            currentPL += trade.idealProfit
            print(String(format: "%.2f", currentPL))
        }
        
        for trade in sessionManager.trades {
            print(trade.exitTime.generateDate())
        }
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let logVc = segue.destinationController as? TradingLogViewController {
            self.logViewController = logVc
            self.logViewController?.log = log
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        chartManager?.stopMonitoring()
        sessionManager.stopLiveMonitoring()
        systemClockTimer.invalidate()
        systemClockTimer =  nil
    }
}

extension SimTradingViewController: DataManagerDelegate {
    func chartStatusChanged(statusText: String) {
        latestDataTimeLabel.stringValue = statusText
    }
    
    func chartUpdated(chart: Chart) {
        delegate?.chartUpdated(chart: chart)
        
        guard !chart.timeKeys.isEmpty, let lastBarTime = chart.lastBar?.time else {
                return
        }
        
        trader?.chart = chart
        
        if let actions = trader?.decide() {
            sessionManager.processActions(priceBarTime: lastBarTime, actions: actions, completion: { _ in
                self.updateTradesList()
            })
        }
    }
    
    func requestStopMonitoring() {
        startButton.isEnabled = true
        chartManager?.stopMonitoring()
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

extension SimTradingViewController: SessionManagerDelegate {
    func newLogAdded(log: String) {
        if self.log.count == 0 {
            self.log = log
        } else {
            self.log = "\(self.log)\n\(log)"
        }
    }
    
    func positionStatusChanged() {
    }
}

extension SimTradingViewController: NSControlTextEditingDelegate {
    func controlTextDidEndEditing(_ notification: Notification) {
        if let textField = notification.object as? NSTextField {
            do {
                if textField == server1MinURLField {
                    try config.setServer1MinURL(newValue: textField.stringValue)
                    server1minURL = textField.stringValue
                } else if textField == server2MinAnd3MinURLField {
                    try config.setServer2MinURL(newValue: textField.stringValue)
                    try config.setServer3MinURL(newValue: textField.stringValue)
                    server2minURL = textField.stringValue
                    server3minURL = textField.stringValue
                }
            } catch (let error) {
                guard let configError = error as? ConfigError else { return }
                
                configError.displayErrorDialog()
                
                if textField == server1MinURLField {
                    textField.stringValue = server1minURL
                } else if textField == server2MinAnd3MinURLField {
                    textField.stringValue = server2minURL
                }
                
            }
        }
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
    static let CommissionCell = NSUserInterfaceItemIdentifier("CommissionCellID")
}
