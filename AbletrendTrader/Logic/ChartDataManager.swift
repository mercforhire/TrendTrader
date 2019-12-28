//
//  DataManager.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-27.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

protocol DataManagerDelegate: class {
    func chartUpdated(chart: Chart)
}

class ChartDataManager {
    private let readFromServer = false
    private let simulateMinByMinData = true
    
    private var oneMinText: String?
    private var twoMinText: String?
    private var threeMinText: String?
    
    var chart: Chart?
    var subsetChart: Chart?
    
    private var chartStartTime: Date
    private var chartEndTime: Date
    
    private var updateFrequency: TimeInterval
    private var timer: Timer?
    
    weak var delegate: DataManagerDelegate?
    
    init(updateFrequency: TimeInterval = 10) {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components1 = DateComponents(year: now.year(),
                                        month: now.month(),
                                        day: now.day(),
                                        hour: Config.shared.SessionChartStartTime.0,
                                        minute: Config.shared.SessionChartStartTime.1)
        self.chartStartTime = calendar.date(from: components1)!
        
        let components2 = DateComponents(year: now.year(),
                                        month: now.month(),
                                        day: now.day(),
                                        hour: Config.shared.SessionChartEndTime.0,
                                        minute: Config.shared.SessionChartEndTime.1)
        self.chartEndTime = calendar.date(from: components2)!
        self.updateFrequency = updateFrequency
        
        if !readFromServer {
            if let oneMinText = Parser.readFile(fileName: Parser.fileName1),
                let twoMinText = Parser.readFile(fileName: Parser.fileName2),
                let threeMinText = Parser.readFile(fileName: Parser.fileName3) {
                
                let candleSticks = Parser.getPriceData(rawFileInput: oneMinText)
                let oneMinSignals = Parser.getSignalData(rawFileInput: oneMinText, inteval: .oneMin)
                let twoMinSignals = Parser.getSignalData(rawFileInput: twoMinText, inteval: .twoMin)
                let threeMinSignals = Parser.getSignalData(rawFileInput: threeMinText, inteval: .threeMin)
                let oneMinIndicators = Indicators(interval: .oneMin, signals: oneMinSignals)
                let twoMinIndicators = Indicators(interval: .twoMin, signals: twoMinSignals)
                let threeMinIndicators = Indicators(interval: .threeMin, signals: threeMinSignals)
                
                let chartDate: Date = candleSticks.last!.time
                
                let components1 = DateComponents(year: chartDate.year(),
                                                month: chartDate.month(),
                                                day: chartDate.day(),
                                                hour: Config.shared.SessionChartStartTime.0,
                                                minute: Config.shared.SessionChartStartTime.1)
                self.chartStartTime = calendar.date(from: components1)!
                
                let components2 = DateComponents(year: chartDate.year(),
                                                month: chartDate.month(),
                                                day: chartDate.day(),
                                                hour: Config.shared.SessionChartEndTime.0,
                                                minute: Config.shared.SessionChartEndTime.1)
                self.chartEndTime = calendar.date(from: components2)!
                
                self.chart = Chart.generateChart(ticker: "NQ",
                                                 candleSticks: candleSticks,
                                                 indicatorsSet: [oneMinIndicators, twoMinIndicators, threeMinIndicators],
                                                 startTime: Config.shared.ByPassTradingTimeRestrictions ? nil : self.chartStartTime,
                                                 cutOffTime: Config.shared.ByPassTradingTimeRestrictions ? nil : self.chartEndTime)
                
                if simulateMinByMinData {
                    _ = simulateMinPassed()
                }
            }
        }
    }
    
