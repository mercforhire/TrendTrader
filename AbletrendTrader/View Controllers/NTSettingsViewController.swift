//
//  NTSettingsViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2020-03-08.
//  Copyright © 2020 LeonChen. All rights reserved.
//

import Cocoa

class NTSettingsViewController: NSViewController, NSTextFieldDelegate, NSWindowDelegate {
    let config = ConfigurationManager.shared
    
    @IBOutlet weak var server1MinField: NSTextField!
    @IBOutlet weak var server2MinField: NSTextField!
    @IBOutlet weak var server3MinField: NSTextField!
    @IBOutlet weak var selectionPicker: NSPopUpButton!
    @IBOutlet weak var addButton: NSButton!
    @IBOutlet weak var deleteButton: NSButton!
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
    
    private var selectedSettingsIndex: Int?
    private var selectedSettings: NTSettings? {
        didSet {
            if let selectedSettings = selectedSettings {
                server1MinField.stringValue = selectedSettings.server1MinURL
                server2MinField.stringValue = selectedSettings.server2MinURL
                server3MinField.stringValue = selectedSettings.server3MinURL
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
            } else {
                server1MinField.stringValue = ""
                server2MinField.stringValue = ""
                server3MinField.stringValue = ""
                positionSizeField.stringValue = ""
                symbolField.stringValue = ""
                commissionField.stringValue = ""
                dollarPointField.stringValue = ""
                exchangeField.stringValue = ""
                longNameField.stringValue = ""
                shortNameField.stringValue = ""
                baseFolderField.stringValue = ""
                inputFolderField.stringValue = ""
                outputFolderField.stringValue = ""
            }
            
        }
    }
    
    func setupUI() {
        server1MinField.delegate = self
        server2MinField.delegate = self
        server3MinField.delegate = self
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
        if config.ntSettings.isEmpty {
            config.addNTSettings(settings: NTSettings())
        }
        
        guard let defaultSelection = config.ntSettings.first else {
            print("ERROR: ntSettings shouldn't be empty.")
            return
        }
        
        selectedSettings = defaultSelection
        selectedSettingsIndex = 0
        selectionPicker.removeAllItems()
        for i in 1...config.ntSettings.count {
            selectionPicker.addItem(withTitle: "Settings - \(i)")
        }
        
        deleteButton.isEnabled = config.ntSettings.count > 1
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        setupUI()
        loadSettings()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        view.window?.delegate = self
    }
    
    @IBAction func selectBaseFolder(_ sender: NSButton) {
        guard let window = view.window else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { result in
            if result == .OK, let selectedPath = panel.url?.path {
                self.selectedSettings?.basePath = selectedPath
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
                self.selectedSettings?.incomingPath = selectedPath
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
                self.selectedSettings?.outgoingPath = selectedPath
                self.outputFolderField.stringValue = selectedPath
            }
            panel.close()
        }
    }
    
    @IBAction func nextPressed(_ sender: NSButton) {
        if let selectedSettingsIndex = selectedSettingsIndex,
            let selectedSettings = selectedSettings,
            verifySettings() {
            
            config.updateNTSettings(index: selectedSettingsIndex, settings: selectedSettings)
            performSegue(withIdentifier: "showLiveTrader", sender: nil)
            view.window?.close()
        }
    }
    
