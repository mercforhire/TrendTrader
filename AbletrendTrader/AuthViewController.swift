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
    
    @IBOutlet weak var authStatusLabel: NSTextField!
    @IBOutlet weak var validateSSOButton: NSButton!
    @IBOutlet weak var getStatusButton: NSButton!
    @IBOutlet weak var reauthButton: NSButton!
    @IBOutlet weak var logOffButton: NSButton!
    @IBOutlet weak var accountsPicker: NSComboBox!
    @IBOutlet weak var accountInfoLabel: NSTextField!
    @IBOutlet weak var tickerField: NSTextField!
    @IBOutlet weak var conIdField: NSTextField!
    @IBOutlet weak var sizeField: NSTextField!
    @IBOutlet weak var goToSimButton: NSButton!
    @IBOutlet weak var goToLiveButton: NSButton!
    
    private var authenticated: Bool? {
        didSet {
            if authenticated == true {
                authStatusLabel.stringValue = "Authenticated"
                timer = Timer.scheduledTimer(timeInterval: TimeInterval(60.0), target: self, selector: #selector(pingServer), userInfo: nil, repeats: true)
                logOffButton.isEnabled = true
                goToLiveButton.isEnabled = true
                fetchAccounts()
            } else if authenticated == false {
                authStatusLabel.stringValue = "Not authenticated"
                timer?.invalidate()
                logOffButton.isEnabled = false
                goToLiveButton.isEnabled = false
            } else {
                authStatusLabel.stringValue = "--"
                timer?.invalidate()
                logOffButton.isEnabled = false
                goToLiveButton.isEnabled = false
            }
        }
    }
    
    private var ssoToken: SSOToken?
    private var timer: Timer?
    private var accounts: [Account]? {
        didSet {
            accountsPicker.reloadData()
        }
    }
   private  var selectedAccount: Account? {
        didSet {
            IBNetworkManager.shared.selectedAccount = selectedAccount
            accountInfoLabel.stringValue = selectedAccount?.accountTitle ?? "No account selected"
        }
    }
    
    func setupUI() {
        accountsPicker.usesDataSource = true
        accountsPicker.dataSource = self
        logOffButton.isEnabled = false
        goToLiveButton.isEnabled = false
        
        tickerField.stringValue = config.ticker
        tickerField.isEditable = false
        conIdField.stringValue = String(format: "%d", config.conId)
        conIdField.isEditable = false
        sizeField.stringValue = String(format: "%d", config.positionSize)
        sizeField.isEditable = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        setupUI()
        
        validateSSOPressed(validateSSOButton)
        getStatusPressed(getStatusButton)
    }
    
    @objc
    private func pingServer() {
        IBNetworkManager.shared.pingServer { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                self.ssoToken = nil
                self.authenticated = false
            case .failure:
                break
            }
        }
    }
    
    func fetchAccounts() {
        IBNetworkManager.shared.fetchAccounts { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let accounts):
                self.accounts = accounts
                if let defaultAccount = accounts.first {
                    self.accountsPicker.selectItem(at: 0)
                    self.selectedAccount = defaultAccount
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
            case .failure:
                break
            }
        }
    }
    
    @IBAction func validateSSOPressed(_ sender: NSButton) {
        sender.isEnabled = false
        IBNetworkManager.shared.validateSSO { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let token):
                self.ssoToken = token
            case .failure:
                self.ssoToken = nil
            }
            
            sender.isEnabled = true
        }
    }
    
    @IBAction func getStatusPressed(_ sender: NSButton) {
        sender.isEnabled = false
        IBNetworkManager.shared.fetchAuthenticationStatus { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let status):
                self.authenticated = status.authenticated
            case .failure:
                self.authenticated = false
            }
            
            sender.isEnabled = true
        }
    }
    
    @IBAction func reAuthPressed(_ sender: NSButton) {
        sender.isEnabled = false
        IBNetworkManager.shared.reauthenticate { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                self.authenticated = true
            case .failure:
                break
            }
            
            sender.isEnabled = true
        }
    }
    
    @IBAction func logOffPressed(_ sender: NSButton) {
        sender.isEnabled = false
        IBNetworkManager.shared.logOut { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                self.ssoToken = nil
                self.authenticated = false
            case .failure:
                break
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
