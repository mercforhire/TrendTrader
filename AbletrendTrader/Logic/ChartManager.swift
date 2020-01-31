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
    func requestStopMonitoring()
    func chartStatusChanged(statusText: String)
}

class ChartManager {
    private let config = Config.shared
    private let delayBeforeFetchingAtNewMinute = 10
    
    var chart: Chart?
    var monitoring = false
    weak var delegate: DataManagerDelegate?
    
    private let live: Bool
    private var simTime: Date!
    private var currentPriceBarTime: Date?
    private var fetchingChart = false
    
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
                                         minute: 20)
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
                    self.delegate?.chartStatusChanged(statusText: "Chart data reading failed")
                    completion(nil)
                }
            }
        }
    }
    
    func startMonitoring() {
        guard live || config.simulateTimePassage else { return }
        
        updateChart()
        monitoring = true
    }
    
    func stopMonitoring() {
        monitoring = false
        currentPriceBarTime = nil
    }
    
    @objc
    private func updateChart() {
        let now = Date()
        if live,
            !config.byPassTradingTimeRestrictions, now > Date.flatPositionsTime(date: now).getOffByMinutes(minutes: 5) {
            delegate?.requestStopMonitoring()
            self.delegate?.chartStatusChanged(statusText: "Trading session is over at " + now.hourMinute())
            return
        }
        
        if monitoring, live, currentPriceBarTime?.isInSameMinute(date: now) ?? false {
            // call this again 10 seconds after the next minute
            let waitSeconds = 60 + delayBeforeFetchingAtNewMinute - now.second()
            let statusText: String = "Skipped fetching at \(now.hourMinuteSecond()) will fetch again in \(waitSeconds) seconds"
            self.delegate?.chartStatusChanged(statusText: statusText)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(waitSeconds)) {
                self.updateChart()
            }
            return
        }
        
        if fetchingChart {
            return
        }
        
        self.delegate?.chartStatusChanged(statusText: "Start fetching at " + now.hourMinuteSecond())
        fetchingChart = true
        fetchChart { [weak self] chart in
            guard let self = self else { return }
            
            self.fetchingChart = false
            if let chart = chart {
                self.delegate?.chartUpdated(chart: chart)
                self.currentPriceBarTime = chart.absLastBarDate
                
                if self.monitoring {
                    if self.live {
                        // keep calling this until the latest chart is fetched
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.updateChart()
                        }
                    } else if self.config.simulateTimePassage {
                        guard self.simTime < Date.flatPositionsTime(date: self.simTime), self.simTime < Date() else {
                            self.delegate?.chartStatusChanged(statusText: "Simulate time is up to date")
                            self.stopMonitoring()
                            self.delegate?.requestStopMonitoring()
                            return
                        }
                        self.updateChart()
                    }
                }
            } else if self.monitoring, self.live {
                self.delegate?.chartStatusChanged(statusText: "Data for " + Date().hourMinuteSecond() + " yet not found")
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
        downloadData(from: oneMinUrl, fileName: config.fileName1) { string, response, error in
            DispatchQueue.main.async() {
                if let string = string {
                    oneMinText = string
                }
                chartFetchingTask.leave()
            }
        }
        
        chartFetchingTask.enter()
        downloadData(from: twoMinUrl, fileName: config.fileName2) { string, response, error in
            DispatchQueue.main.async() {
                if let string = string {
                    twoMinText = string
                }
                chartFetchingTask.leave()
            }
        }
        
        chartFetchingTask.enter()
        downloadData(from: threeMinUrl, fileName: config.fileName3) { string, response, error in
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
                self.delegate?.chartStatusChanged(statusText: "Latest data: " + (self.chart?.lastBar?.candleStick.time.hourMinuteSecond() ?? "--"))
                completion(self.chart)
            } else {
                self.delegate?.chartStatusChanged(statusText: "Chart fetching failed")
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
        fetchLatestAvailableUrlDuring(time: now, interval: .oneMin, completion: { url in
            oneMinUrl = url
            urlFetchingTask.leave()
        })
        
        urlFetchingTask.enter()
        fetchLatestAvailableUrlDuring(time: now, interval: .twoMin, completion: { url in
            twoMinUrl = url
            urlFetchingTask.leave()
        })
        
        urlFetchingTask.enter()
        fetchLatestAvailableUrlDuring(time: now, interval: .threeMin, completion: { url in
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
                let urlFetchingTask = DispatchGroup()
                
                urlFetchingTask.enter()
                self.fetchLastAvailableUrlInMinute(time: self.simTime, interval: .oneMin, completion: { url in
                    oneMinUrl = url
                    urlFetchingTask.leave()
                })
                
                urlFetchingTask.enter()
                self.fetchLastAvailableUrlInMinute(time: self.simTime, interval: .twoMin, completion: { url in
                    twoMinUrl = url
                    urlFetchingTask.leave()
                })
                
                urlFetchingTask.enter()
                self.fetchLastAvailableUrlInMinute(time: self.simTime, interval: .threeMin, completion: { url in
                    threeMinUrl = url
                    urlFetchingTask.leave()
                })
                
                urlFetchingTask.notify(queue: DispatchQueue.main) {
                    if oneMinUrl == nil || twoMinUrl == nil || threeMinUrl == nil {
                        print("Missing chart data for time:", self.simTime.hourMinuteSecond())
                    }
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
    
    private func downloadData(from url: String, fileName: String, completion: @escaping (String?, URLResponse?, Error?) -> ()) {
        let destination: DownloadRequest.DownloadFileDestination = { _, _ in
            var documentsURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            documentsURL = documentsURL.appendingPathComponent(fileName)
            return (documentsURL, [.removePreviousFile])
        }

        Alamofire.download(url, to: destination).responseData { response in
            if let destinationUrl = response.destinationURL, let string = try? String(contentsOf: destinationUrl, encoding: .utf8) {
               completion(string, nil, nil)
            } else {
                completion(nil, nil, nil)
            }
        }
    }
    
    private func fetchLatestAvailableUrlDuring(time: Date,
                                               interval: SignalInteval,
                                               completion: @escaping (String?) -> ()) {
        let queue = DispatchQueue.global()
        queue.async {
            let semaphore = DispatchSemaphore(value: 0)
            var existUrl: String?
            
            let now = Date()
            let currentSecond = now.second() - 1
            
            if currentSecond < self.delayBeforeFetchingAtNewMinute {
                sleep(UInt32(self.delayBeforeFetchingAtNewMinute - currentSecond))
            }
            
            for i in stride(from: currentSecond, through: 0, by: -1) {
                if existUrl != nil {
                    break
                }
                
                let urlString: String = String(format: "%@%@_%02d-%02d-%02d-%02d-%02d.txt",
                                               self.config.dataServerURL,
                                               interval.text(),
                                               time.month(),
                                               time.day(),
                                               time.hour(),
                                               time.minute(),
                                               i)
                
                Alamofire.SessionManager.default.request(urlString).validate().response { response in
                    if response.response?.statusCode == 200 {
                        existUrl = urlString
                    }
                    semaphore.signal()
                }
                
                semaphore.wait()
            }
            
            DispatchQueue.main.async {
                completion(existUrl)
            }
        }
    }
    
    private func fetchLastAvailableUrlInMinute(time: Date, interval: SignalInteval, completion: @escaping (String?) -> ()) {
        let queue = DispatchQueue.global()
        queue.async {
            let semaphore = DispatchSemaphore(value: 0)
            var existUrl: String?
            
            for second in self.delayBeforeFetchingAtNewMinute...59 {
                if existUrl != nil {
                    break
                }
                
                let urlString: String = String(format: "%@%@_%02d-%02d-%02d-%02d-%02d.txt", self.config.dataServerURL, interval.text(), time.month(), time.day(), time.hour(), time.minute(), second)
                
                Alamofire.SessionManager.default.request(urlString).validate().response { response in
                    if response.response?.statusCode == 200 {
                        existUrl = urlString
                    }
                    semaphore.signal()
                }
                
                semaphore.wait()
            }
            
            DispatchQueue.main.async {
                completion(existUrl)
            }
        }
    }
}
