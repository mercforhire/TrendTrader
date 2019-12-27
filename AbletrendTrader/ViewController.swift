//
//  ViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-19.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet weak var systemTimeLabel: NSTextField!
    @IBOutlet weak var refreshDataButton: NSButton!
    @IBOutlet weak var latestDataTimeLabel: NSTextField!
    @IBOutlet weak var simTimeLabel: NSTextField!
    @IBOutlet weak var beginningButton: NSButton!
    @IBOutlet weak var startButton: NSButton!
    @IBOutlet weak var endButton: NSButton!
    @IBOutlet weak var totalPLLabel: NSTextField!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var divider: NSView!
    
    // Configuration:
    @IBOutlet weak var maxSLField: NSTextField!
    @IBOutlet weak var minSTPField: NSTextField!
    @IBOutlet weak var sweetspotDistanceField: NSTextField!
    @IBOutlet weak var minProfitGreenBarField: NSTextField!
    @IBOutlet weak var minProfitByPass: NSTextField!
    @IBOutlet weak var minProfitPullbackField: NSTextField!
    @IBOutlet weak var highRiskEntryStartPicker: NSDatePicker!
    @IBOutlet weak var highRiskEntryEndPicker: NSDatePicker!
    @IBOutlet weak var sessionStartTimePicker: NSDatePicker!
    @IBOutlet weak var liquidateTimePicker: NSDatePicker!
    @IBOutlet weak var flatTimePicker: NSDatePicker!
    @IBOutlet weak var dailyLossLimitPicker: NSTextField!
    
    private var config = Config()
    private var dataManager: DataManager?
    private let dateFormatter = DateFormatter()
    private var timer: Timer!
    private var trader: Trader?
    private var listOfTrades: [TradeDisplayable]?
    
    private var realTimeChart: Chart? {
        didSet {
            if let chart = realTimeChart, let lastDate = chart.absLateBarData {
                latestDataTimeLabel.stringValue = "Latest data time: " + dateFormatter.string(from: lastDate)
                startButton.isEnabled = true
                endButton.isEnabled = true
            } else {
                latestDataTimeLabel.stringValue = "Latest data time: --:--"
                startButton.isEnabled = false
                beginningButton.isEnabled = false
                endButton.isEnabled = false
            }
        }
    }
    // all or subset of the full chart, simulating a particular moment during the session and used by the Trader algo
    
    func setupUI() {
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = Date.DefaultTimeZone
        
        latestDataTimeLabel.stringValue = "Latest data time: --:--"
        simTimeLabel.stringValue = "--:--"
        
        maxSLField.isEditable = false
        minSTPField.isEditable = false
        sweetspotDistanceField.isEditable = false
        minProfitGreenBarField.isEditable = false
        minProfitByPass.isEditable = false
        minProfitPullbackField.isEditable = false
        
        highRiskEntryStartPicker.isEnabled = false
        highRiskEntryEndPicker.isEnabled = false
        sessionStartTimePicker.isEnabled = false
        liquidateTimePicker.isEnabled = false
        flatTimePicker.isEnabled = false
        dailyLossLimitPicker.isEditable = false
        
        beginningButton.isEnabled = false
        startButton.isEnabled = false
        endButton.isEnabled = false
        
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    func loadConfig() {
        maxSLField.stringValue = String(format: "%.2f", config.MaxRisk)
        minSTPField.stringValue = String(format: "%.2f", config.MinBarStop)
        sweetspotDistanceField.stringValue = String(format: "%.2f", config.SweetSpotMinDistance)
        minProfitGreenBarField.stringValue = String(format: "%.2f", config.MinProfitToUseTwoGreenBarsExit)
        minProfitByPass.stringValue = String(format: "%.2f", config.ProfitRequiredAbandonTwoGreenBarsExit)
        minProfitPullbackField.stringValue = String(format: "%.2f", config.ProfitRequiredToReenterTradeonPullback)
        highRiskEntryStartPicker.dateValue = Date().getNewDateFromTime(hour: config.HighRiskEntryStartTime.0, min: config.HighRiskEntryStartTime.1)
        highRiskEntryEndPicker.dateValue = Date().getNewDateFromTime(hour: config.HighRiskEntryEndTime.0, min: config.HighRiskEntryEndTime.1)
        sessionStartTimePicker.dateValue = Date().getNewDateFromTime(hour: config.TradingSessionStartTime.0, min: config.TradingSessionStartTime.1)
        liquidateTimePicker.dateValue = Date().getNewDateFromTime(hour: config.ClearPositionTime.0, min: config.ClearPositionTime.1)
        flatTimePicker.dateValue = Date().getNewDateFromTime(hour: config.FlatPositionsTime.0, min: config.FlatPositionsTime.1)
        dailyLossLimitPicker.stringValue = String(format: "%.2f", config.MaxDailyLoss)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        preferredContentSize = NSSize(width: 860, height: 480)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupUI()
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(1.0), target: self, selector: #selector(updateSystemTimeLabel), userInfo: self, repeats: true)
        dataManager = DataManager(config: config)
        dataManager?.delegate = self
        loadConfig()
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
                self.trader = Trader(chart: chart, config: self.config)
            }
        })
    }
    
    @IBAction func startMonitoring(_ sender: NSButton) {
        guard trader != nil, let realTimeChart = realTimeChart, !realTimeChart.timeKeys.isEmpty
        else { return }
        
        startButton.isEnabled = false
        trader?.generateSession()
        updateTradesList()
        dataManager?.startMonitoring()
    }
    
    @IBAction func restartSimulation(_ sender: Any) {
        guard let chart = realTimeChart else { return }
        
        dataManager?.stopMonitoring()
        trader = Trader(chart: chart, config: self.config)
        listOfTrades?.removeAll()
        
        simTimeLabel.stringValue = "--:--"
        totalPLLabel.stringValue = "Total P/L: --"
        beginningButton.isEnabled = false
        endButton.isEnabled = true
        startButton.isEnabled = true
        tableView.reloadData()
    }
    
    @IBAction func goToEndOfDay(_ sender: Any) {
        guard trader != nil, let realTimeChart = realTimeChart, !realTimeChart.timeKeys.isEmpty
        else { return }
        
        dataManager?.stopMonitoring()
        trader?.generateSession()
        endButton.isEnabled = false
        startButton.isEnabled = true
        updateTradesList()
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
}

extension ViewController: DataManagerDelegate {
    func chartUpdated(chart: Chart) {
        self.realTimeChart = chart
        
        guard let realTimeChart = realTimeChart,
            !realTimeChart.timeKeys.isEmpty,
            let timeKey = realTimeChart.lastTimeKey else {
                return
        }
        
        trader?.chart = realTimeChart
        
        if let actions = trader?.process() {
            for action in actions {
                switch action {
                case .noAction:
                    break
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
        }
    }
}

extension ViewController: NSTableViewDelegate {
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

extension ViewController: NSTableViewDataSource {
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
