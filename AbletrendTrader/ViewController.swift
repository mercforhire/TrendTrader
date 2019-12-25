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
    @IBOutlet weak var backButton: NSButton!
    @IBOutlet weak var startButton: NSButton!
    @IBOutlet weak var pauseButton: NSButton!
    @IBOutlet weak var nextButton: NSButton!
    @IBOutlet weak var endButton: NSButton!
    @IBOutlet weak var totalPLLabel: NSTextField!
    
    
    // Configuration:
    @IBOutlet weak var maxSLField: NSTextField!
    @IBOutlet weak var minSTPField: NSTextField!
    @IBOutlet weak var sweetspotDistanceField: NSTextField!
    @IBOutlet weak var minProfitGreenBarField: NSTextField!
    @IBOutlet weak var minProfitPullbackField: NSTextField!
    @IBOutlet weak var highRiskEntryStartPicker: NSDatePicker!
    @IBOutlet weak var highRiskEntryEndPicker: NSDatePicker!
    @IBOutlet weak var sessionStartTimePIcker: NSDatePicker!
    @IBOutlet weak var liquidateTimePicker: NSDatePicker!
    @IBOutlet weak var flatTimePicker: NSDatePicker!
    @IBOutlet weak var dailyLossLimitPicker: NSTextField!
    

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
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
            
            let chartBuilder = ChartBuilder()
            
            if let chart = chartBuilder.generateChart(ticker: "NQ", candleSticks: candleSticks, indicatorsSet: [oneMinIndicators, twoMinIndicators, threeMinIndicators]) {
                let trader = Trader(chart: chart)
                trader.newSession(startTime: chart.startDate!, cutOffTime: chart.lastDate!)
                if let session: Session = trader.generateSession() {
                    for trade in session.trades {
                        print(trade.summary())
                    }
                    print(String(format: "Total P/L is %.2f", session.getTotalPAndL()))
                }
            }
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}
