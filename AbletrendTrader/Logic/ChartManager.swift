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
    private let fileName1: String = "1m.txt" // filename for local sandbox folder
    private let fileName2: String = "2m.txt" // filename for local sandbox folder
    private let fileName3: String = "3m.txt" // filename for local sandbox folder
    
    private let config = ConfigurationManager.shared
    private let delayBeforeFetchingAtNewMinute = 5
    
    var serverUrls: [SignalInteval: String] = [:]
    var chart: Chart?
    var monitoring = false
    weak var delegate: DataManagerDelegate?
    
    private let live: Bool
    private var simTime: Date!
    private var currentPriceBarTime: Date?
    private var fetchingChart = false
    private var refreshTimer: Timer?
    private var nextRuntime: Date?
    
    init(live: Bool, serverUrls: [SignalInteval: String]) {
        self.live = live
        self.serverUrls = serverUrls
        resetSimTime()
    }
    
    func resetSimTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components1 = DateComponents(year: Date().year(),
                                         month: Date().month(),
                                         day: Date().day(),
                                         hour: 9,
                                         minute: 40)
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
                findLatestAvailableUrls { [weak self] urls in
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
                if let oneMinText = Parser.readFile(fileName: fileName1),
                    let twoMinText = Parser.readFile(fileName: fileName2),
                    let threeMinText = Parser.readFile(fileName: fileName3) {
                    
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
        refreshTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(timerFunction), userInfo: nil, repeats: true)
    }
    
    func stopMonitoring() {
        monitoring = false
        currentPriceBarTime = nil
        nextRuntime = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    @objc func timerFunction() {
        guard let nextRuntime = nextRuntime else { return }
        
        if Date() >= nextRuntime {
            updateChart()
        }
    }
    
    @objc
    private func updateChart() {
        let now = Date()
        if live,
            !config.byPassTradingTimeRestrictions, now > Date.flatPositionsTime(date: now).getOffByMinutes(minutes: 2) {
            delegate?.requestStopMonitoring()
            self.delegate?.chartStatusChanged(statusText: "Trading session is over at " + now.hourMinute())
            return
        }
        
        if monitoring, live, currentPriceBarTime?.isInSameMinute(date: now) ?? false {
            // call this again X seconds after the next minute
            let waitSeconds = 60 + delayBeforeFetchingAtNewMinute - now.second()
            nextRuntime = now.addingTimeInterval(TimeInterval(waitSeconds))
            let statusText: String = "Latest data: \((currentPriceBarTime?.hourMinute() ?? "--")), will fetch again at \(nextRuntime!.hourMinuteSecond())"
            self.delegate?.chartStatusChanged(statusText: statusText)
            
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
                        self.nextRuntime = nil
                        let date = Date().addingTimeInterval(TimeInterval(1))
                        let timer = Timer(fireAt: date, interval: 0, target: self, selector: #selector(self.updateChart), userInfo: nil, repeats: false)
                        RunLoop.main.add(timer, forMode: .common)
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
                self.updateChart()
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
        downloadData(from: oneMinUrl, fileName: fileName1) { string, response, error in
            DispatchQueue.main.async() {
                if let string = string {
                    oneMinText = string
                }
                chartFetchingTask.leave()
            }
        }
        
        chartFetchingTask.enter()
        downloadData(from: twoMinUrl, fileName: fileName2) { string, response, error in
            DispatchQueue.main.async() {
                if let string = string {
                    twoMinText = string
                }
                chartFetchingTask.leave()
            }
        }
        
        chartFetchingTask.enter()
        downloadData(from: threeMinUrl, fileName: fileName3) { string, response, error in
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
        
        self.chart = Chart.generateChart(candleSticks: candleSticks,
                                         indicatorsSet: [oneMinIndicators, twoMinIndicators, threeMinIndicators])
    }
    
    private func findLatestAvaiableUrls(completion: @escaping (_ urls: (String, String, String)?) -> Void) {
        var oneMinUrl: String?
        var twoMinUrl: String?
        var threeMinUrl: String?
        let now = Date()
        let urlFetchingTask = DispatchGroup()
        
        print(Date().hourMinuteSecond() + ": start fetching latest urls...")
        
        urlFetchingTask.enter()
        fetchLatestAvailableUrlDuring(time: now, startSecond: now.second() - 1, interval: .oneMin, completion: { url in
            oneMinUrl = url
            urlFetchingTask.leave()
        })
        
        urlFetchingTask.enter()
        fetchLatestAvailableUrlDuring(time: now, startSecond: now.second() - 1, interval: .twoMin, completion: { url in
            twoMinUrl = url
            urlFetchingTask.leave()
        })
        
        urlFetchingTask.enter()
        fetchLatestAvailableUrlDuring(time: now, startSecond: now.second() - 1, interval: .threeMin, completion: { url in
            threeMinUrl = url
            urlFetchingTask.leave()
        })
        
        urlFetchingTask.notify(queue: DispatchQueue.main) {
            guard let oneMinUrl = oneMinUrl, let twoMinUrl = twoMinUrl, let threeMinUrl = threeMinUrl else {
                return completion(nil)
            }
            
            print(Date().hourMinuteSecond() + ": urls fetched, downloading", oneMinUrl, twoMinUrl, threeMinUrl)
            completion((oneMinUrl, twoMinUrl, threeMinUrl))
        }
    }
    
    private func findLatestAvailableUrls(completion: @escaping (_ urls: (String, String, String)?) -> Void) {
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
                self.fetchLatestAvailableUrlDuring(time: self.simTime, startSecond: 15, interval: .oneMin, completion: { url in
                    oneMinUrl = url
                    urlFetchingTask.leave()
                })
                
                urlFetchingTask.enter()
                self.fetchLatestAvailableUrlDuring(time: self.simTime, startSecond: 15, interval: .twoMin, completion: { url in
                    twoMinUrl = url
                    urlFetchingTask.leave()
                })
                
                urlFetchingTask.enter()
                self.fetchLatestAvailableUrlDuring(time: self.simTime, startSecond: 15, interval: .threeMin, completion: { url in
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
                                               startSecond: Int = 59,
                                               interval: SignalInteval,
                                               completion: @escaping (String?) -> ()) {
        guard let serverURL = serverUrls[interval] else {
            print("Error: Does not contain url for", interval.text(), "min data server")
            return
        }
        
        let queue = DispatchQueue.global()
        queue.async {
            let semaphore = DispatchSemaphore(value: 0)
            var existUrl: String?
            
            for i in stride(from: startSecond, through: 0, by: -1) {
                if existUrl != nil {
                    break
                }
                
                let urlString: String = String(format: "%@%@_%02d-%02d-%02d-%02d-%02d.txt",
                                               serverURL,
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
}
