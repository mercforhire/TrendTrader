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
            
            if let chart = chartBuilder.generateChart(ticker: "NQ", candleSticks: candleSticks, indicatorsSet: [oneMinIndicators, twoMinIndicators, threeMinIndicators]),
                let startBar = chart.startBar {
                let trader = Trader(chart: chart)
                
                let longEntries = trader.findEntrySignals(direction: .long, start: startBar)
                let shortEntries = trader.findEntrySignals(direction: .short, start: startBar)
                
//                for longEntry in longEntries {
//                    guard let trade = trader.findExitPoint(direction: .long, entryBar: longEntry) else { continue }
//                    
//                    print(String(format: "Long entry from %.2f to %.2f", trade.entry.candleStick.close, trade.exit.candleStick.close))
//                }
//                
//                for shortEntry in shortEntries {
//                    guard let trade = trader.findExitPoint(direction: .short, entryBar: shortEntry) else { continue }
//                    
//                    print(String(format: "Short entry from %.2f to %.2f", trade.entry.candleStick.close, trade.exit.candleStick.close))
//                }
                
                let barNumber1 = 124
                let previousLevel: Double = trader.findPreviousLevel(direction: .long, entryBar: chart.priceBars[chart.timeKeys[barNumber1]]!)
                print(String(format: "Previous level support for bar %d is %.2f", barNumber1, previousLevel))
                
                let barNumber2 = 47
                let previousLevel2: Double = trader.findPreviousLevel(direction: .short, entryBar: chart.priceBars[chart.timeKeys[barNumber2]]!)
                print(String(format: "Previous level resistance for bar %d is %.2f", barNumber2, previousLevel2))
                
                let startingBarNumber = 15
                let endingBarNumber = 40
                if let startingBar = chart.priceBars[chart.timeKeys[startingBarNumber]],
                    let endingBar = chart.priceBars[chart.timeKeys[endingBarNumber]] {
                    let pair = trader.findPairOfGreenBarsWithHighestLow(start: startingBar, end: endingBar)
                    print(String(format: "The pair of green bars with highest low are at %@ and %@", pair?.0.identifier ?? "nil", pair?.1.identifier ?? "nil"))
                }
                
                let startingBarNumber1 = 69
                let endingBarNumber1 = 122
                if let startingBar = chart.priceBars[chart.timeKeys[startingBarNumber1]],
                    let endingBar = chart.priceBars[chart.timeKeys[endingBarNumber1]] {
                    let pair = trader.findPairOfGreenBarsWithLowestHigh(start: startingBar, end: endingBar)
                    print(String(format: "The pair of green bars with lowest high are at %@ and %@", pair?.0.identifier ?? "nil", pair?.1.identifier ?? "nil"))
                }
                
                let startingBarNumber2 = 149
                let endingBarNumber2 = 177
                if let startingBar = chart.priceBars[chart.timeKeys[startingBarNumber2]],
                    let endingBar = chart.priceBars[chart.timeKeys[endingBarNumber2]] {
                    
                    let sweetSpots = trader.findSweetSpots(start: startingBar, end: endingBar, direction: .long)
                    print(String(format: "Found %d series of green bars", sweetSpots.count))
                    
                    for sweetSpot in sweetSpots {
                        print(String(format: "Lowest point for sweetspot %@ is %.2f", sweetSpot.coloredBar.identifier, sweetSpot.getLowestPoint() ?? 0))
                    }
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

