//
//  SimTradingViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-19.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Cocoa

class ChartNotifications {
    static let ChartUpdated: Notification.Name = Notification.Name("ChartNotifications")
}

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
    } // all or subset of the full chart, simulating a particular moment during the session and used by the Trader algo
    
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
        
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(1.0), target: self, selector: #selector(updateSystemTimeLabel), userInfo: nil, repeats: true)
        dataManager = ChartDataManager()
        dataManager?.delegate = self
    }
    
    @objc func updateSystemTimeLabel() {
        systemTimeLabel.stringValue = dateFormatter.string(from: Date())
    }
    
    @IBAction func refreshChartData(_ sender: NSButton) {
        dataManager?.stopMonitoring()
        realTimeChart = nil
        
        dataManager?.fetchChart(completion: {  [weak self] chart in
            guard let self = self else { return }
            
            if let chart = chart {
                self.realTimeChart = chart
                self.trader = TraderBot(chart: chart)
                self.startButton.isEnabled = true
                self.endButton.isEnabled = true
            }
        })
    }
    
    @IBAction func startMonitoring(_ sender: NSButton) {
        guard trader != nil, let realTimeChart = realTimeChart, !realTimeChart.timeKeys.isEmpty
        else { return }
        
        beginningButton.isEnabled = true
        startButton.isEnabled = false
        trader?.generateSimSession()
        updateTradesList()
        dataManager?.startMonitoring()
    }
    
    @IBAction func restartSimulation(_ sender: Any) {
        guard let chart = realTimeChart else { return }
        
        dataManager?.stopMonitoring()
        trader = TraderBot(chart: chart)
        listOfTrades?.removeAll()
        
        simTimeLabel.stringValue = "--:--"
        totalPLLabel.stringValue = "Total P/L: --"
        beginningButton.isEnabled = false
        endButton.isEnabled = true
        startButton.isEnabled = true
        tableView.reloadData()
    }
    
    @IBAction func goToEndOfDay(_ sender: Any) {
        guard trader != nil, let completedChart = dataManager?.chart, !completedChart.timeKeys.isEmpty
        else { return }
        
        beginningButton.isEnabled = true
        endButton.isEnabled = false
        startButton.isEnabled = true
        
        dataManager?.stopMonitoring()
        realTimeChart = completedChart
        trader?.chart = completedChart
        trader?.generateSimSession()
        updateTradesList()
        delegate?.chartUpdated(chart: completedChart)
    }
    
    private func updateTradesList() {
        listOfTrades = trader!.session.listOfTrades()
        tableView.reloadData()
        totalPLLabel.stringValue = String(format: "Total P/L: %.2f", trader!.session.getTotalPAndL())
        
        if let lastSimTime = trader?.chart.lastBar?.candleStick.time {
            simTimeLabel.stringValue = dateFormatter.string(from: lastSimTime)
        }
    }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let chartVC = segue.destinationController as? ChartViewController {
            chartVC.chart = realTimeChart
            delegate = chartVC
        }
    }
}

extension SimTradingViewController: DataManagerDelegate {
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
                    print(String(format: "Closed %@ position from %@ on %@ with P/L of %.2f", type, trade.entry.identifier, trade.exit.identifier, trade.profit ?? 0))
                case .updatedStop(let position):
                    print(String(format: "%@ updated stop loss to %.2f", position.currentBar.identifier, position.stopLoss.stop))
                }
            }
            updateTradesList()
            latestProcessedTimeKey = realTimeChart.lastTimeKey
        }
    }
}

extension SimTradingViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let listOfTrades = listOfTrades else { return nil }
        
        var text: String = ""
        var cellIdentifier: NSUserInterfaceItemIdentifier = .TypeCell
         
        let trade: TradeDisplayable = listOfTrades[row]
        
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
