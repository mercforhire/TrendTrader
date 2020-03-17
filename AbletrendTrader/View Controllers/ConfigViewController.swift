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
    
    @IBOutlet private weak var riskField: NSTextField!
    @IBOutlet private weak var maxSLField: NSTextField!
    @IBOutlet private weak var minSTPField: NSTextField!
    @IBOutlet private weak var sweetspotDistanceField: NSTextField!
    @IBOutlet private weak var minProfitGreenBarField: NSTextField!
    @IBOutlet private weak var minProfitByPass: NSTextField!
    @IBOutlet private weak var minProfitPullbackField: NSTextField!
    @IBOutlet private weak var takeProfitField: NSTextField!
    @IBOutlet private weak var highRiskEntryStartPicker: NSDatePicker!
    @IBOutlet private weak var highRiskEntryEndPicker: NSDatePicker!
    @IBOutlet private weak var sessionStartTimePicker: NSDatePicker!
    @IBOutlet private weak var liquidateTimePicker: NSDatePicker!
    @IBOutlet private weak var flatTimePicker: NSDatePicker!
    @IBOutlet private weak var dailyLossLimitPicker: NSTextField!
    @IBOutlet private weak var byPassTradingTimeCheckbox: NSButton!
    @IBOutlet private weak var noEntryDuringLunchCheckbox: NSButton!
    
    func setupUI() {
        riskField.isEditable = true
        maxSLField.isEditable = true
        minSTPField.isEditable = true
        sweetspotDistanceField.isEditable = true
        minProfitGreenBarField.isEditable = true
        minProfitByPass.isEditable = true
        minProfitPullbackField.isEditable = true
        takeProfitField.isEditable = true
        highRiskEntryStartPicker.isEnabled = true
        highRiskEntryEndPicker.isEnabled = true
        sessionStartTimePicker.isEnabled = true
        liquidateTimePicker.isEnabled = true
        flatTimePicker.isEnabled = true
        dailyLossLimitPicker.isEditable = true
    }
    
    func loadConfig() {
        riskField.stringValue = String(format: "%.2f", config.riskMultiplier)
        maxSLField.stringValue = String(format: "%.2f", config.maxRisk)
        minSTPField.stringValue = String(format: "%.2f", config.minStop)
        sweetspotDistanceField.stringValue = String(format: "%.2f", config.sweetSpotMinDistance)
        minProfitGreenBarField.stringValue = String(format: "%.2f", config.greenBarsExit)
        minProfitByPass.stringValue = String(format: "%.2f", config.skipGreenBarsExit)
        minProfitPullbackField.stringValue = String(format: "%.2f", config.enterOnPullback)
        takeProfitField.stringValue = String(format: "%.2f", config.takeProfitBarLength)
        
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
    
    @IBAction func highRiskStartChanged(_ sender: NSDatePicker) {
        print(sender.dateValue.hourMinute())
    }
    
    @IBAction func highRiskEndChanged(_ sender: NSDatePicker) {
        print(sender.dateValue.hourMinute())
    }
    
    @IBAction func sessionStartChanged(_ sender: NSDatePicker) {
        print(sender.dateValue.hourMinute())
    }
    
    @IBAction func liquidationTimeChanged(_ sender: NSDatePicker) {
        print(sender.dateValue.hourMinute())
    }
    
    @IBAction func flatPositionsTimeChanged(_ sender: NSDatePicker) {
        print(sender.dateValue.hourMinute())
    }
    
}

extension ConfigViewController: NSControlTextEditingDelegate {
    func controlTextDidEndEditing(_ notification: Notification) {
        if let textField = notification.object as? NSTextField {
            if textField == riskField {
                config.setRiskMultiplier(newValue: textField.doubleValue)
            } else if textField == maxSLField {
                config.setMaxRisk(newValue: textField.doubleValue)
            } else if textField == minSTPField {
                config.setMaxRisk(newValue: textField.doubleValue)
            } else if textField == sweetspotDistanceField {
                config.setSweetSpotMinDistance(newValue: textField.doubleValue)
            } else if textField == minProfitGreenBarField {
                config.setGreenBarsExit(newValue: textField.doubleValue)
            } else if textField == minProfitByPass {
                config.setSkipGreenBarsExit(newValue: textField.doubleValue)
            } else if textField == minProfitPullbackField {
                config.setEnterOnPullback(newValue: textField.doubleValue)
            } else if textField == takeProfitField {
                config.setTakeProfitBarLength(newValue: textField.doubleValue)
            } else if textField == dailyLossLimitPicker {
                config.setMaxDailyLoss(newValue: textField.doubleValue)
            }
        }
    }
}
