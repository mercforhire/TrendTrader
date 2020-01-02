//
//  SimTradingViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-19.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Cocoa

class SimTradingViewController: NSViewController {
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
    private var latestProcessedTimeKey: String?
    
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

    override func viewWillAppear() {
        super.viewWillAppear()
        preferredContentSize = NSSize(width: 860, height: 480)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupUI()
        
        systemClockTimer = Timer.scheduledTimer(timeInterval: TimeInterval(1.0), target: self, selector: #selector(updateSystemTimeLabel), userInfo: nil, repeats: true)
        dataManager = ChartManager()
        dataManager?.delegate = self
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
                
                if self.dataManager?.simulateTimePassage ?? false {
                    self.startButton.isEnabled = true
                }
            }
            
            sender.isEnabled = true
        })
    }
    
    @IBAction
    private func startMonitoring(_ sender: NSButton) {
        guard trader != nil, let realTimeChart = trader?.chart, !realTimeChart.timeKeys.isEmpty else {
            return
        }
        
        beginningButton.isEnabled = true
        startButton.isEnabled = false
        dataManager?.startMonitoring()
    }
    
    @IBAction
    private func restartSimulation(_ sender: Any) {
        dataManager?.stopMonitoring()
        dataManager?.subsetChart = nil
        sessionManager.resetSession()
        listOfTrades?.removeAll()
        
        simTimeLabel.stringValue = "--:--"
        totalPLLabel.stringValue = "Total P/L: --"
        beginningButton.isEnabled = false
        endButton.isEnabled = true
        if dataManager?.simulateTimePassage ?? false {
            startButton.isEnabled = true
        }
        tableView.reloadData()
    }
    
    @IBAction
    private func goToEndOfDay(_ sender: Any) {
        guard trader != nil, let completedChart = dataManager?.chart, !completedChart.timeKeys.isEmpty
        else { return }
        
        beginningButton.isEnabled = true
        endButton.isEnabled = false
        if dataManager?.simulateTimePassage ?? false {
            startButton.isEnabled = true
        }
        
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
            let timeKey = chart.lastTimeKey else {
                return
        }
        
        trader?.chart = chart
        
        if let actions = trader?.decide(), latestProcessedTimeKey != chart.lastTimeKey {
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
                case .updatedStop(let stopLoss):
                    print(String(format: "Updated stop loss to %.2f", stopLoss.stop))
                }
            }
            sessionManager.processActions(actions: actions) { networkError in
                self.updateTradesList()
                self.latestProcessedTimeKey = chart.lastTimeKey
            }
        }
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

extension SimTradingViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return listOfTrades?.count ?? 0
    }
}

extension NSUserInterfaceItemIdentifier {
    static let TypeCell = NSUserInterfaceItemIdentifier("TypeCellID")
    static let EntryCell = NSUserInterfaceItemIdentifier("EntryCellID")
    static let StopCell = NSUserInterfaceItemIdentifier("StopCellID")
    static let ExitCell = NSUserInterfaceItemIdentifier("ExitCellID")
    static let PAndLCell = NSUserInterfaceItemIdentifier("PAndLCellID")
    static let EntryTimeCell = NSUserInterfaceItemIdentifier("EntryCellID")
    static let ExitTimeCell = NSUserInterfaceItemIdentifier("ExitTimeCellID")
}