    func fetchChart(completion: @escaping (_ chart: Chart?) -> Void) {
        if readFromServer {
            let url = URL(string: Config.shared.dataServerURL)
            let dispatchGroup = DispatchGroup()
            var hasError: Bool = false
            
            dispatchGroup.enter()
            print("Fetching chart data...")
            getData(from: (url?.appendingPathComponent(Config.shared.fileName1))!) { data, response, error in
                DispatchQueue.main.async() {
                    if let data = data {
                        self.oneMinText = String(decoding: data, as: UTF8.self)
                    } else if error != nil {
                        hasError = true
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.enter()
            getData(from: (url?.appendingPathComponent(Config.shared.fileName2))!) { data, response, error in
                DispatchQueue.main.async() {
                    if let data = data {
                        self.twoMinText = String(decoding: data, as: UTF8.self)
                    } else if error != nil {
                        hasError = true
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.enter()
            getData(from: (url?.appendingPathComponent(Config.shared.fileName3))!) { data, response, error in
                DispatchQueue.main.async() {
                    if let data = data {
                        self.threeMinText = String(decoding: data, as: UTF8.self)
                    } else if error != nil {
                        hasError = true
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: DispatchQueue.main) { [weak self] in
                guard let self = self else { return }
                
                if hasError {
                    print("Chart data fetching failed")
                    completion(nil)
                } else if let oneMinText = self.oneMinText,
                            let twoMinText = self.twoMinText,
                            let threeMinText = self.threeMinText {
                    print("Chart data fetched")
                    let candleSticks = Parser.getPriceData(rawFileInput: oneMinText)
                    let oneMinSignals = Parser.getSignalData(rawFileInput: oneMinText, inteval: .oneMin)
                    let twoMinSignals = Parser.getSignalData(rawFileInput: twoMinText, inteval: .twoMin)
                    let threeMinSignals = Parser.getSignalData(rawFileInput: threeMinText, inteval: .threeMin)
                    let oneMinIndicators = Indicators(interval: .oneMin, signals: oneMinSignals)
                    let twoMinIndicators = Indicators(interval: .twoMin, signals: twoMinSignals)
                    let threeMinIndicators = Indicators(interval: .threeMin, signals: threeMinSignals)
                    
                    self.chart = Chart.generateChart(ticker: "NQ",
                                                     candleSticks: candleSticks,
                                                     indicatorsSet: [oneMinIndicators, twoMinIndicators, threeMinIndicators],
                                                     startTime: Config.shared.ByPassTradingTimeRestrictions ? nil : self.chartStartTime,
                                                     cutOffTime: Config.shared.ByPassTradingTimeRestrictions ? nil : self.chartEndTime)
                    completion(self.chart)
                }
            }
        } else if simulateMinByMinData {
            completion(subsetChart)
        } else {
            completion(chart)
        }
    }
    
    func startMonitoring() {
        if readFromServer {
            timer = Timer.scheduledTimer(timeInterval: updateFrequency, target: self, selector: #selector(updateChart), userInfo: self, repeats: true)
        } else {
            timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(0.05), repeats: true, block: { [weak self] timer in
                guard let self = self else { return }
                
                if !self.simulateMinPassed() {
                    timer.invalidate()
                } else {
                    if let subsetChart = self.subsetChart {
                        self.delegate?.chartUpdated(chart: subsetChart)
                    }
                }
            })
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
    }
    
    func simulateMinPassed() -> Bool {
        guard let chart = chart else { return false }
        
        if subsetChart == nil {
            subsetChart = Chart(ticker: chart.ticker)
        }
        
        let indexOfBarToAddToSubsetChart: Int = subsetChart?.timeKeys.count ?? 0
        
        guard indexOfBarToAddToSubsetChart < chart.timeKeys.count,
            let nextBar = chart.priceBars[chart.timeKeys[indexOfBarToAddToSubsetChart]] else {
                return false
        }
        
        subsetChart!.timeKeys.append(chart.timeKeys[indexOfBarToAddToSubsetChart])
        subsetChart!.priceBars[chart.timeKeys[indexOfBarToAddToSubsetChart]] = nextBar
        
        return true
    }
    
    @objc
    private func updateChart() {
        fetchChart { [weak self] chart in
            guard let self = self else { return }
            
            if let chart = chart {
                self.delegate?.chartUpdated(chart: chart)
            }
        }
    }
    
    private func getData(from url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
        URLSession.shared.dataTask(with: url, completionHandler: completion).resume()
    }
}
