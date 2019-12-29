//
//  ConfigViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-27.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Cocoa

class ConfigViewController: NSViewController {
    
    @IBOutlet private weak var maxSLField: NSTextField!
    @IBOutlet private weak var minSTPField: NSTextField!
    @IBOutlet private weak var sweetspotDistanceField: NSTextField!
    @IBOutlet private weak var minProfitGreenBarField: NSTextField!
    @IBOutlet private weak var minProfitByPass: NSTextField!
    @IBOutlet private weak var minProfitPullbackField: NSTextField!
    @IBOutlet private weak var highRiskEntryStartPicker: NSDatePicker!
    @IBOutlet private weak var highRiskEntryEndPicker: NSDatePicker!
    @IBOutlet private weak var sessionStartTimePicker: NSDatePicker!
    @IBOutlet private weak var liquidateTimePicker: NSDatePicker!
    @IBOutlet private weak var flatTimePicker: NSDatePicker!
    @IBOutlet private weak var dailyLossLimitPicker: NSTextField!
    
    func setupUI() {
        maxSLField.isEditable = false
        minSTPField.isEditable = false
        sweetspotDistanceField.isEditable = false
        minProfitGreenBarField.isEditable = false
        minProfitByPass.isEditable = false
        minProfitPullbackField.isEditable = false
        
        highRiskEntryStartPicker.isEnabled = false
        highRiskEntryEndPicker.isEnabled = false
        sessionStartTimePicker.isEnabled = false
        liquidateTimePicker.isEnabled = false
        flatTimePicker.isEnabled = false
        dailyLossLimitPicker.isEditable = false
    }
    
    func loadConfig() {
        maxSLField.stringValue = String(format: "%.2f", Config.shared.MaxRisk)
        minSTPField.stringValue = String(format: "%.2f", Config.shared.MinBarStop)
        sweetspotDistanceField.stringValue = String(format: "%.2f", Config.shared.SweetSpotMinDistance)
        minProfitGreenBarField.stringValue = String(format: "%.2f", Config.shared.GreenBarsExit)
        minProfitByPass.stringValue = String(format: "%.2f", Config.shared.SkipGreenBarsExit)
        minProfitPullbackField.stringValue = String(format: "%.2f", Config.shared.EnterOnPullback)
        highRiskEntryStartPicker.dateValue = Date().getNewDateFromTime(hour: Config.shared.HighRiskStart.0, min: Config.shared.HighRiskStart.1)
        highRiskEntryEndPicker.dateValue = Date().getNewDateFromTime(hour: Config.shared.HighRiskEnd.0, min: Config.shared.HighRiskEnd.1)
        sessionStartTimePicker.dateValue = Date().getNewDateFromTime(hour: Config.shared.TradingStart.0, min: Config.shared.TradingStart.1)
        liquidateTimePicker.dateValue = Date().getNewDateFromTime(hour: Config.shared.ClearTime.0, min: Config.shared.ClearTime.1)
        flatTimePicker.dateValue = Date().getNewDateFromTime(hour: Config.shared.FlatTime.0, min: Config.shared.FlatTime.1)
        dailyLossLimitPicker.stringValue = String(format: "%.2f", Config.shared.MaxDailyLoss)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        setupUI()
        loadConfig()
    }
    
}
