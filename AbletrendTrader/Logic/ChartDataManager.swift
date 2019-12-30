//
//  DataManager.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-27.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation
import Alamofire

protocol DataManagerDelegate: class {
    func chartUpdated(chart: Chart)
}

class ChartDataManager {
    private let readFromServer = true
    
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
    var fetching = false
    
    init(updateFrequency: TimeInterval = 5) {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components1 = DateComponents(year: now.year(),
                                        month: now.month(),
                                        day: now.day(),
                                        hour: Config.shared.ChartStart.0,
                                        minute: Config.shared.ChartStart.1)
        self.chartStartTime = calendar.date(from: components1)!
        
        let components2 = DateComponents(year: now.year(),
                                        month: now.month(),
                                        day: now.day(),
                                        hour: Config.shared.ChartEnd.0,
                                        minute: Config.shared.ChartEnd.1)
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
                                                hour: Config.shared.ChartStart.0,
                                                minute: Config.shared.ChartStart.1)
                self.chartStartTime = calendar.date(from: components1)!
                
                let components2 = DateComponents(year: chartDate.year(),
                                                month: chartDate.month(),
                                                day: chartDate.day(),
                                                hour: Config.shared.ChartEnd.0,
                                                minute: Config.shared.ChartEnd.1)
                self.chartEndTime = calendar.date(from: components2)!
                
                self.chart = Chart.generateChart(ticker: "NQ",
                                                 candleSticks: candleSticks,
                                                 indicatorsSet: [oneMinIndicators, twoMinIndicators, threeMinIndicators],
                                                 startTime: self.chartStartTime,
                                                 cutOffTime: self.chartEndTime)
                
                _ = simulateMinPassed()
            }
        }
    }
    
    func fetchChart(completion: @escaping (_ chart: Chart?) -> Void) {
        if readFromServer {
            var oneMinUrl: String?
            var twoMinUrl: String?
            var threeMinUrl: String?
            
            let dispatchGroup1 = DispatchGroup()
            
            print("Fetching urls...")
            dispatchGroup1.enter()
            fetchLatestAvailableUrl(interval: .oneMin, completion: { url in
                oneMinUrl = url
                dispatchGroup1.leave()
            })
            
            dispatchGroup1.enter()
            fetchLatestAvailableUrl(interval: .twoMin, completion: { url in
                twoMinUrl = url
                dispatchGroup1.leave()
            })
            
            dispatchGroup1.enter()
            fetchLatestAvailableUrl(interval: .threeMin, completion: { url in
                threeMinUrl = url
                dispatchGroup1.leave()
            })
            
            dispatchGroup1.notify(queue: DispatchQueue.main) { [weak self] in
                guard let self = self,
                    let oneMinUrl = oneMinUrl,
                    let twoMinUrl = twoMinUrl,
                    let threeMinUrl = threeMinUrl else {
                    return
                }
                
                print("Fetched urls:", terminator:" ")
                print(oneMinUrl, terminator:" ")
                print(twoMinUrl, terminator:" ")
                print(threeMinUrl)
                
                let dispatchGroup2 = DispatchGroup()
                var hasError: Bool = false
                
                print("Fetching data...")
                dispatchGroup2.enter()
                self.downloadData(from: oneMinUrl) { data, response, error in
                    DispatchQueue.main.async() {
                        if let data = data {
                            self.oneMinText = String(decoding: data, as: UTF8.self)
                        } else if error != nil {
                            hasError = true
                        }
                        dispatchGroup2.leave()
                    }
                }
                
                dispatchGroup2.enter()
                self.downloadData(from: twoMinUrl) { data, response, error in
                    DispatchQueue.main.async() {
                        if let data = data {
                            self.twoMinText = String(decoding: data, as: UTF8.self)
                        } else if error != nil {
                            hasError = true
                        }
                        dispatchGroup2.leave()
                    }
                }
                
                dispatchGroup2.enter()
                self.downloadData(from: threeMinUrl) { data, response, error in
                    DispatchQueue.main.async() {
                        if let data = data {
                            self.threeMinText = String(decoding: data, as: UTF8.self)
                        } else if error != nil {
                            hasError = true
                        }
                        dispatchGroup2.leave()
                    }
                }
                
                dispatchGroup2.notify(queue: DispatchQueue.main) { [weak self] in
                    guard let self = self else { return }
                    
                    if hasError {
                        print("Data fetching failed")
                        completion(nil)
                    } else if let oneMinText = self.oneMinText, let twoMinText = self.twoMinText, let threeMinText = self.threeMinText {
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
                                                         startTime: self.chartStartTime,
                                                         cutOffTime: self.chartEndTime)
                        print("Data fetched, last bar: " + (self.chart?.absLastBarDate?.generateDateIdentifier() ?? ""))
                        completion(self.chart)
                    }
                }
            }
        } else {
            completion(subsetChart)
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
    
    private func downloadData(from url: String, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
        Alamofire.SessionManager.default.request(url).responseData { response in
            if let data = response.data {
                completion(data, nil, nil)
            } else {
                completion(nil, nil, nil)
            }
        }
    }
    
    private func fetchLatestAvailableUrl(interval: SignalInteval, completion: @escaping (String) -> ()) {
        let queue = DispatchQueue.global()
        queue.async {
            let semaphore = DispatchSemaphore(value: 0)
            var existUrl: String?
            
            while existUrl == nil {
                let now = Date()
                
                if now.second() < 5 {
                    sleep(1)
                    continue
                }
                
                for i in stride(from: now.second(), through: 0, by: -1) {
                    if existUrl != nil {
                        break
                    }
                    
                    let urlString: String = String(format: "%@%@_%02d-%02d-%02d.txt", Config.shared.dataServerURL, interval.text(), now.hour(), now.minute(), i)
                    
                    Alamofire.SessionManager.default.request(urlString).validate().response { response in
                        if response.response?.statusCode == 200 {
                            existUrl = urlString
                        }
                        semaphore.signal()
                    }
                    
                    semaphore.wait()
                }
                
                DispatchQueue.main.async {
                    if let existUrl = existUrl {
                        completion(existUrl)
                    }
                }
            }
        }
    }
}
