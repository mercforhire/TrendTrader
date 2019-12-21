//
//  ViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-19.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

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
                trader.findEntrySignals(direction: .long)
            }
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

}

