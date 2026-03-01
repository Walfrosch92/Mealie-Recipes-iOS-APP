//
//  IngredientLocalization.swift
//  MealieRecipes
//
//  Localization keys for ingredient editing
//

import Foundation

extension String {
    var localizedIngredient: String {
        let translations: [String: String] = [
            "quantity": NSLocalizedString("quantity", value: "Menge", comment: ""),
            "unit": NSLocalizedString("unit", value: "Einheit", comment: ""),
            "ingredient": NSLocalizedString("ingredient", value: "Zutat", comment: ""),
            "parsed": NSLocalizedString("parsed", value: "Strukturiert", comment: ""),
            "mixed": NSLocalizedString("mixed", value: "Gemischt", comment: "")
        ]
        
        return translations[self] ?? NSLocalizedString(self, comment: "")
    }
}
