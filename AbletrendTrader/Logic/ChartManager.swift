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
    func requestStopMonitoring()
}

class ChartManager {
    private let networkManager = NetworkManager.shared
    private let config = Config.shared
    
    weak var delegate: DataManagerDelegate?
    
    let live: Bool
    var chart: Chart?
    var simTime: Date!
    var monitoring = false
    
    init(live: Bool) {
        self.live = live
        resetSimTime()
    }
    
    func resetSimTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components1 = DateComponents(year: Date().year(),
                                         month: Date().month(),
                                         day: Date().day(),
                                         hour: 9,
                                         minute: 15)
        self.simTime = calendar.date(from: components1)!
    }
    
    func fetchChart(completion: @escaping (_ chart: Chart?) -> Void) {
        if live {            
            self.findLatestAvaiableUrls { [weak self] urls in
                guard let self = self,
                    let oneMinUrl = urls?.0,
                    let twoMinUrl = urls?.1,
                    let threeMinUrl = urls?.2 else {
                    return completion(nil)
                }
                
                self.downloadChartFromUrls(oneMinUrl: oneMinUrl, twoMinUrl: twoMinUrl, threeMinUrl: threeMinUrl, completion: completion)
            }
        } else {
            if config.simulateTimePassage {
                findFirstAvailableUrls { [weak self] urls in
                    guard let self = self else {
                        return
                    }
                    
                    if let urls = urls {
                        self.downloadChartFromUrls(oneMinUrl: urls.0,
                                                   twoMinUrl: urls.1,
                                                   threeMinUrl: urls.2)
                        { downloadedChart in
                            self.chart = downloadedChart
                            completion(downloadedChart)
                        }
                    } else {
                        completion(nil)
                    }
                }
            } else {
                if let oneMinText = Parser.readFile(fileName: config.fileName1),
                    let twoMinText = Parser.readFile(fileName: config.fileName2),
                    let threeMinText = Parser.readFile(fileName: config.fileName3) {
                    
                    generateChart(oneMinText: oneMinText, twoMinText: twoMinText, threeMinText: threeMinText)
                    completion(self.chart)
                } else {
                    print("Chart data reading failed")
                    completion(nil)
                }
            }
        }
    }
    
    func startMonitoring() {
        if live {
            updateChart()
        } else if config.simulateTimePassage {
            updateChart()
        }
        
        monitoring = true
    }
    
    func stopMonitoring() {
        monitoring = false
        currentPriceBarTime = nil
    }
    
    var currentPriceBarTime: Date?
    var fetchingChart = false
    
    @objc
    private func updateChart() {
        let now = Date()
        if monitoring, live, currentPriceBarTime?.isInSameMinute(date: now) ?? false {
            // call this again 5 seconds after the next minute
            let waitSeconds = 65.0 - Double(now.second())
            print("Skipped fetching chart at", now.hourMinuteSecond(), "will fetch again in", waitSeconds, "seconds")
            DispatchQueue.main.asyncAfter(deadline: .now() + waitSeconds) {
                self.updateChart()
            }
            return
        }
        
        if fetchingChart {
            return
        }
        
        print("Start fetching chart at", now.hourMinuteSecond(), terminator:"...")
        fetchingChart = true
        fetchChart { [weak self] chart in
            guard let self = self else { return }
            
            self.fetchingChart = false
            if let chart = chart {
                print("Fetched chart for the current minute at", Date().hourMinuteSecond())
                self.delegate?.chartUpdated(chart: chart)
                self.currentPriceBarTime = chart.absLastBarDate
                
                if self.monitoring {
                    if self.live {
                        // keep calling this until the latest chart is fetched
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.updateChart()
                        }
                    } else if self.config.simulateTimePassage {
                        guard self.simTime < Date() else {
                            print("Simulate time is up to date")
                            self.stopMonitoring()
                            self.delegate?.requestStopMonitoring()
                            return
                        }
                        self.updateChart()
                    }
                }
            } else if self.monitoring, self.live {
                print("Fetched chart for current minute yet not found at", Date().hourMinuteSecond())
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.updateChart()
                }
            }
        }
    }
    
    private func downloadChartFromUrls(oneMinUrl: String,
                                       twoMinUrl: String,
                                       threeMinUrl: String,
                                       completion: @escaping (_ chart: Chart?) -> Void) {
        var oneMinText: String?
        var twoMinText: String?
        var threeMinText: String?
        
        let chartFetchingTask = DispatchGroup()
        chartFetchingTask.enter()
        networkManager.downloadData(from: oneMinUrl, fileName: config.fileName1) { string, response, error in
            DispatchQueue.main.async() {
                if let string = string {
                    oneMinText = string
                }
                chartFetchingTask.leave()
            }
        }
        
        chartFetchingTask.enter()
        networkManager.downloadData(from: twoMinUrl, fileName: config.fileName2) { string, response, error in
            DispatchQueue.main.async() {
                if let string = string {
                    twoMinText = string
                }
                chartFetchingTask.leave()
            }
        }
        
        chartFetchingTask.enter()
        networkManager.downloadData(from: threeMinUrl, fileName: config.fileName3) { string, response, error in
            DispatchQueue.main.async() {
                if let string = string {
                    threeMinText = string
                }
                chartFetchingTask.leave()
            }
        }
        
        chartFetchingTask.notify(queue: DispatchQueue.main) { [weak self] in
            guard let self = self else { return }
            
            if let oneMinText = oneMinText, let twoMinText = twoMinText, let threeMinText = threeMinText {
                self.generateChart(oneMinText: oneMinText, twoMinText: twoMinText, threeMinText: threeMinText)
                completion(self.chart)
            } else {
                print("Chart fetching failed")
                completion(nil)
            }
        }
    }
    
    private func generateChart(oneMinText: String, twoMinText: String, threeMinText: String) {
        let candleSticks = Parser.getPriceData(rawFileInput: oneMinText)
        let oneMinSignals = Parser.getSignalData(rawFileInput: oneMinText, inteval: .oneMin)
        let twoMinSignals = Parser.getSignalData(rawFileInput: twoMinText, inteval: .twoMin)
        let threeMinSignals = Parser.getSignalData(rawFileInput: threeMinText, inteval: .threeMin)
        let oneMinIndicators = Indicators(interval: .oneMin, signals: oneMinSignals)
        let twoMinIndicators = Indicators(interval: .twoMin, signals: twoMinSignals)
        let threeMinIndicators = Indicators(interval: .threeMin, signals: threeMinSignals)
        
        self.chart = Chart.generateChart(ticker: "NQ",
                                         candleSticks: candleSticks,
                                         indicatorsSet: [oneMinIndicators, twoMinIndicators, threeMinIndicators])
    }
    
    private func findLatestAvaiableUrls(completion: @escaping (_ urls: (String, String, String)?) -> Void) {
        var oneMinUrl: String?
        var twoMinUrl: String?
        var threeMinUrl: String?
        let now = Date()
        let urlFetchingTask = DispatchGroup()
        
        urlFetchingTask.enter()
        networkManager.fetchLatestAvailableUrlDuring(time: now, interval: .oneMin, completion: { url in
            oneMinUrl = url
            urlFetchingTask.leave()
        })
        
        urlFetchingTask.enter()
        networkManager.fetchLatestAvailableUrlDuring(time: now, interval: .twoMin, completion: { url in
            twoMinUrl = url
            urlFetchingTask.leave()
        })
        
        urlFetchingTask.enter()
        networkManager.fetchLatestAvailableUrlDuring(time: now, interval: .threeMin, completion: { url in
            threeMinUrl = url
            urlFetchingTask.leave()
        })
        
        urlFetchingTask.notify(queue: DispatchQueue.main) {
            guard let oneMinUrl = oneMinUrl, let twoMinUrl = twoMinUrl, let threeMinUrl = threeMinUrl else {
                return completion(nil)
            }
            
            completion((oneMinUrl, twoMinUrl, threeMinUrl))
        }
    }
    
    private func findFirstAvailableUrls(completion: @escaping (_ urls: (String, String, String)?) -> Void) {
        let queue = DispatchQueue.global()
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var oneMinUrl: String?
            var twoMinUrl: String?
            var threeMinUrl: String?
            
            while self.simTime < Date() {
                if let oneMinUrl = oneMinUrl, let twoMinUrl = twoMinUrl, let threeMinUrl = threeMinUrl {
                    DispatchQueue.main.async {
                        print("Sim time:", self.simTime.hourMinuteSecond(), "has urls: ", terminator:"")
                        print(oneMinUrl, terminator:", ")
                        print(twoMinUrl, terminator:", ")
                        print(threeMinUrl)
                        completion((oneMinUrl, twoMinUrl, threeMinUrl))
                    }
                    return
                }
                
                print("Sim time:", self.simTime.hourMinuteSecond())
                let urlFetchingTask = DispatchGroup()
                
                urlFetchingTask.enter()
                self.networkManager.fetchFirstAvailableUrlInMinute(time: self.simTime, interval: .oneMin, completion: { url in
                    oneMinUrl = url
                    urlFetchingTask.leave()
                })
                
                urlFetchingTask.enter()
                self.networkManager.fetchFirstAvailableUrlInMinute(time: self.simTime, interval: .twoMin, completion: { url in
                    twoMinUrl = url
                    urlFetchingTask.leave()
                })
                
                urlFetchingTask.enter()
                self.networkManager.fetchFirstAvailableUrlInMinute(time: self.simTime, interval: .threeMin, completion: { url in
                    threeMinUrl = url
                    urlFetchingTask.leave()
                })
                
                urlFetchingTask.notify(queue: DispatchQueue.main) {
                    semaphore.signal()
                }
                semaphore.wait()
                self.simTime = self.simTime.getOffByMinutes(minutes: 1)
            }
            
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }
}
