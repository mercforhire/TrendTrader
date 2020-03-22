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
    
    private let DefaultTicker = "NQ 03-20"
    private let DefaultAccountLongName = "NinjaTrader Continuum (Demo)"
    private var DefaultBasePath = "/Users/lchen/Downloads/NinjaTrader/"
    private var DefaultIncomingPath = "/Users/lchen/Downloads/NinjaTrader/incoming"
    private var DefaultOutgoingPath = "/Users/lchen/Downloads/NinjaTrader/outgoing"
    private var DefaultAccountName = "Sim101"
    
    @IBOutlet weak var commissionField: NSTextField!
    @IBOutlet weak var exchangeField: NSTextField!
    @IBOutlet weak var longNameField: NSTextField!
    @IBOutlet weak var shortNameField: NSTextField!
    @IBOutlet weak var baseFolderField: NSTextField!
    @IBOutlet weak var inputFolderField: NSTextField!
    @IBOutlet weak var outputFolderField: NSTextField!
    @IBOutlet weak var nextButton: NSButton!
    
    private var commission: Double = 0
    private var exchange: String = ""
    private var longName: String = ""
    private var shortName: String = ""
    private var baseFolder: String = ""
    private var inputFolder: String = ""
    private var outputFolder: String = ""
    
    func setupUI() {
        commissionField.delegate = self
        exchangeField.delegate = self
        longNameField.delegate = self
        shortNameField.delegate = self
        
        baseFolderField.isEditable = false
        inputFolderField.isEditable = false
        outputFolderField.isEditable = false
    }
    
    func loadSettings() {
        commission = config.ntCommission
        exchange = config.ntExchange
        longName = config.ntAccountLongName ?? DefaultAccountLongName
        shortName = config.ntAccountName ?? DefaultAccountName
        baseFolder = config.ntBasePath ?? DefaultBasePath
        inputFolder = config.ntIncomingPath ?? DefaultIncomingPath
        outputFolder = config.ntOutgoingPath ?? DefaultOutgoingPath
        
        commissionField.stringValue = String(format: "%.2f",commission)
        exchangeField.stringValue = exchange
        longNameField.stringValue = longName
        shortNameField.stringValue = shortName
        baseFolderField.stringValue = baseFolder
        inputFolderField.stringValue = inputFolder
        outputFolderField.stringValue = outputFolder
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
                do {
                    try self.config.setNTBasePath(newValue: selectedPath)
                    self.baseFolder = selectedPath
                } catch(let error) {
                    guard let configError = error as? ConfigError else { return }
                    
                    configError.displayErrorDialog()
                }
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
                do {
                    try self.config.setNTIncomingPath(newValue: selectedPath)
                    self.inputFolder = selectedPath
                } catch (let error) {
                    guard let configError = error as? ConfigError else { return }
                    
                    configError.displayErrorDialog()
                }
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
                do {
                    try self.config.setNTOutgoingPath(newValue: selectedPath)
                    self.outputFolder = selectedPath
                } catch (let error) {
                    guard let configError = error as? ConfigError else { return }
                    
                    configError.displayErrorDialog()
                }
            }
            panel.close()
        }
    }
    
    @IBAction func nextPressed(_ sender: NSButton) {
        if verifySettings() {
            performSegue(withIdentifier: "showLiveTrader", sender: nil)
        }
    }
    
    func verifySettings(showError: Bool = false) -> Bool {
        if commission < 0 {
            showErrorDialog(text: "Invalid commission entry")
            return false
        }
        
        if exchange.length == 0 {
            showErrorDialog(text: "Invalid exchange")
            return false
        }
        
        if longName.length == 0 {
            showErrorDialog(text: "Invalid account long name")
            return false
        }
        
        if shortName.length == 0 {
            showErrorDialog(text: "Invalid account short name")
            return false
        }
        
        if baseFolder.length == 0 {
            showErrorDialog(text: "Invalid base folder path")
            return false
        }
        
        if inputFolder.length == 0 {
            showErrorDialog(text: "Invalid input folder path")
            return false
        }
        
        if outputFolder.length == 0 {
            showErrorDialog(text: "Invalid output folder path")
            return false
        }
        
        return true
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let vc = segue.destinationController as? LiveTradingViewController {
            
            vc.tradingMode = .ninjaTrader(accountId: <#T##String#>, commission: <#T##Double#>, ticker: <#T##String#>, name: <#T##String#>, accountLongName: <#T##String#>, accountName: <#T##String#>, basePath: <#T##String#>, incomingPath: <#T##String#>, outgoingPath: <#T##String#>)
        }
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
            do {
                if textField == commissionField {
                    try config.setNTCommission(newValue: commission)
                    commission = textField.doubleValue
                } else if textField == exchangeField {
                    try config.setNTExchange(newValue: exchange)
                    exchange = textField.stringValue
                } else if textField == longNameField {
                    try config.setNTAccountLongName(newValue: longName)
                    longName = textField.stringValue
                } else if textField == shortNameField {
                    try config.setNTAccountName(newValue: shortName)
                    shortName = textField.stringValue
                }
            } catch (let error) {
                guard let configError = error as? ConfigError else { return }
                
                configError.displayErrorDialog()
            }
        }
    }
}
