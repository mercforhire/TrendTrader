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
                
                var pAndL: Double = 0
                var lastTrade: Trade?
                for timeKey in chart.timeKeys {
                    guard let bar = chart.priceBars[timeKey],
                        chart.timeKeys.firstIndex(of: timeKey) ?? 0 >= 0 else { continue }
                    
                    if let lastTrade = lastTrade, bar.candleStick.time <= lastTrade.exit.candleStick.time {
                        continue
                    }
                    
                    var onGoingTrade: Position?
                    if let position = trader.checkForEntrySignal(direction: .long, bar: bar, entryType: .initial) {
                        print(String(format: "Initial buy at %@ - %.2f", position.entry.identifier, position.entryPrice), terminator: "")
                        onGoingTrade = position
                    }
                    else if let position = trader.checkForEntrySignal(direction: .short, bar: bar, entryType: .initial) {
                        print(String(format: "Initial short at %@ - %.2f", position.entry.identifier, position.entryPrice), terminator: "")
                        onGoingTrade = position
                    }
                    
                    if let onGoingTrade = onGoingTrade, let trade = trader.findExitPoint(direction: onGoingTrade.direction, entryBar: onGoingTrade.entry, entryPrice: onGoingTrade.entryPrice) {
                        lastTrade = trade
                        print(String(format: " closed at %@ - %.2f with P/L %.2f", trade.exit.identifier, trade.exitPrice, trade.profit ?? 0))
                        pAndL = pAndL + (trade.profit ?? 0)
                    }
                }
                print(String(format: "Total P/L is %.2f", pAndL))
            }
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

}

