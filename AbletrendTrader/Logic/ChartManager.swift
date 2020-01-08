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

class ChartManager {
    private let networkManager = NetworkManager.shared
    private var calendar = Calendar(identifier: .gregorian)
    private let config = Config.shared
    private var oneMinText: String?
    private var twoMinText: String?
    private var threeMinText: String?
   
    var chart: Chart?
    var subsetChart: Chart?
    
    private var updateFrequency: TimeInterval
    private var timer: Timer?
    
    weak var delegate: DataManagerDelegate?
    var fetching = false
    
    init(updateFrequency: TimeInterval = 10) {
        self.updateFrequency = updateFrequency
    }
    
    func fetchChart(completion: @escaping (_ chart: Chart?) -> Void) {
        if config.readFromServer {
            var oneMinUrl: String?
            var twoMinUrl: String?
            var threeMinUrl: String?
            
            let urlFetchingTask = DispatchGroup()
            
            urlFetchingTask.enter()
            networkManager.fetchLatestAvailableUrl(interval: .oneMin, completion: { url in
                oneMinUrl = url
                urlFetchingTask.leave()
            })
            
            urlFetchingTask.enter()
            networkManager.fetchLatestAvailableUrl(interval: .twoMin, completion: { url in
                twoMinUrl = url
                urlFetchingTask.leave()
            })
            
            urlFetchingTask.enter()
            networkManager.fetchLatestAvailableUrl(interval: .threeMin, completion: { url in
                threeMinUrl = url
                urlFetchingTask.leave()
            })
            
            urlFetchingTask.notify(queue: DispatchQueue.main) { [weak self] in
                guard let self = self,
                    let oneMinUrl = oneMinUrl,
                    let twoMinUrl = twoMinUrl,
                    let threeMinUrl = threeMinUrl else {
                    return
                }
                
                let chartFetchingTask = DispatchGroup()
                var hasError: Bool = false
                
                chartFetchingTask.enter()
                self.networkManager.downloadData(from: oneMinUrl, fileName: self.config.fileName1) { string, response, error in
                    DispatchQueue.main.async() {
                        if let string = string {
                            self.oneMinText = string
                        } else if error != nil {
                            hasError = true
                        }
                        chartFetchingTask.leave()
                    }
                }
                
                chartFetchingTask.enter()
                self.networkManager.downloadData(from: twoMinUrl, fileName: self.config.fileName2) { string, response, error in
                    DispatchQueue.main.async() {
                        if let string = string {
                            self.twoMinText = string
                        } else if error != nil {
                            hasError = true
                        }
                        chartFetchingTask.leave()
                    }
                }
                
                chartFetchingTask.enter()
                self.networkManager.downloadData(from: threeMinUrl, fileName: self.config.fileName3) { string, response, error in
                    DispatchQueue.main.async() {
                        if let string = string {
                            self.threeMinText = string
                        } else if error != nil {
                            hasError = true
                        }
                        chartFetchingTask.leave()
                    }
                }
                
                chartFetchingTask.notify(queue: DispatchQueue.main) { [weak self] in
                    guard let self = self else { return }
                    
                    if hasError {
                        print("Chart fetching failed")
                        completion(nil)
                    } else if let oneMinText = self.oneMinText, let twoMinText = self.twoMinText, let threeMinText = self.threeMinText {
                        
                        let candleSticks = Parser.getPriceData(rawFileInput: oneMinText)
                        let oneMinSignals = Parser.getSignalData(rawFileInput: oneMinText, inteval: .oneMin)
                        let twoMinSignals = Parser.getSignalData(rawFileInput: twoMinText, inteval: .twoMin)
                        let threeMinSignals = Parser.getSignalData(rawFileInput: threeMinText, inteval: .threeMin)
                        let oneMinIndicators = Indicators(interval: .oneMin, signals: oneMinSignals)
                        let twoMinIndicators = Indicators(interval: .twoMin, signals: twoMinSignals)
                        let threeMinIndicators = Indicators(interval: .threeMin, signals: threeMinSignals)
                    
                        self.subsetChart = nil
                        self.chart = Chart.generateChart(ticker: "NQ",
                                                         candleSticks: candleSticks,
                                                         indicatorsSet: [oneMinIndicators, twoMinIndicators, threeMinIndicators])
                        completion(self.chart)
                    }
                }
            }
        } else {
            if let oneMinText = Parser.readFile(fileName: config.fileName1),
                let twoMinText = Parser.readFile(fileName: config.fileName2),
                let threeMinText = Parser.readFile(fileName: config.fileName3) {
                
                let candleSticks = Parser.getPriceData(rawFileInput: oneMinText)
                let oneMinSignals = Parser.getSignalData(rawFileInput: oneMinText, inteval: .oneMin)
                let twoMinSignals = Parser.getSignalData(rawFileInput: twoMinText, inteval: .twoMin)
                let threeMinSignals = Parser.getSignalData(rawFileInput: threeMinText, inteval: .threeMin)
                let oneMinIndicators = Indicators(interval: .oneMin, signals: oneMinSignals)
                let twoMinIndicators = Indicators(interval: .twoMin, signals: twoMinSignals)
                let threeMinIndicators = Indicators(interval: .threeMin, signals: threeMinSignals)
                
                self.subsetChart = nil
                self.chart = Chart.generateChart(ticker: "NQ",
                                                 candleSticks: candleSticks,
                                                 indicatorsSet: [oneMinIndicators, twoMinIndicators, threeMinIndicators])
                
                _ = simulateMinPassed()
                
                if config.simulateTimePassage {
                    completion(subsetChart)
                } else {
                    completion(chart)
                }
            }
        }
    }
    
    func startMonitoring() {
        if config.readFromServer {
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
        if fetching {
            return
        }
        
        fetching = true
        fetchChart { [weak self] chart in
            guard let self = self else { return }
            
            if let chart = chart {
                self.delegate?.chartUpdated(chart: chart)
            }
            
            self.fetching = false
        }
    }
}