//
//  Parser.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-19.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class Parser {
    static let fileName1 = "NQ 1m.txt"
    static let fileName2 = "NQ 2m.txt"
    static let fileName3 = "NQ 3m.txt"
    
    static let PriceDataHeader = "StartDate\tStartTime\t        Open\t        High\t         Low\t       Close\tVolume\tBid\tAsk"
    static let PriceAndSignalDivider = "Indicator AbleTrendTS Data"
    static let SignalHeader = "Date\tTime\t       BarUp\t       BarDn\t     BuyStop\t    SellStop\tOn1\tOn2\tOn3\tOn4\t         Buy\t        Sell\t        Exit\tOn5\tOn6\tOn7"
    
    
    static func readFile(fileNane: String) -> String? {
        let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fileURL = dir.appendingPathComponent(fileNane)
        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            print(text)
            return text
        }
        catch {
            print("error reading")
        }
        
        return nil
    }
    
    static func getPriceData(rawFileInput: String) -> [PriceBar] {
        let lines = rawFileInput.components(separatedBy: .newlines)
        // get all lines such as
        // 20191219     90000     8616.000000     8616.000000     8615.500000     8615.500000    163
        var priceBars: [PriceBar] = []
        
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
    
    static func generatePriceBar(priceBarString: String, number: Int) -> PriceBar? {
        let components = priceBarString.components(separatedBy: "\t")
        
        var year: Int
        var month: Int
        var day: Int
        var hour: Int
        var minute: Int
        
        // generate the time from [0] and [1]
        let dateComponent: String = components[0]
        let timeComponent: String = components[1]
        let timeComponentPadded: String = String(format: "%06d", timeComponent.int ?? 0)
        
        let yearString: String = dateComponent.substring(to: 3)
        let monthString: String = dateComponent.substring(from: 4).substring(to: 1)
        let dayString: String = dateComponent.substring(from: 6)
        let hourString: String = timeComponentPadded.substring(to: 1)
        let minuteString: String = timeComponentPadded.substring(from: 2).substring(to: 1)
        
        year = yearString.int ?? 0
        month = monthString.int ?? 0
        day = dayString.int ?? 0
        hour = hourString.int ?? 0
        minute = minuteString.int ?? 0
        
        let date = makeDate(year: year, month: month, day: day, hr: hour, min: minute)
        
        // generate the open from [2]
        let open: Float = components[2].float ?? 00
        
        // generate the high from [3]
        let high: Float = components[3].float ?? 00
        
        // generate the low from [4]
        let low: Float = components[4].float ?? 00
        
        // generate the close from [5]
        let close: Float = components[5].float ?? 00
        
        // generate the volume from [6]
        let volume: Int = components[6].int ?? 00
        
        let priceBar = PriceBar(identifier: number, time: date, open: open, high: high, low: low, close: close, volume: volume)
        return priceBar
    }
    
    static func makeDate(year: Int, month: Int, day: Int, hr: Int, min: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(abbreviation: "EST")!
        let components = DateComponents(year: year, month: month, day: day, hour: hr, minute: min)
        return calendar.date(from: components)!
    }
}
