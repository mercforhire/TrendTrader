//
//  ConfigViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-27.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Cocoa

class ConfigViewController: NSViewController {
    let config = ConfigurationManager.shared
    
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
    @IBOutlet private weak var byPassTradingTimeCheckbox: NSButton!
    @IBOutlet private weak var noEntryDuringLunchCheckbox: NSButton!
    
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
        maxSLField.stringValue = String(format: "%.2f", config.maxRisk)
        minSTPField.stringValue = String(format: "%.2f", config.minStop)
        sweetspotDistanceField.stringValue = String(format: "%.2f", config.sweetSpotMinDistance)
        minProfitGreenBarField.stringValue = String(format: "%.2f", config.greenBarsExit)
        minProfitByPass.stringValue = String(format: "%.2f", config.skipGreenBarsExit)
        minProfitPullbackField.stringValue = String(format: "%.2f", config.enterOnPullback)
        
        highRiskEntryStartPicker.dateValue = Date.getNewDateFromTime(hour: config.highRiskStart.hour(),
                                                                       min: config.highRiskStart.minute())
        
        highRiskEntryEndPicker.dateValue = Date.getNewDateFromTime(hour: config.highRiskEnd.hour(),
                                                                     min: config.highRiskEnd.minute())
        
        sessionStartTimePicker.dateValue = Date.getNewDateFromTime(hour: config.tradingStart.hour(),
                                                                     min: config.tradingStart.minute())
        
        liquidateTimePicker.dateValue = Date.getNewDateFromTime(hour: config.clearTime.hour(),
                                                                min: config.clearTime.minute())
        
        flatTimePicker.dateValue = Date.getNewDateFromTime(hour: config.flatTime.hour(),
                                                           min: config.flatTime.minute())
        
        dailyLossLimitPicker.stringValue = String(format: "%.2f", config.maxDailyLoss)
        byPassTradingTimeCheckbox.state = config.byPassTradingTimeRestrictions ? .on : .off
        noEntryDuringLunchCheckbox.state = config.noEntryDuringLunch ? .on : .off
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        setupUI()
        loadConfig()
    }
    
    @IBAction func byPassTimeChecked(_ sender: NSButton) {
        switch sender.state {
        case .on:
            config.setByPassTradingTimeRestrictions(newValue: true)
        case .off:
            config.setByPassTradingTimeRestrictions(newValue: false)
        default:
            break
        }
    }
    
    @IBAction func noEntryChecked(_ sender: NSButton) {
        switch sender.state {
        case .on:
            config.setNoEntryDuringLunch(newValue: true)
        case .off:
            config.setNoEntryDuringLunch(newValue: false)
        default:
            break
        }
    }
}
