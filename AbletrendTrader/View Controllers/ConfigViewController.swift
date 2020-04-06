//
//  ConfigViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-27.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Cocoa

class ConfigViewController: NSViewController, NSTextFieldDelegate {
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
    @IBOutlet private weak var lunchStartPicker: NSDatePicker!
    @IBOutlet private weak var lunchEndPicker: NSDatePicker!
    @IBOutlet private weak var highRiskTradesField: NSTextField!
    @IBOutlet private weak var sessionStartTimePicker: NSDatePicker!
    @IBOutlet private weak var liquidateTimePicker: NSDatePicker!
    @IBOutlet private weak var flatTimePicker: NSDatePicker!
    @IBOutlet private weak var dailyLossLimitField: NSTextField!
    @IBOutlet private weak var byPassTradingTimeCheckbox: NSButton!
    @IBOutlet private weak var noEntryDuringLunchCheckbox: NSButton!
    
    func setupUI() {
        riskField.delegate = self
        maxSLField.delegate = self
        minSTPField.delegate = self
        sweetspotDistanceField.delegate = self
        minProfitGreenBarField.delegate = self
        minProfitByPass.delegate = self
        minProfitPullbackField.delegate = self
        takeProfitField.delegate = self
        dailyLossLimitField.delegate = self
        highRiskTradesField.delegate = self
    }
    
    func loadConfig() {
        riskField.stringValue = String(format: "%.2f", config.riskMultiplier)
        maxSLField.stringValue = String(format: "%.2f", config.maxRiskBase)
        minSTPField.stringValue = String(format: "%.2f", config.minStopBase)
        sweetspotDistanceField.stringValue = String(format: "%.2f", config.sweetSpotBase)
        minProfitGreenBarField.stringValue = String(format: "%.2f", config.greenExitBase)
        minProfitByPass.stringValue = String(format: "%.2f", config.skipGreenExitBase)
        minProfitPullbackField.stringValue = String(format: "%.2f", config.enterOnAnyPullbackBase)
        takeProfitField.stringValue = String(format: "%.2f", config.takeProfitBarLengthBase)
        
        highRiskEntryStartPicker.dateValue = Date.getNewDateFromTime(hour: config.highRiskStart.hour(),
                                                                     min: config.highRiskStart.minute())
        
        highRiskEntryEndPicker.dateValue = Date.getNewDateFromTime(hour: config.highRiskEnd.hour(),
                                                                   min: config.highRiskEnd.minute())
        
        lunchStartPicker.dateValue = Date.getNewDateFromTime(hour: config.lunchStart.hour(),
                                                             min: config.lunchStart.minute())
        
        lunchEndPicker.dateValue = Date.getNewDateFromTime(hour: config.lunchEnd.hour(),
                                                           min: config.lunchEnd.minute())
        
        sessionStartTimePicker.dateValue = Date.getNewDateFromTime(hour: config.tradingStart.hour(),
                                                                   min: config.tradingStart.minute())
        
        liquidateTimePicker.dateValue = Date.getNewDateFromTime(hour: config.clearTime.hour(),
                                                                min: config.clearTime.minute())
        
        flatTimePicker.dateValue = Date.getNewDateFromTime(hour: config.flatTime.hour(),
                                                           min: config.flatTime.minute())
        
        dailyLossLimitField.stringValue = String(format: "%.2f", config.maxDailyLossBase)
        highRiskTradesField.stringValue = String(format: "%d", config.maxHighRiskEntryAllowed)
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
        do {
            try config.setHighRiskStart(newValue: sender.dateValue)
        } catch (let error) {
            guard let configError = error as? ConfigError else { return }
            
            configError.displayErrorDialog()
            
            sender.dateValue = config.highRiskStart
        }
    }
    
    @IBAction func highRiskEndChanged(_ sender: NSDatePicker) {
        do {
            try config.setHighRiskEnd(newValue: sender.dateValue)
        } catch (let error) {
            guard let configError = error as? ConfigError else { return }
            
            configError.displayErrorDialog()
            
            sender.dateValue = config.highRiskEnd
        }
    }
    
    @IBAction func lunchStartChanged(_ sender: NSDatePicker) {
        do {
            try config.setLunchStart(newValue: sender.dateValue)
        } catch (let error) {
            guard let configError = error as? ConfigError else { return }
            
            configError.displayErrorDialog()
            
            sender.dateValue = config.lunchStart
        }
    }
    
    @IBAction func lunchEndChanged(_ sender: NSDatePicker) {
        do {
            try config.setLunchEnd(newValue: sender.dateValue)
        } catch (let error) {
            guard let configError = error as? ConfigError else { return }
            
            configError.displayErrorDialog()
            
            sender.dateValue = config.lunchEnd
        }
    }
    
    @IBAction func sessionStartChanged(_ sender: NSDatePicker) {
        do {
            try config.setTradingStart(newValue: sender.dateValue)
        } catch (let error) {
            guard let configError = error as? ConfigError else { return }
            
            configError.displayErrorDialog()
            
            sender.dateValue = config.tradingStart
        }
    }
    
    @IBAction func liquidationTimeChanged(_ sender: NSDatePicker) {
        do {
            try config.setClearTime(newValue: sender.dateValue)
        } catch (let error) {
            guard let configError = error as? ConfigError else { return }
            
            configError.displayErrorDialog()
            
            sender.dateValue = config.clearTime
        }
    }
    
    @IBAction func flatPositionsTimeChanged(_ sender: NSDatePicker) {
        do {
            try config.setFlatTime(newValue: sender.dateValue)
        } catch (let error) {
            guard let configError = error as? ConfigError else { return }
            
            configError.displayErrorDialog()
            
            sender.dateValue = config.flatTime
        }
    }
    
}

extension ConfigViewController: NSControlTextEditingDelegate {
    func controlTextDidEndEditing(_ notification: Notification) {
        if let textField = notification.object as? NSTextField {
            do {
                if textField == riskField {
                    try config.setRiskMultiplier(newValue: textField.doubleValue)
                } else if textField == maxSLField {
                    try config.setMaxRisk(newValue: textField.doubleValue)
                } else if textField == minSTPField {
                    try config.setMinStop(newValue: textField.doubleValue)
                } else if textField == sweetspotDistanceField {
                    try config.setSweetSpotMinDistance(newValue: textField.doubleValue)
                } else if textField == minProfitGreenBarField {
                    try config.setGreenBarsExit(newValue: textField.doubleValue)
                } else if textField == minProfitByPass {
                    try config.setSkipGreenBarsExit(newValue: textField.doubleValue)
                } else if textField == minProfitPullbackField {
                    try config.setEnterOnPullback(newValue: textField.doubleValue)
                } else if textField == takeProfitField {
                    try config.setTakeProfitBarLength(newValue: textField.doubleValue)
                } else if textField == dailyLossLimitField {
                    try config.setMaxDailyLoss(newValue: textField.doubleValue)
                } else if textField == highRiskTradesField {
                    try config.setMaxHighRiskEntryAllowed(newValue: textField.integerValue)
                }
            } catch (let error) {
                guard let configError = error as? ConfigError else { return }
                
                configError.displayErrorDialog()
            }
        }
    }
}
