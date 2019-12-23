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
                
                for timeKey in chart.timeKeys {
                    guard let bar = chart.priceBars[timeKey] else { continue }
                    
                    if let sweetSpot = trader.checkForPullback(direction: .long, start: bar) {
                        print(String(format: "%@ is a long sweet spot", sweetSpot.end))
                    }
                    
                    if let sweetSpot = trader.checkForPullback(direction: .short, start: bar) {
                        print(String(format: "%@ is a short sweet spot", sweetSpot.end))
                    }
                    
                    if trader.checkForSignalConfirmation(direction: .long, bar: bar) {
                        print(String(format: "%@ has buy confirmation", bar.identifier))
                    }
                    
                    if trader.checkForSignalConfirmation(direction: .short, bar: bar) {
                        print(String(format: "%@ has short confirmation", bar.identifier))
                    }
                }
                
                let barNumber1 = 124
                let previousLevel: Double = trader.findPreviousLevel(direction: .long, entryBar: chart.priceBars[chart.timeKeys[barNumber1]]!)
                print(String(format: "Previous level support for bar %d is %.2f", barNumber1, previousLevel))
                
                let barNumber2 = 47
                let previousLevel2: Double = trader.findPreviousLevel(direction: .short, entryBar: chart.priceBars[chart.timeKeys[barNumber2]]!)
                print(String(format: "Previous level resistance for bar %d is %.2f", barNumber2, previousLevel2))
            }
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

}

