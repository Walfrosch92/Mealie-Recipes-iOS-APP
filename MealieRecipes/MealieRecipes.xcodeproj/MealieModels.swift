import Foundation

// MARK: - API Model (direktes Mapping zur Mealie API)

/// Rohes Ingredient-Modell direkt von der Mealie API
/// ⚠️ Enthält alle möglichen Felder, auch wenn sie optional/null sind
struct MealieIngredientDTO: Codable, Identifiable {
    let id: UUID
    
    // Geparste Felder (können null sein!)
    let quantity: Double?
    let unit: String?
    let food: String?          // Hauptname der Zutat
    let note: String?          // 🔥 Oft vergessen!
    
    // Zusätzliche Felder
    let title: String?         // Alternative zu food in manchen Versionen
    let originalText: String?  // Fallback: ungeparster Text
    let display: String?       // Vorformatierter Display-String
    
    // Mealie-spezifische Felder
    let referenceId: String?
    let disableAmount: Bool?
    
    // Custom CodingKeys für snake_case → camelCase
    enum CodingKeys: String, CodingKey {
        case id
        case quantity
        case unit
        case food
        case note
        case title
        case originalText = "original_text"
        case display
        case referenceId = "reference_id"
        case disableAmount = "disable_amount"
    }
    
    // Custom Decoder für maximale Fehlertoleranz
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // ID: Generiere UUID falls fehlend
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        
        // Defensive Decoding mit Fallbacks
        quantity = try? container.decodeIfPresent(Double.self, forKey: .quantity)
        unit = Self.decodeNonEmptyString(from: container, forKey: .unit)
        food = Self.decodeNonEmptyString(from: container, forKey: .food)
        note = Self.decodeNonEmptyString(from: container, forKey: .note) // 🔥 Kritisch!
        title = Self.decodeNonEmptyString(from: container, forKey: .title)
        originalText = Self.decodeNonEmptyString(from: container, forKey: .originalText)
        display = Self.decodeNonEmptyString(from: container, forKey: .display)
        referenceId = Self.decodeNonEmptyString(from: container, forKey: .referenceId)
        disableAmount = try? container.decodeIfPresent(Bool.self, forKey: .disableAmount)
    }
    
    /// Hilfsfunktion: Decodiert String nur wenn nicht-leer
    private static func decodeNonEmptyString(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> String? {
        guard let string = try? container.decodeIfPresent(String.self, forKey: key),
              !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return string
    }
}

// MARK: - Domain Model (für UI optimiert)

/// UI-optimiertes Ingredient-Modell
/// ✅ Garantiert saubere, nicht-optionale Display-Werte
struct Ingredient: Identifiable, Hashable, Equatable {
    let id: UUID
    
    // Display-optimierte Properties
    let quantityText: String      // "2.5" oder ""
    let unit: String              // "kg" oder ""
    let name: String              // Nie leer!
    let note: String              // "" wenn keine Note
    let originalText: String      // Fallback für unparsed
    
    // Optionale Raw-Werte für Berechnungen
    let quantityValue: Double?
    
    // Mealie-Referenz
    let referenceId: String?
    let shouldDisplayAmount: Bool
    
    /// Vollständiger Display-String für die UI
    var displayText: String {
        var parts: [String] = []
        
        if shouldDisplayAmount {
            if !quantityText.isEmpty {
                parts.append(quantityText)
            }
            
            if !unit.isEmpty {
                parts.append(unit)
            }
        }
        
        parts.append(name)
        
        if !note.isEmpty {
            parts.append("(\(note))")
        }
        
        return parts.joined(separator: " ")
    }
    
    /// Kompakter Display für Listen
    var compactDisplayText: String {
        if !originalText.isEmpty {
            return originalText
        }
        return displayText
    }
    
    /// Hat diese Zutat eine Notiz?
    var hasNote: Bool {
        !note.isEmpty
    }
    
    // MARK: - Mapping von API zu Domain
    
    /// Konvertiert API DTO zu UI-freundlichem Model
    static func from(dto: MealieIngredientDTO) -> Ingredient {
        // Name-Fallback-Strategie
        let name = dto.food
            ?? dto.title
            ?? dto.originalText
            ?? "Unbekannte Zutat"
        
        // Quantity formatieren
        let quantityText: String
        if let qty = dto.quantity {
            // Entferne .0 bei ganzen Zahlen
            if qty.truncatingRemainder(dividingBy: 1) == 0 {
                quantityText = String(Int(qty))
            } else {
                quantityText = String(format: "%.1f", qty)
            }
        } else {
            quantityText = ""
        }
        
        return Ingredient(
            id: dto.id,
            quantityText: quantityText,
            unit: dto.unit ?? "",
            name: name,
            note: dto.note ?? "", // 🔥 Wichtig: Nie nil in UI!
            originalText: dto.originalText ?? "",
            quantityValue: dto.quantity,
            referenceId: dto.referenceId,
            shouldDisplayAmount: !(dto.disableAmount ?? false)
        )
    }
}

// MARK: - Recipe Model mit Ingredients

struct MealieRecipeDTO: Codable {
    let id: String
    let name: String
    let description: String?
    
    // 🔥 Ingredients können als Array fehlen oder leer sein
    let recipeIngredient: [MealieIngredientDTO]?
    
    // Alternative Namen in verschiedenen API-Versionen
    let ingredients: [MealieIngredientDTO]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case recipeIngredient = "recipe_ingredient"
        case ingredients
    }
    
    /// Gibt die Ingredients zurück, egal aus welchem Feld
    var allIngredients: [MealieIngredientDTO] {
        recipeIngredient ?? ingredients ?? []
    }
}

struct Recipe: Identifiable {
    let id: String
    let name: String
    let description: String
    let ingredients: [Ingredient]
    
    static func from(dto: MealieRecipeDTO) -> Recipe {
        Recipe(
            id: dto.id,
            name: dto.name,
            description: dto.description ?? "",
            // Map alle DTOs zu Domain-Models
            ingredients: dto.allIngredients.map { Ingredient.from(dto: $0) }
        )
    }
}

// MARK: - Array Extensions für sicheres Mapping

extension Array where Element == MealieIngredientDTO {
    /// Mappt DTOs zu Ingredients, filtert NICHT aus
    /// ✅ Jede Zutat wird angezeigt, auch wenn Daten fehlen
    func toIngredients() -> [Ingredient] {
        self.map { Ingredient.from(dto: $0) }
    }
    
    /// Debug: Zeigt welche Ingredients keine Notes haben
    func logMissingNotes() {
        let withoutNotes = self.filter { $0.note == nil || $0.note?.isEmpty == true }
        if !withoutNotes.isEmpty {
            print("⚠️ \(withoutNotes.count) Ingredients ohne Notes:")
            withoutNotes.forEach { ingredient in
                print("   - \(ingredient.food ?? ingredient.title ?? "unnamed")")
            }
        }
    }
}
