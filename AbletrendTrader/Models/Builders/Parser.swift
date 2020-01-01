//
//  Parser.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-19.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class Parser {
    static let PriceDataHeader = "StartDate\tStartTime\t        Open\t        High\t         Low\t       Close\tVolume\tBid\tAsk"
    static let PriceAndSignalDivider = "Indicator AbleTrendTS Data"
    static let SignalHeader = "Date\tTime\t       BarUp\t       BarDn\t     BuyStop\t    SellStop\tOn1\tOn2\tOn3\tOn4\t         Buy\t        Sell\t        Exit\tOn5\tOn6\tOn7"
    
    static func readFile(fileName: String) -> String? {
        let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fileURL = dir.appendingPathComponent(fileName)
        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            return text
        }
        catch {
            print("error reading")
        }
        
        return nil
    }
    
    static func getPriceData(rawFileInput: String) -> [CandleStick] {
        let lines = rawFileInput.components(separatedBy: .newlines)
        // get all lines such as
        // 20191219     90000     8616.000000     8616.000000     8615.500000     8615.500000    163
        var priceBars: [CandleStick] = []
        
        var startRecording: Bool = false // when startRecording is true, append the next 'line' in loop to 'priceDateLines'
        var count: Int = 0
        for line in lines {
            if line == PriceDataHeader {
                startRecording = true
            } else if startRecording, line == PriceAndSignalDivider {
                break
            } else if startRecording, !line.isEmpty {
                let filterLine = line.replacingOccurrences(of: " ", with: "")
                if let priceBar = Parser.generatePriceBar(priceBarString: filterLine, number: count) {
                    priceBars.append(priceBar)
                }
                count += 1
            }
        }
        
        return priceBars
    }
    
    static func getSignalData(rawFileInput: String, inteval: SignalInteval) -> [Signal] {
        let lines = rawFileInput.components(separatedBy: .newlines)
        
        // get all lines such as
        // 20191219     90800       8618.2500       8572.7500       8615.9121       8574.9395    true    false    true    false                       8572.7500                    false    false    false
        var signals: [Signal] = []
        
        var startRecording: Bool = false // when startRecording is true, append the next 'line' in loop to 'priceDateLines'
        for line in lines {
            if line == SignalHeader {
                startRecording = true
            } else if startRecording, !line.isEmpty {
                let filterLine = line.replacingOccurrences(of: " ", with: "")
                if let signal = Parser.generateSignal(signalString: filterLine, inteval: inteval) {
                    signals.append(signal)
                }
            }
        }
        
        return signals
    }
    
    static func generatePriceBar(priceBarString: String, number: Int) -> CandleStick? {
        let components = priceBarString.components(separatedBy: "\t")
        
        guard components.count >= 7 else { return nil }
        
        // generate the time from [0] and [1]
        let dateComponent: String = components[0]
        let timeComponent: String = components[1]
        let date = makeDate(dateComponent: dateComponent, timeComponent: timeComponent)
        
        // generate the open from [2]
        let open: Double = components[2].double ?? 00
        
        // generate the high from [3]
        let high: Double = components[3].double ?? 00
        
        // generate the low from [4]
        let low: Double = components[4].double ?? 00
        
        // generate the close from [5]
        let close: Double = components[5].double ?? 00
        
        // generate the volume from [6]
        let volume: Int = components[6].int ?? 00
        
        let priceBar = CandleStick(time: date, open: open, high: high, low: low, close: close, volume: volume)
        return priceBar
    }
    
    static func generateSignal(signalString: String, inteval: SignalInteval) -> Signal? {
        let components = signalString.components(separatedBy: "\t")
        
        guard components.count >= 10 else { return nil }
        
        // generate the time from [0] and [1]
        let dateComponent: String = components[0]
        let timeComponent: String = components[1]
        
        guard !dateComponent.isEmpty && !timeComponent.isEmpty else { return nil }
        
        let date = makeDate(dateComponent: dateComponent, timeComponent: timeComponent)
        
        // generate the on1 from [6]
        let on1String: String = components[6]
        
        // generate the on2 from [7]
        let on2String: String = components[7]
        
        // calculate SignalColor from on1 and on2
        var signalColor: SignalColor
        // on1 == false && on2 == false -> green bar
        // on1 == true && on2 == false -> blue bar
        // on1 == false && on2 == true -> red bar
        if on1String == "true" && on2String == "false" {
            signalColor = .blue
        } else if on1String == "false" && on2String == "true" {
            signalColor = .red
        } else {
            signalColor = .green
        }
        
        // generate the on3 from [8]
        let on3String: String = components[8]
        
        // generate the on4 from [9]
        let on4String: String = components[9]
        
        // calculate stop from on3 and on4
        // on3 == false && on4 == false, bar has no resistence nor support
        // on3 == true && on4 == false, bar has support
        // on3 == false && on4 == true, bar has resistence
        
        // generate BuyStop from [4]
        let buyStopString: String = components[4]
        
        // generate SellStop from [5]
        let sellStopString: String = components[5]
        
        var stop: Double?
        var direction: TradeDirection?
        if on3String == "true" && on4String == "false" {
            stop = buyStopString.double
            direction = .long
        } else if on3String == "false" && on4String == "true" {
            stop = sellStopString.double
            direction = .short
        }
        
        let signal: Signal = Signal(time: date, color: signalColor, stop: stop, direction: direction, inteval: inteval)
        return signal
    }
    
    static func makeDate(dateComponent: String, timeComponent: String) -> Date {
        var year: Int
        var month: Int
        var day: Int
        var hour: Int
        var minute: Int
        let yearString: String = dateComponent.substring(to: 3)
        let monthString: String = dateComponent.substring(from: 4).substring(to: 1)
        let dayString: String = dateComponent.substring(from: 6)
        let timeComponentPadded: String = String(format: "%06d", timeComponent.int ?? 0)
        let hourString: String = timeComponentPadded.substring(to: 1)
        let minuteString: String = timeComponentPadded.substring(from: 2).substring(to: 1)
        
        year = yearString.int ?? 0
        month = monthString.int ?? 0
        day = dayString.int ?? 0
        hour = hourString.int ?? 0
        minute = minuteString.int ?? 0
        
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Date.DefaultTimeZone
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return calendar.date(from: components)!
    }
}
