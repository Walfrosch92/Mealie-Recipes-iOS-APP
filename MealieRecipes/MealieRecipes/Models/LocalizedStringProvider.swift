//
//  LocalizedStringProvider.swift
//  MealieRecipes
//
//  Created by Michael Haiszan on 02.05.25.
//

import Foundation

class LocalizedStringProvider {
    /// Optional: Temporäre Sprache für Vorschau (z. B. in SetupView)
    static var overrideLanguage: String?

    /// Gibt den lokalisierten String für den gegebenen Schlüssel zurück
    static func localized(_ key: String) -> String {
        let language = overrideLanguage ?? AppSettings.shared.selectedLanguage

        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }

        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}
