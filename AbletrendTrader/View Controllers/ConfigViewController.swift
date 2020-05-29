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
    @IBOutlet private weak var maxDistanceToSRField: NSTextField!
    @IBOutlet private weak var profitAvoidSameDirectionField: NSTextField!
    @IBOutlet private weak var losingTradesField: NSTextField!
    @IBOutlet private weak var oppositeLosingTradesField: NSTextField!
    @IBOutlet private weak var fomcTimePicker: NSDatePicker!
    @IBOutlet private weak var sessionStartTimePicker: NSDatePicker!
    @IBOutlet private weak var sessionEndTimePicker: NSDatePicker!
    @IBOutlet private weak var liquidateTimePicker: NSDatePicker!
    @IBOutlet private weak var flatTimePicker: NSDatePicker!
    @IBOutlet private weak var dailyLossLimitField: NSTextField!
    @IBOutlet private weak var simRealTimeCheckbox: NSButton!
    @IBOutlet private weak var avoidSameTradeCheckbox: NSButton!
    @IBOutlet private weak var avoidSameLosingTradeCheckbox: NSButton!
    @IBOutlet private weak var byPassTradingTimeCheckbox: NSButton!
    @IBOutlet private weak var noEntryDuringLunchCheckbox: NSButton!
    @IBOutlet private weak var waitFinalizedSignalsCheckbox: NSButton!
    @IBOutlet private weak var fomcDayCheckbox: NSButton!
    @IBOutlet private weak var stoplossBufferField: NSTextField!
    @IBOutlet private weak var maxDDField: NSTextField!
    @IBOutlet private weak var present1Button: NSButton!
    @IBOutlet private weak var present2Button: NSButton!
    @IBOutlet private weak var present3Button: NSButton!
    @IBOutlet private weak var present4Button: NSButton!
    
    var tradingSetting: TradingSettings! {
        didSet {
            loadConfig()
        }
    }
    
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
        maxDistanceToSRField.delegate = self
        profitAvoidSameDirectionField.delegate = self
        losingTradesField.delegate = self
        oppositeLosingTradesField.delegate = self
        stoplossBufferField.delegate = self
        maxDDField.delegate = self
    }
    
    func loadConfig() {
        riskField.stringValue = String(format: "%.2f", tradingSetting.riskMultiplier)
        maxSLField.stringValue = String(format: "%.2f", tradingSetting.maxRiskBase)
        minSTPField.stringValue = String(format: "%.2f", tradingSetting.minStopBase)
        sweetspotDistanceField.stringValue = String(format: "%.2f", tradingSetting.sweetSpotBase)
        minProfitGreenBarField.stringValue = String(format: "%.2f", tradingSetting.greenExitBase)
        minProfitByPass.stringValue = String(format: "%.2f", tradingSetting.skipGreenExitBase)
        minProfitPullbackField.stringValue = String(format: "%.2f", tradingSetting.enterOnAnyPullbackBase)
        takeProfitField.stringValue = String(format: "%.2f", tradingSetting.takeProfitBarLengthBase)
        maxDDField.stringValue = String(format: "%.2f", tradingSetting.drawdownLimit)
    
        fomcTimePicker.dateValue = Date.getNewDateFromTime(hour: tradingSetting.fomcTime.hour(),
                                                           min: tradingSetting.fomcTime.minute())
        
        highRiskEntryStartPicker.dateValue = Date.getNewDateFromTime(hour: tradingSetting.highRiskStart.hour(),
                                                                     min: tradingSetting.highRiskStart.minute())
        
        highRiskEntryEndPicker.dateValue = Date.getNewDateFromTime(hour: tradingSetting.highRiskEnd.hour(),
                                                                   min: tradingSetting.highRiskEnd.minute())
        
        lunchStartPicker.dateValue = Date.getNewDateFromTime(hour: tradingSetting.lunchStart.hour(),
                                                             min: tradingSetting.lunchStart.minute())
        
        lunchEndPicker.dateValue = Date.getNewDateFromTime(hour: tradingSetting.lunchEnd.hour(),
                                                           min: tradingSetting.lunchEnd.minute())
        
        sessionStartTimePicker.dateValue = Date.getNewDateFromTime(hour: tradingSetting.tradingStart.hour(),
                                                                   min: tradingSetting.tradingStart.minute())
        
        sessionEndTimePicker.dateValue = Date.getNewDateFromTime(hour: tradingSetting.tradingEnd.hour(),
                                                                 min: tradingSetting.tradingEnd.minute())
        
        liquidateTimePicker.dateValue = Date.getNewDateFromTime(hour: tradingSetting.clearTime.hour(),
                                                                min: tradingSetting.clearTime.minute())
        
        flatTimePicker.dateValue = Date.getNewDateFromTime(hour: tradingSetting.flatTime.hour(),
                                                           min: tradingSetting.flatTime.minute())
        
        dailyLossLimitField.stringValue = String(format: "%.2f", tradingSetting.maxDailyLossBase)
        highRiskTradesField.stringValue = String(format: "%d", tradingSetting.maxHighRiskEntryAllowed)
        losingTradesField.stringValue = String(format: "%d", tradingSetting.losingTradesToHalt)
        oppositeLosingTradesField.stringValue = String(format: "%d", tradingSetting.oppositeLosingTradesToHalt)
        maxDistanceToSRField.stringValue = String(format: "%.2f", tradingSetting.maxDistanceToSRBase)
        profitAvoidSameDirectionField.stringValue = String(format: "%.2f", tradingSetting.profitAvoidSameDirectionBase)
        
        simRealTimeCheckbox.state = tradingSetting.simulateTimePassage ? .on : .off
        avoidSameTradeCheckbox.state = tradingSetting.avoidTakingSameTrade ? .on : .off
        avoidSameLosingTradeCheckbox.state = tradingSetting.avoidTakingSameLosingTrade ? .on : .off
        byPassTradingTimeCheckbox.state = tradingSetting.byPassTradingTimeRestrictions ? .on : .off
        noEntryDuringLunchCheckbox.state = tradingSetting.noEntryDuringLunch ? .on : .off
        waitFinalizedSignalsCheckbox.state = tradingSetting.waitForFinalizedSignals ? .on : .off
        fomcDayCheckbox.state = tradingSetting.fomcDay ? .on : .off
        stoplossBufferField.stringValue = String(format: "%.2f", tradingSetting.buffer)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        setupUI()
        tradingSetting = config.tradingSettings[config.tradingSettingsSelection]
        
        switch config.tradingSettingsSelection {
        case 0:
            present1Button.state = .on
        case 1:
            present2Button.state = .on
        case 2:
            present3Button.state = .on
        case 3:
            present4Button.state = .on
        default:
            break
        }
    }
    
    @IBAction func presentPressed(_ sender: NSButton) {
        present1Button.state = .off
        present2Button.state = .off
        present3Button.state = .off
        present4Button.state = .off
        sender.state = .on
        
        guard sender.tag != config.tradingSettingsSelection else { return }
        
        config.setTradingSettingsSelection(newValue: sender.tag)
        tradingSetting = config.tradingSettings[sender.tag]
        
    }
    
    @IBAction func simRealTimeChecked(_ sender: NSButton) {
        switch sender.state {
        case .on:
            tradingSetting.setSimulateTimePassage(newValue: true)
        case .off:
            tradingSetting.setSimulateTimePassage(newValue: false)
        default:
            break
        }
        config.updateTradingSettings(settings: tradingSetting)
    }
    
    @IBAction func avoidSameTradeChecked(_ sender: NSButton) {
        switch sender.state {
        case .on:
            tradingSetting.setAvoidTakingSameTrade(newValue: true)
        case .off:
            tradingSetting.setAvoidTakingSameTrade(newValue: false)
        default:
            break
        }
        config.updateTradingSettings(settings: tradingSetting)
    }
    
    @IBAction func avoidSameLosingTrade(_ sender: NSButton) {
        switch sender.state {
        case .on:
            tradingSetting.setAvoidTakingSameLosingTrade(newValue: true)
        case .off:
            tradingSetting.setAvoidTakingSameLosingTrade(newValue: false)
        default:
            break
        }
        config.updateTradingSettings(settings: tradingSetting)
    }
    
    @IBAction func byPassTimeChecked(_ sender: NSButton) {
        switch sender.state {
        case .on:
            tradingSetting.setByPassTradingTimeRestrictions(newValue: true)
        case .off:
            tradingSetting.setByPassTradingTimeRestrictions(newValue: false)
        default:
            break
        }
        config.updateTradingSettings(settings: tradingSetting)
    }
    
    @IBAction func noEntryChecked(_ sender: NSButton) {
        switch sender.state {
        case .on:
            tradingSetting.setNoEntryDuringLunch(newValue: true)
        case .off:
            tradingSetting.setNoEntryDuringLunch(newValue: false)
        default:
            break
        }
        config.updateTradingSettings(settings: tradingSetting)
    }
    
    @IBAction func waitFinalizedSignalsCheckboxChecked(_ sender: NSButton) {
        switch sender.state {
        case .on:
            tradingSetting.setWaitForFinalizedSignals(newValue: true)
        case .off:
            tradingSetting.setWaitForFinalizedSignals(newValue: false)
        default:
            break
        }
        config.updateTradingSettings(settings: tradingSetting)
    }
    
    @IBAction func fomcDayCheckboxChecked(_ sender: NSButton) {
        switch sender.state {
        case .on:
            tradingSetting.setFomcDay(newValue: true)
        case .off:
            tradingSetting.setFomcDay(newValue: false)
        default:
            break
        }
        config.updateTradingSettings(settings: tradingSetting)
    }
    
    @IBAction func highRiskStartChanged(_ sender: NSDatePicker) {
        do {
            try tradingSetting.setHighRiskStart(newValue: sender.dateValue)
            config.updateTradingSettings(settings: tradingSetting)
        } catch (let error) {
            guard let configError = error as? ConfigError else { return }
            
            configError.displayErrorDialog()
            
            sender.dateValue = tradingSetting.highRiskStart
        }
    }
    
    @IBAction func highRiskEndChanged(_ sender: NSDatePicker) {
        do {
            try tradingSetting.setHighRiskEnd(newValue: sender.dateValue)
            config.updateTradingSettings(settings: tradingSetting)
        } catch (let error) {
            guard let configError = error as? ConfigError else { return }
            
            configError.displayErrorDialog()
            
            sender.dateValue = tradingSetting.highRiskEnd
        }
    }
    
    @IBAction func lunchStartChanged(_ sender: NSDatePicker) {
        do {
            try tradingSetting.setLunchStart(newValue: sender.dateValue)
            config.updateTradingSettings(settings: tradingSetting)
        } catch (let error) {
            guard let configError = error as? ConfigError else { return }
            
            configError.displayErrorDialog()
            
            sender.dateValue = tradingSetting.lunchStart
        }
    }
    
    @IBAction func lunchEndChanged(_ sender: NSDatePicker) {
        do {
            try tradingSetting.setLunchEnd(newValue: sender.dateValue)
            config.updateTradingSettings(settings: tradingSetting)
        } catch (let error) {
            guard let configError = error as? ConfigError else { return }
            
            configError.displayErrorDialog()
            
            sender.dateValue = tradingSetting.lunchEnd
        }
    }
    
    @IBAction func fomcTimeChanged(_ sender: NSDatePicker) {
        do {
            try tradingSetting.setFomcTime(newValue: sender.dateValue)
            config.updateTradingSettings(settings: tradingSetting)
        } catch (let error) {
            guard let configError = error as? ConfigError else { return }
            
            configError.displayErrorDialog()
            
            sender.dateValue = tradingSetting.fomcTime
        }
    }
    
    @IBAction func sessionStartChanged(_ sender: NSDatePicker) {
        do {
            try tradingSetting.setTradingStart(newValue: sender.dateValue)
            config.updateTradingSettings(settings: tradingSetting)
        } catch (let error) {
            guard let configError = error as? ConfigError else { return }
            
            configError.displayErrorDialog()
            
            sender.dateValue = tradingSetting.tradingStart
        }
    }
    
    @IBAction func sessionEndChanged(_ sender: NSDatePicker) {
        do {
            try tradingSetting.setTradingEnd(newValue: sender.dateValue)
            config.updateTradingSettings(settings: tradingSetting)
        } catch (let error) {
            guard let configError = error as? ConfigError else { return }
            
            configError.displayErrorDialog()
            
            sender.dateValue = tradingSetting.tradingEnd
        }
    }
    
    @IBAction func liquidationTimeChanged(_ sender: NSDatePicker) {
        do {
            try tradingSetting.setClearTime(newValue: sender.dateValue)
            config.updateTradingSettings(settings: tradingSetting)
        } catch (let error) {
            guard let configError = error as? ConfigError else { return }
            
            configError.displayErrorDialog()
            
            sender.dateValue = tradingSetting.clearTime
        }
    }
    
    @IBAction func flatPositionsTimeChanged(_ sender: NSDatePicker) {
        do {
            try tradingSetting.setFlatTime(newValue: sender.dateValue)
            config.updateTradingSettings(settings: tradingSetting)
        } catch (let error) {
            guard let configError = error as? ConfigError else { return }
            
            configError.displayErrorDialog()
            
            sender.dateValue = tradingSetting.flatTime
        }
    }
    
}

