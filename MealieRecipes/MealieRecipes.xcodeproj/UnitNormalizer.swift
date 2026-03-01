//
//  UnitNormalizer.swift
//  MealieRecipes
//
//  Normalisiert Einheiten-Strings für Mealie API Kompatibilität
//

import Foundation

struct UnitNormalizer {
    
    /// Normalisiert eine Einheit zu einem Mealie-kompatiblen Format
    /// - Parameter unit: Die eingegebene Einheit (z.B. "Gramm", "gramm", "GRAMM")
    /// - Returns: Normalisierte Einheit (z.B. "g") oder Original wenn nicht gefunden
    static func normalize(_ unit: String?) -> String? {
        guard let unit = unit?.trimmingCharacters(in: .whitespacesAndNewlines),
              !unit.isEmpty else {
            return nil
        }
        
        let lowercased = unit.lowercased()
        
        // Prüfe ob bereits normalisiert (kurze Abkürzung)
        if unit.count <= 3 && !needsNormalization(lowercased) {
            return unit
        }
        
        // Normalisierungs-Map
        return unitMapping[lowercased] ?? unit
    }
    
    /// Prüft ob eine Einheit normalisiert werden muss
    private static func needsNormalization(_ unit: String) -> Bool {
        return unitMapping.keys.contains(unit)
    }
    
    /// Mapping von verschiedenen Schreibweisen zu Standard-Einheiten
    private static let unitMapping: [String: String] = [
        // Gewicht
        "gramm": "g",
        "gram": "g",
        "grams": "g",
        "gr": "g",
        "kilogramm": "kg",
        "kilogram": "kg",
        "kilo": "kg",
        "milligramm": "mg",
        "milligram": "mg",
        
        // Volumen
        "milliliter": "ml",
        "millilitre": "ml",
        "liter": "l",
        "litre": "l",
        "deziliter": "dl",
        "deciliter": "dl",
        "centiliter": "cl",
        
        // Löffel
        "esslöffel": "EL",
        "essloffel": "EL",
        "tablespoon": "EL",
        "tablespoons": "EL",
        "tbsp": "EL",
        "tbs": "EL",
        "teelöffel": "TL",
        "teeloffel": "TL",
        "teaspoon": "TL",
        "teaspoons": "TL",
        "tsp": "TL",
        
        // Tassen
        "tasse": "Tasse",
        "tassen": "Tasse",
        "cup": "cup",
        "cups": "cup",
        
        // Stück/Anzahl
        "stück": "Stück",
        "stuck": "Stück",
        "stk": "Stück",
        "piece": "pcs",
        "pieces": "pcs",
        "stck": "Stück",
        
        // Packung/Beutel
        "packung": "Pkt",
        "pkg": "Pkt",
        "package": "Pkt",
        "beutel": "Beutel",
        "bag": "Beutel",
        
        // Spezielle
        "prise": "Prise",
        "pinch": "Prise",
        "spritzer": "Spritzer",
        "dash": "Spritzer",
        "schuss": "Schuss",
        "splash": "Schuss",
        
        // Dosen/Gläser
        "dose": "Dose",
        "dosen": "Dose",
        "can": "Dose",
        "cans": "Dose",
        "glas": "Glas",
        "gläser": "Glas",
        "glaser": "Glas",
        "jar": "Glas",
        "jars": "Glas",
        
        // Bund/Zweig
        "bund": "Bund",
        "bunch": "Bund",
        "zweig": "Zweig",
        "zweige": "Zweig",
        "sprig": "Zweig",
        "sprigs": "Zweig",
        
        // Scheiben/Slices
        "scheibe": "Scheibe",
        "scheiben": "Scheibe",
        "slice": "Scheibe",
        "slices": "Scheibe",
        
        // Blätter
        "blatt": "Blatt",
        "blätter": "Blatt",
        "blatter": "Blatt",
        "leaf": "Blatt",
        "leaves": "Blatt",
        
        // Zehe (Knoblauch)
        "zehe": "Zehe",
        "zehen": "Zehe",
        "clove": "Zehe",
        "cloves": "Zehe"
    ]
    
    /// Gibt eine Liste unterstützter Einheiten zurück (für Autocomplete)
    static var supportedUnits: [String] {
        return Array(Set(unitMapping.values)).sorted()
    }
    
    /// Gibt Vorschläge für eine Einheit basierend auf Eingabe
    static func suggestions(for input: String) -> [String] {
        guard !input.isEmpty else { return [] }
        
        let lowercased = input.lowercased()
        
        // Exakte Matches
        let exactMatches = unitMapping.filter { key, _ in
            key.hasPrefix(lowercased)
        }.values
        
        // Partielle Matches
        let partialMatches = unitMapping.filter { key, _ in
            key.contains(lowercased) && !key.hasPrefix(lowercased)
        }.values
        
        return Array(Set(exactMatches + partialMatches))
            .sorted()
            .prefix(8)
            .map { $0 }
    }
}

// MARK: - Extension für Recipe Payload

extension RecipeUpdatePayload.Ingredient {
    /// Erstellt ein Ingredient mit normalisierten Einheiten
    init(normalizing ingredient: Ingredient) {
        self.init(
            referenceId: UUID().uuidString,
            note: ingredient.note,
            quantity: ingredient.quantity,
            unit: UnitNormalizer.normalize(ingredient.unit),
            food: ingredient.food
        )
    }
}
