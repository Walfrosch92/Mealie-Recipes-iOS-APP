import SwiftUI
import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - Initialisierung
    private init() {
        // Sprache initialisieren
        self.selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage")
            ?? Locale.current.language.languageCode?.identifier ?? "de"

        // Eingeklappte Kategorien initialisieren
        let savedArray = UserDefaults.standard.stringArray(forKey: "collapsedShoppingCategories") ?? []
        self.collapsedShoppingCategories = Set(savedArray)

        // API-Version initialisieren
        let savedVersion = UserDefaults.standard.string(forKey: "mealieAPIVersion")
        self.apiVersion = MealieAPIVersion(rawValue: savedVersion ?? "") ?? .v2_8
        
        // Rezeptbilder-Einstellung initialisieren
        if UserDefaults.standard.object(forKey: "showRecipeImages") == nil {
            // Standardwert auf true setzen, wenn noch nicht gespeichert
            self.showRecipeImages = true
            UserDefaults.standard.set(true, forKey: "showRecipeImages")
        } else {
            self.showRecipeImages = UserDefaults.standard.bool(forKey: "showRecipeImages")
        }
        
        // Logging-Einstellung initialisieren
        if UserDefaults.standard.object(forKey: "enableLogging") == nil {
            // Standardwert auf true setzen
            self.enableLogging = true
            UserDefaults.standard.set(true, forKey: "enableLogging")
        } else {
            self.enableLogging = UserDefaults.standard.bool(forKey: "enableLogging")
        }
        
        // API Service konfigurieren NACH der Initialisierung
        APIService.shared.setAPIVersion(self.apiVersion)
    }

    // MARK: - Logging-Einstellung
    @Published var enableLogging: Bool {
        didSet {
            UserDefaults.standard.set(enableLogging, forKey: "enableLogging")
            
            if enableLogging {
                // Logging starten wenn aktiviert
                LogManager.shared.startLogging()
                LogManager.shared.info("📝 Logging aktiviert")
            } else {
                LogManager.shared.info("📝 Logging deaktiviert")
            }
        }
    }

    // MARK: - Rezeptbilder-Einstellung
    @Published var showRecipeImages: Bool {
        didSet {
            UserDefaults.standard.set(showRecipeImages, forKey: "showRecipeImages")
            
            if enableLogging {
                LogManager.shared.info("🖼️ Rezeptbilder-Einstellung: \(showRecipeImages ? "aktiviert" : "deaktiviert")")
            }
        }
    }

    // MARK: - API-Version
    @Published var apiVersion: MealieAPIVersion {
        didSet {
            UserDefaults.standard.set(apiVersion.rawValue, forKey: "mealieAPIVersion")
            APIService.shared.setAPIVersion(apiVersion)
            
            if enableLogging {
                LogManager.shared.info("🔧 API-Version geändert: \(apiVersion.rawValue)")
            }
        }
    }

    // MARK: - Eingeklappte Kategorien merken
    @Published var collapsedShoppingCategories: Set<String> {
        didSet {
            let array = Array(collapsedShoppingCategories)
            UserDefaults.standard.set(array, forKey: "collapsedShoppingCategories")
            
            if enableLogging {
                LogManager.shared.info("📦 Eingeklappte Kategorien aktualisiert: \(array.count) Kategorien")
            }
        }
    }

    // MARK: - Sprache (wird in Views beobachtet)
    @Published var selectedLanguage: String {
        didSet {
            UserDefaults.standard.set(selectedLanguage, forKey: "selectedLanguage")
            
            if enableLogging {
                LogManager.shared.info("🌐 Sprache geändert: \(selectedLanguage)")
            }
        }
    }

    // MARK: - App-Logo-Auswahl
    var selectedLogo: String {
        get { UserDefaults.standard.string(forKey: "selectedLogo") ?? "Classic" }
        set {
            UserDefaults.standard.set(newValue, forKey: "selectedLogo")
            
            if enableLogging {
                LogManager.shared.info("🎨 App-Logo geändert: \(newValue)")
            }
        }
    }

    var currentLogoName: String {
        selectedLogo
    }

    // MARK: - API Konfiguration
    var serverURL: String {
        get { UserDefaults.standard.string(forKey: "serverURL") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "serverURL")
            
            if enableLogging && !newValue.isEmpty {
                LogManager.shared.info("🌐 Server-URL gesetzt: \(newValue)")
            }
        }
    }

    var token: String {
        get { UserDefaults.standard.string(forKey: "token") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "token")
            
            if enableLogging && !newValue.isEmpty {
                // Token maskieren für Sicherheit (nur ersten/last 4 Zeichen zeigen)
                let maskedToken = maskToken(newValue)
                LogManager.shared.info("🔑 Token gesetzt: \(maskedToken)")
            }
        }
    }
    
    private func maskToken(_ token: String) -> String {
        guard token.count > 8 else { return "••••" }
        let start = token.prefix(4)
        let end = token.suffix(4)
        return "\(start)••••\(end)"
    }

    var householdId: String {
        get { UserDefaults.standard.string(forKey: "householdId") ?? "Family" }
        set {
            UserDefaults.standard.set(newValue, forKey: "householdId")
            
            if enableLogging {
                LogManager.shared.info("🏠 Household ID gesetzt: \(newValue)")
            }
        }
    }

    var shoppingListId: String {
        get { UserDefaults.standard.string(forKey: "shoppingListId") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "shoppingListId")
            
            if enableLogging && !newValue.isEmpty {
                LogManager.shared.info("🛒 Shopping List ID gesetzt: \(newValue)")
            }
        }
    }

    var sendOptionalHeaders: Bool {
        get { UserDefaults.standard.bool(forKey: "sendOptionalHeaders") }
        set {
            UserDefaults.standard.set(newValue, forKey: "sendOptionalHeaders")
            
            if enableLogging {
                LogManager.shared.info("📋 Optionale Header: \(newValue ? "aktiviert" : "deaktiviert")")
            }
        }
    }

    var optionalHeaderKey1: String {
        get { UserDefaults.standard.string(forKey: "optionalHeaderKey1") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "optionalHeaderKey1")
            
            if enableLogging && !newValue.isEmpty {
                LogManager.shared.info("📋 Optionaler Header 1 Key: \(newValue)")
            }
        }
    }

    var optionalHeaderValue1: String {
        get { UserDefaults.standard.string(forKey: "optionalHeaderValue1") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "optionalHeaderValue1")
            
            if enableLogging && !newValue.isEmpty {
                LogManager.shared.info("📋 Optionaler Header 1 Value: \(newValue)")
            }
        }
    }

    var optionalHeaderKey2: String {
        get { UserDefaults.standard.string(forKey: "optionalHeaderKey2") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "optionalHeaderKey2")
            
            if enableLogging && !newValue.isEmpty {
                LogManager.shared.info("📋 Optionaler Header 2 Key: \(newValue)")
            }
        }
    }

    var optionalHeaderValue2: String {
        get { UserDefaults.standard.string(forKey: "optionalHeaderValue2") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "optionalHeaderValue2")
            
            if enableLogging && !newValue.isEmpty {
                LogManager.shared.info("📋 Optionaler Header 2 Value: \(newValue)")
            }
        }
    }

    var optionalHeaderKey3: String {
        get { UserDefaults.standard.string(forKey: "optionalHeaderKey3") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "optionalHeaderKey3")
            
            if enableLogging && !newValue.isEmpty {
                LogManager.shared.info("📋 Optionaler Header 3 Key: \(newValue)")
            }
        }
    }

    var optionalHeaderValue3: String {
        get { UserDefaults.standard.string(forKey: "optionalHeaderValue3") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "optionalHeaderValue3")
            
            if enableLogging && !newValue.isEmpty {
                LogManager.shared.info("📋 Optionaler Header 3 Value: \(newValue)")
            }
        }
    }

    var isConfigured: Bool {
        !serverURL.isEmpty && !token.isEmpty && !householdId.isEmpty && !shoppingListId.isEmpty
    }
    
    /// Gibt eine Zusammenfassung der Einstellungen (ohne sensible Daten)
    var settingsSummary: String {
        var summary = "=== App Settings Summary ===\n"
        summary += "Sprache: \(selectedLanguage)\n"
        summary += "API Version: \(apiVersion.rawValue)\n"
        summary += "Rezeptbilder: \(showRecipeImages ? "aktiviert" : "deaktiviert")\n"
        summary += "Logging: \(enableLogging ? "aktiviert" : "deaktiviert")\n"
        summary += "Server: \(serverURL.isEmpty ? "nicht gesetzt" : "gesetzt")\n"
        summary += "Token: \(token.isEmpty ? "nicht gesetzt" : "gesetzt")\n"
        summary += "Household: \(householdId)\n"
        summary += "Shopping List: \(shoppingListId.isEmpty ? "nicht gesetzt" : "gesetzt")\n"
        summary += "Optionale Header: \(sendOptionalHeaders ? "aktiviert" : "deaktiviert")\n"
        summary += "Logo: \(selectedLogo)\n"
        summary += "Eingeklappte Kategorien: \(collapsedShoppingCategories.count)\n"
        summary += "========================"
        return summary
    }

    // MARK: - API Service Konfiguration
    func configureAPIService() {
        var headers: [String: String] = [:]

        if sendOptionalHeaders {
            let rawHeaders = [
                optionalHeaderKey1: optionalHeaderValue1,
                optionalHeaderKey2: optionalHeaderValue2,
                optionalHeaderKey3: optionalHeaderValue3
            ]

            headers = Dictionary(uniqueKeysWithValues: rawHeaders.compactMap { key, value in
                let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return (!trimmedKey.isEmpty && !trimmedValue.isEmpty) ? (trimmedKey, trimmedValue) : nil
            })
            
            if enableLogging {
                LogManager.shared.info("📋 Konfigurierte optionale Header: \(headers.count)")
            }
        }

        if let url = URL(string: serverURL) {
            APIService.shared.configure(baseURL: url, token: token, optionalHeaders: headers)
            APIService.shared.setAPIVersion(apiVersion)
            
            if enableLogging {
                let maskedToken = maskToken(token)
                LogManager.shared.info("✅ API konfiguriert: \(url.absoluteString), Token: \(maskedToken), Version: \(apiVersion.rawValue)")
            }
        } else if enableLogging {
            LogManager.shared.warning("⚠️ Ungültige Server-URL: \(serverURL)")
        }
    }
    
    /// Setzt alle Einstellungen zurück
    func resetAllSettings() {
        if enableLogging {
            LogManager.shared.info("🔄 Alle Einstellungen werden zurückgesetzt")
        }
        
        // Zurücksetzen auf Standardwerte
        selectedLanguage = "de"
        apiVersion = .v2_8
        showRecipeImages = true
        enableLogging = true
        serverURL = ""
        token = ""
        householdId = "Family"
        shoppingListId = ""
        sendOptionalHeaders = false
        optionalHeaderKey1 = ""
        optionalHeaderValue1 = ""
        optionalHeaderKey2 = ""
        optionalHeaderValue2 = ""
        optionalHeaderKey3 = ""
        optionalHeaderValue3 = ""
        selectedLogo = "Classic"
        collapsedShoppingCategories = []
        
        if enableLogging {
            LogManager.shared.info("✅ Alle Einstellungen zurückgesetzt")
        }
    }
    
    /// Exportiert alle Einstellungen als Dictionary (ohne sensible Daten)
    func exportSettings() -> [String: Any] {
        return [
            "language": selectedLanguage,
            "apiVersion": apiVersion.rawValue,
            "showRecipeImages": showRecipeImages,
            "enableLogging": enableLogging,
            "serverURL": serverURL,
            "tokenSet": !token.isEmpty,
            "householdId": householdId,
            "shoppingListIdSet": !shoppingListId.isEmpty,
            "sendOptionalHeaders": sendOptionalHeaders,
            "optionalHeadersCount": [optionalHeaderKey1, optionalHeaderKey2, optionalHeaderKey3].filter { !$0.isEmpty }.count,
            "selectedLogo": selectedLogo,
            "collapsedCategoriesCount": collapsedShoppingCategories.count
        ]
    }
}

// MARK: - Helper Extension für UserDefaults
extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return bool(forKey: key)
    }
}