    func verifySettings(showError: Bool = false) -> Bool {
        guard let selectedSettings = selectedSettings else { return false }
        
        if !validateServerURL(url: selectedSettings.server1MinURL) {
            showErrorDialog(text: ConfigError.serverURLError.displayMessage())
            return false
        }
        
        if !validateServerURL(url: selectedSettings.server2MinURL) {
            showErrorDialog(text: ConfigError.serverURLError.displayMessage())
            return false
        }
        
        if !validateServerURL(url: selectedSettings.server3MinURL) {
            showErrorDialog(text: ConfigError.serverURLError.displayMessage())
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
        
        if selectedSettings.pointValue < 1{
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
    
    private func validateServerURL(url: String) -> Bool {
        return url.range(of: config.IPRegex, options: .regularExpression) != nil
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let vc = segue.destinationController as? LiveTradingViewController,
            let selectedSettings = selectedSettings {
            vc.server1minURL = selectedSettings.server1MinURL
            vc.server2minURL = selectedSettings.server2MinURL
            vc.server3minURL = selectedSettings.server3MinURL
            vc.tradingMode = .ninjaTrader(accountId: selectedSettings.accName,
                                          commission: selectedSettings.commission,
                                          ticker: selectedSettings.ticker,
                                          pointValue: selectedSettings.pointValue,
                                          exchange: selectedSettings.exchange,
                                          accountLongName: selectedSettings.accLongName,
                                          basePath: selectedSettings.basePath,
                                          incomingPath: selectedSettings.incomingPath,
                                          outgoingPath: selectedSettings.outgoingPath)
        }
    }
    
    @IBAction func addPressed(_ sender: NSButton) {
        config.addNTSettings(settings: NTSettings())
        
        guard let newSelection = config.ntSettings.last else {
            print("ERROR: ntSettings shouldn't be empty.")
            return
        }
        
        selectedSettingsIndex = config.ntSettings.count - 1
        selectedSettings = newSelection
        selectionPicker.addItem(withTitle: "Settings - \(config.ntSettings.count)")
        selectionPicker.selectItem(at: config.ntSettings.count - 1)
        
        deleteButton.isEnabled = config.ntSettings.count > 1
    }
    
    @IBAction func deletePressed(_ sender: NSButton) {
        guard config.ntSettings.count > 1, let selectedSettingsIndex = selectedSettingsIndex else { return }
        
        config.removeNTSettings(index: selectedSettingsIndex)
        loadSettings()
    }
    
    @IBAction func savePressed(_ sender: NSButton) {
        if let selectedSettingsIndex = selectedSettingsIndex,
            let selectedSettings = selectedSettings,
            verifySettings() {
            
            config.updateNTSettings(index: selectedSettingsIndex, settings: selectedSettings)
        }
    }
    
    @IBAction func selectionChanged(_ sender: NSPopUpButton) {
        guard sender.indexOfSelectedItem < config.ntSettings.count,
            config.ntSettings[sender.indexOfSelectedItem] != selectedSettings else { return }
        
        selectedSettings = config.ntSettings[sender.indexOfSelectedItem]
        selectedSettingsIndex = sender.indexOfSelectedItem
    }
    
    private func showErrorDialog(text: String) {
        let alert = NSAlert()
        alert.messageText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if let selectedSettingsIndex = selectedSettingsIndex,
            let selectedSettings = selectedSettings,
            verifySettings() {
            
            config.updateNTSettings(index: selectedSettingsIndex, settings: selectedSettings)
            
            return true
        }
        return false
    }
}

extension NTSettingsViewController: NSControlTextEditingDelegate {
    func controlTextDidEndEditing(_ notification: Notification) {
        if let textField = notification.object as? NSTextField {
            if textField == server1MinField {
                selectedSettings?.server1MinURL = textField.stringValue
            } else if textField == server2MinField {
                selectedSettings?.server2MinURL = textField.stringValue
            } else if textField == server3MinField {
                selectedSettings?.server3MinURL = textField.stringValue
            } else if textField == positionSizeField {
                selectedSettings?.positionSize = textField.integerValue
            } else if textField == symbolField {
                selectedSettings?.ticker = textField.stringValue
            } else if textField == commissionField {
                selectedSettings?.commission = textField.doubleValue
            } else if textField == dollarPointField {
                selectedSettings?.pointValue = textField.doubleValue
            } else if textField == exchangeField {
                selectedSettings?.exchange = textField.stringValue
            } else if textField == longNameField {
                selectedSettings?.accLongName = textField.stringValue
            } else if textField == shortNameField {
                selectedSettings?.accName = textField.stringValue
            }
        }
    }
}
