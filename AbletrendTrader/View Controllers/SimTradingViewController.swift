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
    @IBOutlet weak var server2MinURLField: NSTextField!
    @IBOutlet weak var server3MinURLField: NSTextField!
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
    private var serverUrls: [SignalInteval: String] {
        return [SignalInteval.oneMin: server1minURL, SignalInteval.twoMin: server2minURL, SignalInteval.threeMin: server3minURL]
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
    
    var tradingSetting: TradingSettings!
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
        server2MinURLField.delegate = self
        server3MinURLField.delegate = self
        
        server1minURL = config.server1MinURL
        server2minURL = config.server2MinURL
        server3minURL = config.server3MinURL
        
        server1MinURLField.stringValue = server1minURL
        server2MinURLField.stringValue = server2minURL
        server3MinURLField.stringValue = server3minURL
        
        systemClockTimer = Timer.scheduledTimer(timeInterval: TimeInterval(1.0),
                                                target: self,
                                                selector: #selector(updateSystemTimeLabel),
                                                userInfo: nil,
                                                repeats: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tradingSetting = config.tradingSettings[config.tradingSettingsSelection]
        setupUI()
        
        chartManager = ChartManager(live: false, serverUrls: serverUrls, tradingSetting: tradingSetting)
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
        
        chartManager?.fetchChart(completion: { [weak self] chart in
            guard let self = self else { return }
            
            if let chart = chart {
                self.trader = TraderBot(chart: chart, sessionManager: self.sessionManager, tradingSetting: self.tradingSetting)
                self.endButton.isEnabled = true
                self.startButton.isEnabled = self.tradingSetting.simulateTimePassage
            }
            
            sender.isEnabled = true
        })
    }
    
    @IBAction
    func loadFromDiskPressed(_ sender: NSButton) {
        chartManager?.loadChart(completion: { [weak self] chart in
            guard let self = self else { return }
            
            if let chart = chart {
                self.trader = TraderBot(chart: chart, sessionManager: self.sessionManager, tradingSetting: self.tradingSetting)
                self.endButton.isEnabled = true
                self.startButton.isEnabled = self.tradingSetting.simulateTimePassage
                
                if self.testing {
                    self.goToEndOfDay(self.endButton as Any)
                }
            }
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
        startButton.isEnabled = tradingSetting.simulateTimePassage
        tableView.reloadData()
    }
    
    private let testing = true
    @IBAction private func goToEndOfDay(_ sender: Any) {
        guard trader != nil, let completedChart = chartManager?.chart, !completedChart.timeKeys.isEmpty
        else { return }
        
        beginningButton.isEnabled = true
        endButton.isEnabled = false
        startButton.isEnabled = tradingSetting.simulateTimePassage
        
        chartManager?.stopMonitoring()
        trader?.chart = completedChart
        
        if testing {
            var start = 5
            while start <= 7 {
                print("Testing numOfHoursToForget: \(start)...")
                trader?.tradingSetting.numOfHoursToForget = start
                trader?.generateSimSession(completion: { [weak self] in
                    guard let self = self else { return }

                    self.updateTradesList()
                    self.delegate?.chartUpdated(chart: completedChart)
                    print("")
                    start += 1
                })
            }
        } else {
            trader?.generateSimSession(completion: { [weak self] in
                guard let self = self else { return }

                self.updateTradesList()
                self.delegate?.chartUpdated(chart: completedChart)
                print("")
            })
        }
    }
    
    private func updateTradesList() {
        listOfTrades = sessionManager.listOfTrades()
        tableView.reloadData()
        totalPLLabel.stringValue = String(format: "Total P/L: %.2f", sessionManager.getTotalPAndL())
        
        if let lastSimTime = trader?.chart.lastBar?.time {
            simTimeLabel.stringValue = dateFormatter.string(from: lastSimTime)
        }
        
        var currentPL = 0.0
        var winningTrades = 0
        var totalWin = 0.0
        var losingTrades = 0
        var totalLoss = 0.0
        var worstPLDay = 0.0
        var worstPLDayTime: Date?
        var peak = 0.0
        var maxDD = 0.0
        
        var lastTrade: Trade?
        var currentDayPL = 0.0
        var count = 0
        var monday = 0.0
        var tuesday = 0.0
        var wednesday = 0.0
        var thursday = 0.0
        var friday = 0.0
        var morningTrades = 0.0
        var lunchTrades = 0.0
        
        if !testing {
            print("")
            print("P/L to date:")
        }
        
        for trade in sessionManager.trades {
            currentPL += trade.idealProfit
            peak = max(peak, currentPL)
            maxDD = max(maxDD, peak - currentPL)
            currentDayPL += trade.idealProfit
            
            if !testing {
                print(String(format: "%.2f", currentPL))
            }
            
            switch trade.entryTime.weekDay() {
            case 2:
                monday += trade.idealProfit
            case 3:
                tuesday += trade.idealProfit
            case 4:
                wednesday += trade.idealProfit
            case 5:
                thursday += trade.idealProfit
            case 6:
                friday += trade.idealProfit
            default:
                break
            }
            
            if tradingSetting.highRiskEntryInteval(date: trade.entryTime).contains(trade.entryTime.addingTimeInterval(-60)) {
                morningTrades += trade.idealProfit
            } else if tradingSetting.lunchInterval(date: trade.entryTime).contains(trade.entryTime.addingTimeInterval(-60)) {
                lunchTrades += trade.idealProfit
            }
            
            if trade.idealProfit <= 0 {
                losingTrades += 1
                totalLoss = totalLoss + abs(trade.idealProfit)
            } else {
                winningTrades += 1
                totalWin = totalWin + abs(trade.idealProfit)
            }
            
            count += 1
            
            if let lastTradeTime = lastTrade?.entryTime,
                lastTradeTime.day() != trade.entryTime.day(),
                count != sessionManager.trades.count {
                
                worstPLDayTime = currentDayPL < worstPLDay ? lastTradeTime : worstPLDayTime
                worstPLDay = min(worstPLDay, currentDayPL)
                currentDayPL = 0.0
            } else if count == sessionManager.trades.count {
                worstPLDayTime = currentDayPL < worstPLDay ? trade.entryTime : worstPLDayTime
                worstPLDay = min(worstPLDay, currentDayPL)
            }
            
            lastTrade = trade
        }
        
        if !testing {
            print("")
            print("Trade date:")
            for trade in sessionManager.trades {
                print(trade.exitTime.generateDate())
            }
            print("")
            print("Trade direction:")
            for trade in sessionManager.trades {
                print(trade.direction.description())
            }
            print("")
            print("Trade entry time:")
            for trade in sessionManager.trades {
                print(trade.entryTime.hourMinute())
            }
            print("")
            print("Trade entry price:")
            for trade in sessionManager.trades {
                print(trade.idealEntryPrice)
            }
            print("")
            print("Tradee exit time:")
            for trade in sessionManager.trades {
                print(trade.exitTime.hourMinute())
            }
            print("")
            print("Trade exit price:")
            for trade in sessionManager.trades {
                print(trade.idealExitPrice)
            }
            print("")
        }
        
        print("\(sessionManager.trades.count) trades", "P/L:", String(format: "%.2f", currentPL), "Max DD:", String(format: "%.2f", maxDD))
        print(String(format: "Win rate: %.2f", Double(winningTrades) / Double(sessionManager.trades.count) * 100), String(format: "Average win: %.2f", winningTrades == 0 ? 0 : totalWin / Double(winningTrades)), String(format: "Average loss: %.2f", losingTrades == 0 ? 0 : totalLoss / Double(losingTrades)))
        if let worstPLDayTime = worstPLDayTime {
            print("Worst day: \(String(format: "%.2f", worstPLDay)) on \(worstPLDayTime.generateDate())")
        }
        print("Monday: \(String(format: "%.2f", monday))")
        print("Tuesday: \(String(format: "%.2f", tuesday))")
        print("Wednesday: \(String(format: "%.2f", wednesday))")
        print("Thursday: \(String(format: "%.2f", thursday))")
        print("Friday: \(String(format: "%.2f", friday))")
        print("Morning P/L: \(String(format: "%.2f", morningTrades))")
        print("Lunch P/L: \(String(format: "%.2f", lunchTrades))")
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
        systemClockTimer = nil
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
            sessionManager.processActions(priceBarTime: lastBarTime,
                                          actions: actions,
                                          completion: { [weak self] _ in
                self?.updateTradesList()
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
                } else if textField == server2MinURLField {
                    try config.setServer2MinURL(newValue: textField.stringValue)
                    server2minURL = textField.stringValue
                } else if textField == server3MinURLField {
                    try config.setServer3MinURL(newValue: textField.stringValue)
                    server3minURL = textField.stringValue
                }
            } catch (let error) {
                guard let configError = error as? ConfigError else { return }
                
                configError.displayErrorDialog()
                
                if textField == server1MinURLField {
                    textField.stringValue = server1minURL
                } else if textField == server2MinURLField {
                    textField.stringValue = server2minURL
                } else if textField == server3MinURLField {
                    textField.stringValue = server3minURL
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