extension ConfigViewController: NSControlTextEditingDelegate {
    func controlTextDidEndEditing(_ notification: Notification) {
        if let textField = notification.object as? NSTextField {
            do {
                if textField == riskField {
                    try tradingSetting.setRiskMultiplier(newValue: textField.doubleValue)
                } else if textField == maxSLField {
                    try tradingSetting.setMaxRisk(newValue: textField.doubleValue)
                } else if textField == minSTPField {
                    try tradingSetting.setMinStop(newValue: textField.doubleValue)
                } else if textField == sweetspotDistanceField {
                    try tradingSetting.setSweetSpotMinDistance(newValue: textField.doubleValue)
                } else if textField == minProfitGreenBarField {
                    try tradingSetting.setGreenBarsExit(newValue: textField.doubleValue)
                } else if textField == minProfitByPass {
                    try tradingSetting.setSkipGreenBarsExit(newValue: textField.doubleValue)
                } else if textField == minProfitPullbackField {
                    try tradingSetting.setEnterOnPullback(newValue: textField.doubleValue)
                } else if textField == takeProfitField {
                    try tradingSetting.setTakeProfitBarLength(newValue: textField.doubleValue)
                } else if textField == dailyLossLimitField {
                    try tradingSetting.setMaxDailyLoss(newValue: textField.doubleValue)
                } else if textField == highRiskTradesField {
                    try tradingSetting.setMaxHighRiskEntryAllowed(newValue: textField.integerValue)
                } else if textField == maxDistanceToSRField {
                    try tradingSetting.setMaxDistanceToSR(newValue: textField.doubleValue)
                } else if textField == profitAvoidSameDirectionField {
                    try tradingSetting.setProfitAvoidSameDirection(newValue: textField.doubleValue)
                } else if textField == losingTradesField {
                    try tradingSetting.setLosingTradesToHalt(newValue: textField.integerValue)
                } else if textField == oppositeLosingTradesField {
                    try tradingSetting.setOppositeLosingTradesToHalt(newValue: textField.integerValue)
                } else if textField == stoplossBufferField {
                    try tradingSetting.setBuffer(newValue: textField.doubleValue)
                } else if textField == maxDDField {
                    try tradingSetting.setDrawdownLimit(newValue: textField.doubleValue)
                }
                
                config.updateTradingSettings(settings: tradingSetting)
            } catch (let error) {
                guard let configError = error as? ConfigError else { return }
                
                configError.displayErrorDialog()
            }
        }
    }
}
