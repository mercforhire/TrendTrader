//
//  NTSettingsViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-03-08.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Cocoa

class NTSettingsViewController: NSViewController, NSTextFieldDelegate {
    let config = ConfigurationManager.shared
    private let DefaultName = "New Bot"
    
    @IBOutlet weak var selectionPicker: NSPopUpButton!
    @IBOutlet weak var addButton: NSButton!
    @IBOutlet weak var deleteButton: NSButton!
    @IBOutlet weak var botNameField: NSTextField!
    @IBOutlet weak var positionSizeField: NSTextField!
    @IBOutlet weak var symbolField: NSTextField!
    @IBOutlet weak var dollarPointField: NSTextField!
    @IBOutlet weak var commissionField: NSTextField!
    @IBOutlet weak var exchangeField: NSTextField!
    @IBOutlet weak var longNameField: NSTextField!
    @IBOutlet weak var shortNameField: NSTextField!
    @IBOutlet weak var baseFolderField: NSTextField!
    @IBOutlet weak var inputFolderField: NSTextField!
    @IBOutlet weak var outputFolderField: NSTextField!
    @IBOutlet weak var nextButton: NSButton!
    
    private var ntSettings: [String: NTSettings] = [:]
    private var settingsNames: [String] {
        return Array(ntSettings.keys)
    }
    private var selectedSettingName: String! {
        didSet {
            botNameField.stringValue = selectedSettingName
        }
    }
    private var selectedSettings: NTSettings! {
        didSet {
            positionSizeField.integerValue = selectedSettings.positionSize
            symbolField.stringValue = selectedSettings.ticker
            commissionField.stringValue = String(format: "%.2f", selectedSettings.commission)
            dollarPointField.stringValue = String(format: "%.2f", selectedSettings.pointValue)
            exchangeField.stringValue = selectedSettings.exchange
            longNameField.stringValue = selectedSettings.accLongName
            shortNameField.stringValue = selectedSettings.accName
            baseFolderField.stringValue = selectedSettings.basePath
            inputFolderField.stringValue = selectedSettings.incomingPath
            outputFolderField.stringValue = selectedSettings.outgoingPath
        }
    }
    
    func setupUI() {
        botNameField.delegate = self
        positionSizeField.delegate = self
        symbolField.delegate = self
        commissionField.delegate = self
        dollarPointField.delegate = self
        exchangeField.delegate = self
        longNameField.delegate = self
        shortNameField.delegate = self
        
        baseFolderField.isEditable = false
        inputFolderField.isEditable = false
        outputFolderField.isEditable = false
    }
    
    func loadSettings() {
        ntSettings = config.ntSettings
        
        if ntSettings.isEmpty {
            ntSettings[DefaultName] = NTSettings()
        }
        
        guard let defaultSelectionName = settingsNames.first,
            let defaultSelection: NTSettings = ntSettings[defaultSelectionName] else {
                print("ERROR: ntSettings shouldn't be empty.")
                return
        }
        selectedSettings = defaultSelection
        selectedSettingName = defaultSelectionName
        selectionPicker.addItems(withTitles: settingsNames)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        setupUI()
        loadSettings()
        _ = verifySettings()
    }
    
    @IBAction func selectBaseFolder(_ sender: NSButton) {
        guard let window = view.window else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { result in
            if result == .OK, let selectedPath = panel.url?.path {
                self.selectedSettings.basePath = selectedPath
                self.baseFolderField.stringValue = selectedPath
            }
            panel.close()
        }
    }
    
    @IBAction func selectInputFolder(_ sender: NSButton) {
        guard let window = view.window else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { result in
            if result == .OK, let selectedPath = panel.url?.path {
                self.selectedSettings.incomingPath = selectedPath
                self.inputFolderField.stringValue = selectedPath
            }
            panel.close()
        }
    }
    
    @IBAction func selectOutFolder(_ sender: NSButton) {
        guard let window = view.window else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { result in
            if result == .OK, let selectedPath = panel.url?.path {
                self.selectedSettings.outgoingPath = selectedPath
                self.outputFolderField.stringValue = selectedPath
            }
            panel.close()
        }
    }
    
    @IBAction func nextPressed(_ sender: NSButton) {
        if verifySettings() {
            config.setNTSettings(settings: ntSettings)
            performSegue(withIdentifier: "showLiveTrader", sender: nil)
            view.window?.close()
        }
    }
    
    func verifySettings(showError: Bool = false) -> Bool {
        if selectedSettingName == DefaultName {
            showErrorDialog(text: "Must rename settings name")
            return false
        }
        
        if selectedSettings.positionSize < 1 {
            showErrorDialog(text: "Invalid position size")
            return false
        }
        
        if selectedSettings.ticker.length == 0 {
            showErrorDialog(text: "Invalid ticker entry")
            return false
        }
        
        if selectedSettings.commission < 0 {
            showErrorDialog(text: "Invalid commission entry")
            return false
        }
        
        if selectedSettings.pointValue > 0 {
            showErrorDialog(text: "Point value must be 1 or more")
            return false
        }
        
        if selectedSettings.exchange.length == 0 {
            showErrorDialog(text: "Invalid exchange")
            return false
        }
        
        if selectedSettings.accLongName.length == 0 {
            showErrorDialog(text: "Invalid account long name")
            return false
        }
        
        if selectedSettings.accName.length == 0 {
            showErrorDialog(text: "Invalid account short name")
            return false
        }
        
        if selectedSettings.basePath.length == 0 {
            showErrorDialog(text: "Invalid base folder path")
            return false
        }
        
        if selectedSettings.incomingPath.length == 0 {
            showErrorDialog(text: "Invalid input folder path")
            return false
        }
        
        if selectedSettings.outgoingPath.length == 0 {
            showErrorDialog(text: "Invalid output folder path")
            return false
        }
        
        return true
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let vc = segue.destinationController as? LiveTradingViewController {
            
            vc.tradingMode = .ninjaTrader(accountId: selectedSettings.accName,
                                          commission: selectedSettings.commission,
                                          ticker: selectedSettings.ticker,
                                          exchange: selectedSettings.exchange,
                                          accountLongName: selectedSettings.accLongName,
                                          basePath: selectedSettings.basePath,
                                          incomingPath: selectedSettings.incomingPath,
                                          outgoingPath: selectedSettings.outgoingPath)
        }
    }
    
    @IBAction func addPressed(_ sender: NSButton) {
        
    }
    
    @IBAction func deletePressed(_ sender: NSButton) {
        
    }
    
    @IBAction func selectionChanged(_ sender: NSPopUpButton) {
        
    }
    
    private func showErrorDialog(text: String) {
        let alert = NSAlert()
        alert.messageText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

extension NTSettingsViewController: NSControlTextEditingDelegate {
    func controlTextDidEndEditing(_ notification: Notification) {
        if let textField = notification.object as? NSTextField {
            if textField == positionSizeField {
                selectedSettings.positionSize = textField.integerValue
            } else if textField == symbolField {
                selectedSettings.ticker = textField.stringValue
            } else if textField == commissionField {
                selectedSettings.commission = textField.doubleValue
            } else if textField == exchangeField {
                selectedSettings.exchange = textField.stringValue
            } else if textField == longNameField {
                selectedSettings.accLongName = textField.stringValue
            } else if textField == shortNameField {
                selectedSettings.accName = textField.stringValue
            }
        }
    }
}
