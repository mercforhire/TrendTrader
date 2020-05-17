//
//  ConfigurationManager.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-24.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class ConfigurationManager {
    static let shared = ConfigurationManager()
    private let defaults: UserDefaults = UserDefaults.standard
    let IPRegex = #"http:\/\/\d{0,3}.\d{0,3}.\d{0,3}.\d{0,3}:\d{0,4}\/"#
    
    private(set) var server1MinURL: String
    private(set) var server2MinURL: String
    private(set) var server3MinURL: String
    private(set) var tradingSettingsSelection: Int
    private(set) var tradingSettings: [TradingSettings]
    private(set) var accountSettings: [AccountSettings]
    
    init() {
        let defaultSettings: NSDictionary = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "DefaultSettings", ofType: "plist")!)!
        
        self.server1MinURL = defaults.object(forKey: "server_1min_url") as? String ?? defaultSettings["default_ip"] as! String
        self.server2MinURL = defaults.object(forKey: "server_2min_url") as? String ?? defaultSettings["default_ip"] as! String
        self.server3MinURL = defaults.object(forKey: "server_3min_url") as? String ?? defaultSettings["default_ip"] as! String
        self.tradingSettingsSelection = defaults.object(forKey: "trading_settings_selection") as? Int ?? 0
        
        if let data = UserDefaults.standard.value(forKey:"trading_settings") as? Data {
            self.tradingSettings = (try? PropertyListDecoder().decode(Array<TradingSettings>.self, from: data)) ?? [TradingSettings(), TradingSettings(), TradingSettings(), TradingSettings()]
        } else {
            self.tradingSettings = [TradingSettings(), TradingSettings(), TradingSettings(), TradingSettings()]
        }
        
        if let data = UserDefaults.standard.value(forKey:"nt_settings") as? Data {
            self.accountSettings = (try? PropertyListDecoder().decode(Array<AccountSettings>.self, from: data)) ?? []
        } else {
            self.accountSettings = []
        }
    }
    
    func setServer1MinURL(newValue: String) throws {
        if newValue.range(of: IPRegex, options: .regularExpression) != nil {
            server1MinURL = newValue
            saveToDefaults(newValue: newValue, key: "server_1min_url")
            return
        }
        
        throw ConfigError.serverURLError
    }
    
    func setServer2MinURL(newValue: String) throws {
        if newValue.range(of: IPRegex, options: .regularExpression) != nil {
            server2MinURL = newValue
            saveToDefaults(newValue: newValue, key: "server_2min_url")
            return
        }
        
        throw ConfigError.serverURLError
    }
    
    func setServer3MinURL(newValue: String) throws {
        if newValue.range(of: IPRegex, options: .regularExpression) != nil {
            server3MinURL = newValue
            saveToDefaults(newValue: newValue, key: "server_3min_url")
            return
        }
        
        throw ConfigError.serverURLError
    }
    
    func setTradingSettingsSelection(newValue: Int) {
        tradingSettingsSelection = newValue
        saveToDefaults(newValue: newValue, key: "trading_settings_selection")
    }
    
    func updateTradingSettings(settings: TradingSettings) {
        guard tradingSettingsSelection < tradingSettings.count else { return }
        
        tradingSettings[tradingSettingsSelection] = settings
        
        UserDefaults.standard.set(try? PropertyListEncoder().encode(tradingSettings), forKey: "trading_settings")
        UserDefaults.standard.synchronize()
    }
    
    func removeTradingSettings(index: Int) {
        guard index < accountSettings.count else { return }
        
        accountSettings.remove(at: index)
        
        UserDefaults.standard.set(try? PropertyListEncoder().encode(tradingSettings), forKey: "trading_settings")
        UserDefaults.standard.synchronize()
    }
    
    func addNTSettings(settings: AccountSettings) {
        accountSettings.append(settings)
        
        UserDefaults.standard.set(try? PropertyListEncoder().encode(accountSettings), forKey: "nt_settings")
        UserDefaults.standard.synchronize()
        print("Saved value:", accountSettings, "to key", "nt_settings")
    }
    
    func updateNTSettings(index: Int, settings: AccountSettings) {
        guard index < accountSettings.count else { return }
        
        accountSettings[index] = settings
        
        UserDefaults.standard.set(try? PropertyListEncoder().encode(accountSettings), forKey: "nt_settings")
        UserDefaults.standard.synchronize()
        print("Saved value:", accountSettings, "to key", "nt_settings")
    }
    
    func removeNTSettings(index: Int) {
        guard index < accountSettings.count else { return }
        
        accountSettings.remove(at: index)
        
        UserDefaults.standard.set(try? PropertyListEncoder().encode(accountSettings), forKey: "nt_settings")
        UserDefaults.standard.synchronize()
        print("Saved value:", accountSettings, "to key", "nt_settings")
    }
    
    private func saveToDefaults(newValue: Any, key: String) {
        UserDefaults.standard.set(newValue, forKey: key)
        UserDefaults.standard.synchronize()
        print("Saved value:", newValue, "to key", key)
    }
}
