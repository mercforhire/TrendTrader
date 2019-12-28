//
//  ConfigViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-27.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Cocoa

class ConfigViewController: NSViewController {
    
    // Configuration:
    @IBOutlet weak var maxSLField: NSTextField!
    @IBOutlet weak var minSTPField: NSTextField!
    @IBOutlet weak var sweetspotDistanceField: NSTextField!
    @IBOutlet weak var minProfitGreenBarField: NSTextField!
    @IBOutlet weak var minProfitByPass: NSTextField!
    @IBOutlet weak var minProfitPullbackField: NSTextField!
    @IBOutlet weak var highRiskEntryStartPicker: NSDatePicker!
    @IBOutlet weak var highRiskEntryEndPicker: NSDatePicker!
    @IBOutlet weak var sessionStartTimePicker: NSDatePicker!
    @IBOutlet weak var liquidateTimePicker: NSDatePicker!
    @IBOutlet weak var flatTimePicker: NSDatePicker!
    @IBOutlet weak var dailyLossLimitPicker: NSTextField!
    
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
        minProfitGreenBarField.stringValue = String(format: "%.2f", Config.shared.MinProfitToUseTwoGreenBarsExit)
        minProfitByPass.stringValue = String(format: "%.2f", Config.shared.ProfitRequiredAbandonTwoGreenBarsExit)
        minProfitPullbackField.stringValue = String(format: "%.2f", Config.shared.ProfitRequiredToReenterTradeonPullback)
        highRiskEntryStartPicker.dateValue = Date().getNewDateFromTime(hour: Config.shared.HighRiskEntryStartTime.0, min: Config.shared.HighRiskEntryStartTime.1)
        highRiskEntryEndPicker.dateValue = Date().getNewDateFromTime(hour: Config.shared.HighRiskEntryEndTime.0, min: Config.shared.HighRiskEntryEndTime.1)
        sessionStartTimePicker.dateValue = Date().getNewDateFromTime(hour: Config.shared.TradingSessionStartTime.0, min: Config.shared.TradingSessionStartTime.1)
        liquidateTimePicker.dateValue = Date().getNewDateFromTime(hour: Config.shared.ClearPositionTime.0, min: Config.shared.ClearPositionTime.1)
        flatTimePicker.dateValue = Date().getNewDateFromTime(hour: Config.shared.FlatPositionsTime.0, min: Config.shared.FlatPositionsTime.1)
        dailyLossLimitPicker.stringValue = String(format: "%.2f", Config.shared.MaxDailyLoss)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        setupUI()
        loadConfig()
    }
    
}
