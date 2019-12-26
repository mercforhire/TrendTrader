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
    private let dateFormatter = DateFormatter()
    private var timer: Timer!
    private let chartBuilder = ChartBuilder()
    private var trader: Trader?
    // full chart containing all data points
    
    private var realTimeChart: Chart? {
        didSet {
            if let chart = realTimeChart, let lastDate = chart.lastDate {
                latestDataTimeLabel.stringValue = "Latest data time: " + dateFormatter.string(from: lastDate)
                startButton.isEnabled = true
            } else {
                latestDataTimeLabel.stringValue = "Latest data time: --:--"
                startButton.isEnabled = false
            }
        }
    }
    // all or subset of the full chart, simulating a particular moment during the session and used by the Trader algo
    
    private var chartStartTime: Date {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components = DateComponents(year: now.year(),
                                        month: now.month(),
                                        day: now.day(),
                                        hour: config.SessionChartStartTime.0,
                                        minute: config.SessionChartStartTime.1)
        let date: Date = calendar.date(from: components)!
        return date
    }
    private var chartEndTime: Date {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components = DateComponents(year: now.year(),
                                        month: now.month(),
                                        day: now.day(),
                                        hour: config.SessionChartEndTime.0,
                                        minute: config.SessionChartEndTime.1)
        let date: Date = calendar.date(from: components)!
        return date
    }
    
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
        loadConfig()
    }
    
    @objc func updateSystemTimeLabel() {
        systemTimeLabel.stringValue = dateFormatter.string(from: Date())
    }
    
    @IBAction func refreshChartData(_ sender: NSButton) {
        if let oneMinText = Parser.readFile(fileNane: Parser.fileName1),
            let twoMinText = Parser.readFile(fileNane: Parser.fileName2),
            let threeMinText = Parser.readFile(fileNane: Parser.fileName3) {
            
            let candleSticks = Parser.getPriceData(rawFileInput: oneMinText)
            let oneMinSignals = Parser.getSignalData(rawFileInput: oneMinText, inteval: .oneMin)
            let twoMinSignals = Parser.getSignalData(rawFileInput: twoMinText, inteval: .twoMin)
            let threeMinSignals = Parser.getSignalData(rawFileInput: threeMinText, inteval: .threeMin)
            
            let oneMinIndicators = Indicators(interval: .oneMin, signals: oneMinSignals)
            let twoMinIndicators = Indicators(interval: .twoMin, signals: twoMinSignals)
            let threeMinIndicators = Indicators(interval: .threeMin, signals: threeMinSignals)
            
            if let chart = chartBuilder.generateChart(ticker: "NQ",
                                                      candleSticks: candleSticks,
                                                      indicatorsSet: [oneMinIndicators, twoMinIndicators, threeMinIndicators],
                                                      startTime: chartStartTime,
                                                      cutOffTime: chartEndTime) {
                self.realTimeChart = chart
                self.trader = Trader(chart: Chart(ticker: chart.ticker), config: config)
            }
        }
    }
    
    @IBAction func incrementOneMinute(_ sender: NSButton) {
        guard trader != nil,
            let realTimeChart = realTimeChart,
            !realTimeChart.timeKeys.isEmpty,
            trader!.chart.timeKeys.count < realTimeChart.timeKeys.count
        else { return }
        
        if let simLatestTimeKey: String = trader!.chart.timeKeys.last,
            let realTimeChartIndex: Int = realTimeChart.timeKeys.firstIndex(of: simLatestTimeKey),
            realTimeChartIndex + 1 < realTimeChart.timeKeys.count {
            
            let nextTimeKey = realTimeChart.timeKeys[realTimeChartIndex + 1]
            guard let nextBar = realTimeChart.priceBars[nextTimeKey] else {
                return
            }
            
            trader!.addPriceBar(timeKey: nextTimeKey, priceBar: nextBar)
        } else {
            trader!.addPriceBar(timeKey: realTimeChart.startTimeKey!, priceBar: realTimeChart.startBar!)
        }
        
        guard let simChartLatestTimeKey: String = trader!.chart.lastTimeKey, let simChartLastBar: PriceBar = trader!.chart.priceBars[simChartLatestTimeKey] else {
            return
        }
        
        simTimeLabel.stringValue = dateFormatter.string(from: simChartLastBar.candleStick.time)
        
        for action in trader!.updateSession() {
            switch action {
            case .noAction:
                print(String(format: "No action on %@", simChartLatestTimeKey))
            case .openedPosition(let position):
                let type: String = position.direction == .long ? "Long" : "Short"
                print(String(format: "Opened %@ position on %@ at price %.2f with SL: %.2f", type, simChartLatestTimeKey, position.entryPrice, position.stopLoss.stop))
            case .closedPosition(let trade):
                let type: String = trade.direction == .long ? "Long" : "Short"
                print(String(format: "Closed %@ position from %@ on %@ with P/L of %.2f", type, trade.entry.identifier, trade.exit.identifier, trade.profit ?? 0))
            case .updatedStop(let position):
                print(String(format: "%@ updated stop loss to %.2f", position.currentBar.identifier, position.stopLoss.stop))
            }
        }
    }
    
    @IBAction func restartSimulation(_ sender: Any) {
    }
    
    @IBAction func goToEndOfDay(_ sender: Any) {
    }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}
