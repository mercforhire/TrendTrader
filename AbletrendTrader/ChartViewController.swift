//
//  ChartViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-28.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Cocoa
import Charts

class DateValueFormatter: NSObject, IAxisValueFormatter {
    private let dateFormatter = DateFormatter()
    var startDate: Date?
    
    override init() {
        dateFormatter.dateFormat = "HH:mm"
        super.init()
    }
    
    public func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        return dateFormatter.string(from: (startDate ?? Date()).addingTimeInterval(TimeInterval(value * 60)))
    }
}

class ChartViewController: NSViewController {
    
    @IBOutlet private weak var chartView: CandleStickChartView!
    
    var chart: Chart?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        chartView.chartDescription?.enabled = false
        
        chartView.dragEnabled = true
        chartView.setScaleEnabled(true)
        chartView.pinchZoomEnabled = true
        
        chartView.legend.form = .none
        
        chartView.leftAxis.labelFont = NSFont(name: "HelveticaNeue-Light", size: 10)!
        chartView.leftAxis.spaceTop = 0.3
        chartView.leftAxis.spaceBottom = 0.3
        chartView.leftAxis.axisMinimum = 0
        chartView.leftAxis.drawGridLinesEnabled = false
        
        chartView.rightAxis.enabled = false
        
        chartView.xAxis.labelPosition = .bottom
        chartView.xAxis.labelFont = NSFont(name: "HelveticaNeue-Light", size: 10)!
        chartView.xAxis.drawGridLinesEnabled = false
        
        generateCandleStickChartDate()
    }
    
    func generateCandleStickChartDate() {
        guard let chart = chart, let startDate = chart.startDate else { return }
        
        let set1 = CandleChartDataSet(entries: chart.generateCandleStickData(), label: "NQ futures")
        set1.axisDependency = .left
        set1.setColor(NSColor(white: 80/255, alpha: 1))
        set1.drawIconsEnabled = false
        set1.drawValuesEnabled = false
        set1.shadowColor = .darkGray
        set1.shadowWidth = 0.7
        set1.decreasingColor = .red
        set1.decreasingFilled = true
        set1.increasingColor = NSColor(red: 122/255, green: 242/255, blue: 84/255, alpha: 1)
        set1.increasingFilled = true
        set1.neutralColor = .blue
        
        chartView.leftAxis.axisMaximum = set1.yMax
        chartView.leftAxis.axisMinimum = set1.yMin
        
        let dateValueFormatter = DateValueFormatter()
        dateValueFormatter.startDate = startDate
        chartView.xAxis.valueFormatter = dateValueFormatter
        
        let data = CandleChartData(dataSet: set1)
        chartView.data = data
    }
}

extension ChartViewController: DataManagerDelegate {
    func chartUpdated(chart: Chart) {
        self.chart = chart
        generateCandleStickChartDate()
    }
}
