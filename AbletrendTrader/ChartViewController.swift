//
//  ChartViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-28.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Cocoa
import Charts

class ChartViewController: NSViewController {
    
    @IBOutlet weak var chartView: CandleStickChartView!
    
    var chart: Chart?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        chartView.chartDescription?.enabled = false
        
        chartView.dragEnabled = true
        chartView.setScaleEnabled(true)
        chartView.pinchZoomEnabled = true
        
        chartView.legend.horizontalAlignment = .right
        chartView.legend.verticalAlignment = .top
        chartView.legend.orientation = .vertical
        chartView.legend.drawInside = false
        chartView.legend.font = NSFont(name: "HelveticaNeue-Light", size: 10)!
        
        chartView.leftAxis.labelFont = NSFont(name: "HelveticaNeue-Light", size: 10)!
        chartView.leftAxis.spaceTop = 0.3
        chartView.leftAxis.spaceBottom = 0.3
        chartView.leftAxis.axisMinimum = 0
        
        chartView.rightAxis.enabled = false
        
        chartView.xAxis.labelPosition = .bottom
        chartView.xAxis.labelFont = NSFont(name: "HelveticaNeue-Light", size: 10)!
        
    }
    
    func generateCandleStickChartDate() {
        guard let chart = chart else { return }
        
        let set1 = CandleChartDataSet(entries: chart.generateCandleStickData(), label: "NQ futures")
        set1.axisDependency = .left
        set1.setColor(NSColor(white: 80/255, alpha: 1))
        set1.drawIconsEnabled = false
        set1.shadowColor = .darkGray
        set1.shadowWidth = 0.7
        set1.decreasingColor = .red
        set1.decreasingFilled = true
        set1.increasingColor = NSColor(red: 122/255, green: 242/255, blue: 84/255, alpha: 1)
        set1.increasingFilled = true
        set1.neutralColor = .blue
        
        chartView.leftAxis.axisMaximum = set1.yMax
        chartView.leftAxis.axisMinimum = set1.yMin
        
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
