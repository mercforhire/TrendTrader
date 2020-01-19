//
//  AuthViewController.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-29.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Cocoa

class AuthViewController: NSViewController {
    private let config = Config.shared
    private let networkManager = IBNetworkManager.shared
    
    @IBOutlet weak var authStatusLabel: NSTextField!
    @IBOutlet weak var validateSSOButton: NSButton!
    @IBOutlet weak var getStatusButton: NSButton!
    @IBOutlet weak var reauthButton: NSButton!
    @IBOutlet weak var accountsPicker: NSComboBox!
    @IBOutlet weak var accountInfoLabel: NSTextField!
    @IBOutlet weak var tickerField: NSTextField!
    @IBOutlet weak var conIdField: NSTextField!
    @IBOutlet weak var sizeField: NSTextField!
    @IBOutlet weak var goToSimButton: NSButton!
    @IBOutlet weak var goToLiveButton: NSButton!
    @IBOutlet weak var ipAddressField: NSTextField!
    
    private var authenticated: Bool? {
        didSet {
            if authenticated == true {
                authStatusLabel.stringValue = "Authenticated"
                goToLiveButton.isEnabled = true
            } else if authenticated == false {
                authStatusLabel.stringValue = "Not authenticated"
                goToLiveButton.isEnabled = config.liveTradingMode == .ninjaTrader
            } else {
                authStatusLabel.stringValue = "--"
                goToLiveButton.isEnabled = config.liveTradingMode == .ninjaTrader
            }
        }
    }
    
    private var timer: Timer?
    private var accounts: [Account]? {
        didSet {
            accountsPicker.reloadData()
        }
    }
   private  var selectedAccount: Account? {
        didSet {
            networkManager.selectedAccount = selectedAccount
            accountInfoLabel.stringValue = selectedAccount?.accountTitle ?? "No account selected"
        }
    }
    
    func setupUI() {
        accountsPicker.usesDataSource = true
        accountsPicker.dataSource = self
        
        tickerField.stringValue = config.ticker
        tickerField.isEditable = false
        conIdField.stringValue = String(format: "%d", config.conId)
        conIdField.isEditable = false
        sizeField.stringValue = String(format: "%d", config.positionSize)
        sizeField.isEditable = false
        ipAddressField.stringValue = config.dataServerURL
        ipAddressField.isEditable = false
        
        if config.liveTradingMode == .interactiveBroker {
            goToLiveButton.isEnabled = false
        } else {
            validateSSOButton.isEnabled = false
            reauthButton.isEnabled = false
            getStatusButton.isEnabled = false
            goToLiveButton.isEnabled = true
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        setupUI()
        
        if config.liveTradingMode == .interactiveBroker {
            validateSSOPressed(validateSSOButton)
            getStatusPressed(getStatusButton)
            timer = Timer.scheduledTimer(timeInterval: TimeInterval(30.0),
                                         target: self,
                                         selector: #selector(pingServer),
                                         userInfo: nil,
                                         repeats: true)
        }
    }
    
    @objc
    private func pingServer() {
        networkManager.pingServer { [weak self] success in
            guard let self = self else { return }
            
            if success {
                if self.authenticated != true {
                    print("Pinging server success at", Date().hourMinuteSecond())
                    self.authenticated = true
                }
            } else {
                self.authenticated = false
                print("Pinging server failed, attempting to re-authenticate")
                self.reAuthPressed(self.reauthButton)
            }
        }
    }
    
    func fetchAccounts() {
        networkManager.fetchAccounts { [weak self] accounts in
            guard let self = self else { return }
            
            if let accounts = accounts {
                self.accounts = accounts
                if let defaultAccount = accounts.first {
                    self.accountsPicker.selectItem(at: 0)
                    self.selectedAccount = defaultAccount
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
            }
        }
    }
    
    @IBAction func validateSSOPressed(_ sender: NSButton) {
        sender.isEnabled = false
        networkManager.validateSSO { token in
            
            if token != nil {
                print("Validate SSO success")
            } else {
                print("Validate SSO failed")
            }
            sender.isEnabled = true
        }
    }
    
    @IBAction func getStatusPressed(_ sender: NSButton) {
        sender.isEnabled = false
        networkManager.fetchAuthenticationStatus { [weak self] status in
            guard let self = self else { return }
            
            self.authenticated = status?.authenticated
            if self.authenticated ?? false {
                print("Server authenticated at", Date().hourMinuteSecond())
                self.fetchAccounts()
            }
            sender.isEnabled = true
        }
    }
    
    @IBAction func reAuthPressed(_ sender: NSButton) {
        sender.isEnabled = false
        networkManager.reauthenticate { [weak self] success in
            guard let self = self else { return }
            
            if success {
                self.getStatusPressed(self.getStatusButton)
            }
            sender.isEnabled = true
        }
    }
    
    @IBAction func accountSelected(_ sender: NSComboBox) {
        if let selectedAccount = accounts?[sender.selectedTag()] {
            self.selectedAccount = selectedAccount
        }
    }
}

extension AuthViewController: NSComboBoxDataSource {
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        return accounts?.count ?? 0
    }

    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        return accounts?[index].accountId ?? "[ACCOUNT]"
    }
}
