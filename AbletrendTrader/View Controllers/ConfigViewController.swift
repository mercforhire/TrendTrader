//
//  ConfigViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-27.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Cocoa

class ConfigViewController: NSViewController {
    let config = Config.shared
    
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
    @IBOutlet private weak var platformCombo: NSComboBox!
    @IBOutlet private weak var byPassTradingTimeCheckbox: NSButton!
    @IBOutlet private weak var noEntryDuringLunchCheckbox: NSButton!
    @IBOutlet private weak var ninjaPathField: NSTextField!
    
    private var selectedFolderPath: String = "" {
        didSet {
            config.ntIncomingPath = selectedFolderPath
            ninjaPathField.stringValue = selectedFolderPath
        }
    }
    
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
        ninjaPathField.isEditable = false
        platformCombo.isEnabled = false
        platformCombo.usesDataSource = true
        platformCombo.dataSource = self
    }
    
    func loadConfig() {
        maxSLField.stringValue = String(format: "%.2f", config.maxRisk)
        minSTPField.stringValue = String(format: "%.2f", config.minBarStop)
        sweetspotDistanceField.stringValue = String(format: "%.2f", config.sweetSpotMinDistance)
        minProfitGreenBarField.stringValue = String(format: "%.2f", config.greenBarsExit)
        minProfitByPass.stringValue = String(format: "%.2f", config.skipGreenBarsExit)
        minProfitPullbackField.stringValue = String(format: "%.2f", config.enterOnPullback)
        highRiskEntryStartPicker.dateValue = Date().getNewDateFromTime(hour: config.highRiskStart.0, min: config.highRiskStart.1)
        highRiskEntryEndPicker.dateValue = Date().getNewDateFromTime(hour: config.highRiskEnd.0, min: config.highRiskEnd.1)
        sessionStartTimePicker.dateValue = Date().getNewDateFromTime(hour: config.tradingStart.0, min: config.tradingStart.1)
        liquidateTimePicker.dateValue = Date().getNewDateFromTime(hour: config.clearTime.0, min: config.clearTime.1)
        flatTimePicker.dateValue = Date().getNewDateFromTime(hour: config.flatTime.0, min: config.flatTime.1)
        dailyLossLimitPicker.stringValue = String(format: "%.2f", config.maxDailyLoss)
        ninjaPathField.stringValue = config.ntIncomingPath
        selectedFolderPath = config.ntIncomingPath
        
        switch config.liveTradingMode {
        case .interactiveBroker:
            platformCombo.selectItem(at: 0)
        case .ninjaTrader:
            platformCombo.selectItem(at: 1)
        }
        NSApp.keyWindow?.makeFirstResponder(nil)
        
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
            config.byPassTradingTimeRestrictions = true
        case .off:
            config.byPassTradingTimeRestrictions = false
        default:
            break
        }
    }
    
    @IBAction func noEntryChecked(_ sender: NSButton) {
        switch sender.state {
        case .on:
            config.noEntryDuringLunch = true
        case .off:
            config.noEntryDuringLunch = false
        default:
            break
        }
    }
    
    @IBAction func selectFolderPressed(_ sender: NSButton) {
        guard let window = view.window else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { result in
            if result == .OK, let selectedPath = panel.url?.path {
                self.selectedFolderPath = selectedPath
            }
            panel.close()
        }
    }
}

extension ConfigViewController: NSComboBoxDataSource {
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        return 2
    }

    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        switch index {
        case 0:
            return LiveTradingMode.interactiveBroker.name()
        case 1:
            return LiveTradingMode.ninjaTrader.name()
        default:
            break
        }
        
        return nil
    }
}
