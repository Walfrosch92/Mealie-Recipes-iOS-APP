//
//  RecipeDetail.swift
//  MealieRecipes
//
//  Unterstützt Mealie v2.8 (ingredientStrings) und v3.x (recipeIngredient)
//

import Foundation

// MARK: - Basis-Typen (nur einmal im Projekt definieren!)
struct RecipeTag: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let slug: String?
}

struct Category: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let slug: String?
}

// UI-/App-interne Zutat (vereinheitlicht)
struct Ingredient: Identifiable, Codable, Equatable {
    let id: UUID = UUID()
    var food: String?           // 🍎 Name der Zutat (z.B. "Mehl", "Eier (Größe M)")
    var note: String?           // 📝 Zusätzliche Notiz (z.B. "für die Creme", "Bio")
    var quantity: Double?       // 🔢 Menge (z.B. 2.5)
    var unit: String?           // 📏 Einheit (z.B. "kg", "Stück")
    var isCompleted: Bool = false
    
    // ✅ NEU: Gecachte IDs (werden beim Laden von der API oder beim Speichern gesetzt)
    var foodID: String?         // 🆔 UUID des Foods (aus Mealie-DB)
    var unitID: String?         // 🆔 UUID der Unit (aus Mealie-DB)
    var referenceId: String?    // 🆔 Mealie referenceId (muss bei PATCH erhalten bleiben!)

    enum CodingKeys: String, CodingKey { 
        case food, note, quantity, unit, foodID, unitID, referenceId
    }
    
    /// Gibt es eine zusätzliche Notiz/Anmerkung?
    var hasNote: Bool {
        guard let n = note else { return false }
        return !n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Der Haupt-Zutatname (für die Anzeige)
    var displayName: String {
        food ?? note ?? "Zutat"
    }
}

// UI-/App-interne Anweisung (vereinheitlicht)
struct Instruction: Identifiable, Codable, Equatable {
    let id: UUID = UUID()
    var text: String

    enum CodingKeys: String, CodingKey { case text }
}

struct TextItem: Codable { var text: String }

struct RecipeSettings: Codable {
    var showAssets: Bool
    var `public`: Bool
    var showNutrition: Bool
    var landscapeView: Bool
    var disableAmount: Bool
    var disableComments: Bool
    var locked: Bool
}

// MARK: - RecipeDetail (vereinheitlicht)
struct RecipeDetail: Identifiable, Codable {
    // Kern
    let id: String
    var name: String
    var slug: String
    var description: String?
    var image: String?

    // Vereinheitlichte Collections für die App
    var ingredients: [Ingredient] = []
    var instructions: [Instruction] = []
    var tags: [RecipeTag] = []
    var recipeCategory: [Category] = []

    // Zeiten / Servings
    var prepTime: Int?
    var cookTime: Int?
    var totalTime: Int?
    var recipeServings: Double?
    var rating: Double?

    // Sonstiges (falls benötigt)
    var settings: RecipeSettings = .init(
        showAssets: true,
        public: false,
        showNutrition: false,
        landscapeView: false,
        disableAmount: true,
        disableComments: false,
        locked: false
    )
    var comments: [TextItem] = []
    var notes: [TextItem] = []
    var tools: [TextItem] = []
    var recipeYieldQuantity: Int = 0
    var dateUpdated: Date?
    var dateAdded: Date?
    var createdAt: Date?
    var updatedAt: Date?

    // MARK: - Coding Keys für API
    enum CodingKeys: String, CodingKey {
        case id, name, description, image, slug
        case tags, recipeCategory
        case prepTime, performTime, totalTime, recipeServings, rating  // ✅ performTime statt cookTime

        // Zutaten (alt & neu)
        case ingredientStrings                 // v2.8
        case recipeIngredient                  // v3.x

        // Anleitungen
        case recipeInstructions
        
        // Datums-Felder (verschiedene API-Versionen)
        case dateUpdated, dateAdded
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: Rohstrukturen (nur für Decoding)

    /// Tolerantes Decoding für v3: unit/food können String **oder** Objekt sein; quantity kann Double/Int/String sein.
    struct ParsedIngredientRaw: Decodable {
        let note: String?
        let quantity: Double?
        let unit: String?
        let food: String?
        let display: String?
        let referenceId: String?
        let unitID: String?   // ✅ NEU: ID der Unit (wenn vom Server als Objekt)
        let foodID: String?   // ✅ NEU: ID des Foods (wenn vom Server als Objekt)

        enum CodingKeys: String, CodingKey { case note, quantity, unit, food, display, referenceId }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)

            // note
            note = try c.decodeIfPresent(String.self, forKey: .note)

            // quantity (Double/Int/String tolerant)
            if let d = try? c.decodeIfPresent(Double.self, forKey: .quantity) {
                quantity = d
            } else if let i = try? c.decodeIfPresent(Int.self, forKey: .quantity) {
                quantity = Double(i)
            } else if let s = try? c.decodeIfPresent(String.self, forKey: .quantity) {
                quantity = Double(s.replacingOccurrences(of: ",", with: ".")) ?? nil
            } else {
                quantity = nil
            }

            // unit (String ODER Objekt -> name/display/label/abbreviation/slug/id)
            let unitResult = Self.decodeStringOrObjectWithID(from: c, key: .unit)
            unit = unitResult.name
            unitID = unitResult.id

            // food (String ODER Objekt -> name/display/label/slug/id)
            let foodResult = Self.decodeStringOrObjectWithID(from: c, key: .food)
            food = foodResult.name
            foodID = foodResult.id

            // display (String, wenn vorhanden – enthält oft bereits eine schöne Darstellung)
            display = try c.decodeIfPresent(String.self, forKey: .display)

            referenceId = try c.decodeIfPresent(String.self, forKey: .referenceId)
        }

        private static func decodeStringOrObject(from c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> String? {
            return decodeStringOrObjectWithID(from: c, key: key).name
        }
        
        private static func decodeStringOrObjectWithID(from c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> (name: String?, id: String?) {
            // Versuche als String
            if let s = try? c.decodeIfPresent(String.self, forKey: key) {
                return (name: s.nilIfEmpty(), id: nil)
            }
            
            // Versuche als Objekt (Dictionary)
            if let dict = try? c.decodeIfPresent([String: AnyCodable].self, forKey: key) {
                // Extrahiere Name und ID aus dem Dictionary
                let name = ["name", "display", "label", "abbreviation", "slug"].compactMap { dictKey -> String? in
                    if let value = dict[dictKey] {
                        if let stringValue = value.value as? String {
                            return stringValue
                        }
                    }
                    return nil
                }.first
                
                // Extrahiere ID
                let id = dict["id"]?.value as? String
                
                // Wenn weder Name noch ID gefunden wurde, versuche "id" als Name
                if name == nil, let idAsName = id {
                    return (name: idAsName, id: id)
                }
                
                return (name: name, id: id)
            }
            
            return (name: nil, id: nil)
        }
    }
    
    // Helper für Any-Codable
    struct AnyCodable: Codable {
        let value: Any
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                value = string
            } else if let int = try? container.decode(Int.self) {
                value = int
            } else if let double = try? container.decode(Double.self) {
                value = double
            } else if let bool = try? container.decode(Bool.self) {
                value = bool
            } else {
                value = ""
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            if let string = value as? String {
                try container.encode(string)
            } else if let int = value as? Int {
                try container.encode(int)
            } else if let double = value as? Double {
                try container.encode(double)
            } else if let bool = value as? Bool {
                try container.encode(bool)
            }
        }
    }

    // recipeInstructions können als Objekte oder Strings kommen
    struct ParsedInstructionRaw: Codable {
        let id: String?
        let text: String?
        let title: String?
        let summary: String?
    }

    // MARK: - Custom Encoder (für Cache)
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)

        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(slug, forKey: .slug)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(image, forKey: .image)

        if !tags.isEmpty { try c.encode(tags, forKey: .tags) }
        if !recipeCategory.isEmpty { try c.encode(recipeCategory, forKey: .recipeCategory) }

        try c.encodeIfPresent(prepTime, forKey: .prepTime)
        try c.encodeIfPresent(cookTime, forKey: .performTime)  // ✅ Als performTime senden
        try c.encodeIfPresent(totalTime, forKey: .totalTime)
        try c.encodeIfPresent(recipeServings, forKey: .recipeServings)
        try c.encodeIfPresent(rating, forKey: .rating)

        // Zutaten: wenn strukturierte Werte vorhanden → recipeIngredient, sonst ingredientStrings
        let hasStructured = ingredients.contains { $0.quantity != nil || ($0.unit?.isEmpty == false) }
        if hasStructured {
            struct EncIngr: Codable {
                let note: String?
                let quantity: Double?
                let unit: String?
                let food: String?
                let referenceId: String?
                let unitID: String?   // ✅ NEU: Cache die ID
                let foodID: String?   // ✅ NEU: Cache die ID
                
                enum CodingKeys: String, CodingKey {
                    case note, quantity, unit, food, referenceId, unitID, foodID
                }
            }
            let enc = ingredients.map {
                EncIngr(
                    note: $0.note,
                    quantity: $0.quantity,
                    unit: $0.unit,
                    food: $0.food,
                    referenceId: nil,
                    unitID: $0.unitID,  // ✅ Speichere gecachte ID
                    foodID: $0.foodID   // ✅ Speichere gecachte ID
                )
            }
            try c.encode(enc, forKey: .recipeIngredient)
        } else {
            let strings = ingredients
                .compactMap { $0.food?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !strings.isEmpty {
                try c.encode(strings, forKey: .ingredientStrings)
            }
        }

        // Anweisungen als v3-Objekte mit text-Feld serialisieren
        struct EncStep: Codable { let text: String }
        let steps = instructions.map { EncStep(text: $0.text) }
        if !steps.isEmpty {
            try c.encode(steps, forKey: .recipeInstructions)
        }
    }

    // MARK: - Custom Decoder (vereinheitlicht Zutaten & Anweisungen)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        slug = try c.decode(String.self, forKey: .slug)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        image = try c.decodeIfPresent(String.self, forKey: .image)

        tags = try c.decodeIfPresent([RecipeTag].self, forKey: .tags) ?? []
        recipeCategory = try c.decodeIfPresent([Category].self, forKey: .recipeCategory) ?? []

        prepTime = RecipeDetail.decodeIntOrString(container: c, key: .prepTime)
        cookTime = RecipeDetail.decodeIntOrString(container: c, key: .performTime)  // ✅ performTime vom Server
        totalTime = RecipeDetail.decodeIntOrString(container: c, key: .totalTime)
        
        #if DEBUG
        // Debug: Zeige rohe API-Werte an
        if let prepRaw = try? c.decodeIfPresent(String.self, forKey: .prepTime) {
            print("🕒 PrepTime (raw from API): '\(prepRaw)'")
        } else if let prepInt = try? c.decodeIfPresent(Int.self, forKey: .prepTime) {
            print("🕒 PrepTime (raw from API): \(prepInt)")
        }
        
        if let totalRaw = try? c.decodeIfPresent(String.self, forKey: .totalTime) {
            print("🕒 TotalTime (raw from API): '\(totalRaw)'")
        } else if let totalInt = try? c.decodeIfPresent(Int.self, forKey: .totalTime) {
            print("🕒 TotalTime (raw from API): \(totalInt)")
        }
        
        // Debug: Zeige geparste Werte an
        if let prep = prepTime {
            print("🕒 PrepTime (parsed): \(prep) minutes")
        }
        if let total = totalTime {
            print("🕒 TotalTime (parsed): \(total) minutes")
        }
        #endif
        
        recipeServings = RecipeDetail.decodeServings(container: c)
        rating = try c.decodeIfPresent(Double.self, forKey: .rating)
        
        // Datums-Felder dekodieren (verschiedene Formate unterstützen)
        let dateDecoder = RecipeDetail.createDateDecoder()
        dateUpdated = try? c.decodeIfPresent(Date.self, forKey: .dateUpdated)
            ?? dateDecoder.decodeIfPresent(c, key: .dateUpdated)
        dateAdded = try? c.decodeIfPresent(Date.self, forKey: .dateAdded)
            ?? dateDecoder.decodeIfPresent(c, key: .dateAdded)
        createdAt = try? c.decodeIfPresent(Date.self, forKey: .createdAt)
            ?? dateDecoder.decodeIfPresent(c, key: .createdAt)
        updatedAt = try? c.decodeIfPresent(Date.self, forKey: .updatedAt)
            ?? dateDecoder.decodeIfPresent(c, key: .updatedAt)
        
        #if DEBUG
        if let createdDate = createdAt {
            print("✅ Rezept '\(name)' hat createdAt: \(createdDate)")
        } else if let addedDate = dateAdded {
            print("⚠️ Rezept '\(name)' hat kein createdAt, aber dateAdded: \(addedDate)")
        } else if let updatedDate = dateUpdated {
            print("⚠️ Rezept '\(name)' hat nur dateUpdated: \(updatedDate)")
        } else {
            print("❌ Rezept '\(name)' hat keine Datums-Felder (createdAt, dateAdded, dateUpdated)!")
        }
        #endif

        // Zutaten: v3.x (recipeIngredient) bevorzugen, sonst v2.8 (ingredientStrings)
        if let parsed = try c.decodeIfPresent([ParsedIngredientRaw].self, forKey: .recipeIngredient),
           !parsed.isEmpty {
            self.ingredients = parsed.map { raw in
                // 🔥 WICHTIG: note und food sind unterschiedliche Felder!
                // - note: Zusätzliche Anmerkung (z.B. "für die Creme", "Bio")
                // - food: Haupt-Zutat (z.B. "Mehl", "Pfeffer", "Eier (Größe M)")
                
                // Prüfe, ob die Daten bereits strukturiert sind
                let hasStructuredData = (raw.quantity != nil && raw.quantity! > 0) || 
                                       (raw.unit != nil && !raw.unit!.isEmpty)
                
                if hasStructuredData {
                    // Daten sind bereits strukturiert → direkt verwenden
                    let foodName = raw.food?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let noteName = raw.note?.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    #if DEBUG
                    print("🔍 Strukturierte Zutat geladen:")
                    print("   Food: \(foodName ?? "nil") (ID: \(raw.foodID ?? "nil"))")
                    print("   Note: \(noteName ?? "nil")")
                    print("   Quantity: \(raw.quantity?.description ?? "nil")")
                    print("   Unit: \(raw.unit ?? "nil") (ID: \(raw.unitID ?? "nil"))")
                    #endif
                    
                    return Ingredient(
                        food: foodName,
                        note: noteName,
                        quantity: raw.quantity,
                        unit: raw.unit,
                        isCompleted: false,
                        foodID: raw.foodID,     // ✅ Cache die ID
                        unitID: raw.unitID,     // ✅ Cache die ID
                        referenceId: raw.referenceId  // ✅ KRITISCH: referenceId erhalten!
                    )
                } else {
                    // Daten sind nur als Text vorhanden → parsen
                    let fullText = [
                        raw.display?.trimmingCharacters(in: .whitespacesAndNewlines),
                        raw.food?.trimmingCharacters(in: .whitespacesAndNewlines),
                        raw.note?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ].compactMap { $0 }.first(where: { !$0.isEmpty }) ?? "Zutat"
                    
                    // Verwende den QuantityParser zum Parsen
                    let parsed = QuantityParser.parse(from: fullText)
                    
                    #if DEBUG
                    print("📝 Auto-Parsing unstrukturierter Zutat:")
                    print("  Input: '\(fullText)'")
                    print("  → Quantity: \(parsed.qty?.description ?? "nil")")
                    print("  → Unit: \(parsed.unit ?? "nil")")
                    print("  → Name: '\(parsed.cleaned)'")
                    #endif
                    
                    return Ingredient(
                        food: parsed.cleaned.isEmpty ? fullText : parsed.cleaned,
                        note: nil,
                        quantity: parsed.qty,
                        unit: parsed.unit,
                        isCompleted: false,
                        foodID: raw.foodID,     // ✅ Cache die ID (falls vorhanden)
                        unitID: raw.unitID,     // ✅ Cache die ID (falls vorhanden)
                        referenceId: raw.referenceId  // ✅ KRITISCH: referenceId erhalten!
                    )
                }
            }
        } else if let legacy = try c.decodeIfPresent([String].self, forKey: .ingredientStrings) {
            self.ingredients = legacy.map { Ingredient(food: $0, note: nil, quantity: nil, unit: nil, isCompleted: false, foodID: nil, unitID: nil) }
        } else {
            self.ingredients = []
        }

        // Anweisungen: aus recipeInstructions (Objekte oder Strings)
        if let steps = try c.decodeIfPresent([ParsedInstructionRaw].self, forKey: .recipeInstructions) {
            self.instructions = steps.compactMap { raw in
                guard let txt = raw.text?.trimmingCharacters(in: .whitespacesAndNewlines), !txt.isEmpty else { return nil }
                return Instruction(text: txt)
            }
        } else if let stepsAsStrings = try? c.decode([String].self, forKey: .recipeInstructions) {
            self.instructions = stepsAsStrings.map { Instruction(text: $0) }
        } else {
            self.instructions = []
        }
    }

    // MARK: - Hilfen (Parsing)
    static func decodeIntOrString(container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int? {
        // Versuche direkt als Int zu dekodieren
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) { 
            return intValue 
        }
        
        // Versuche als String zu dekodieren
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
            // 1. Prüfe auf ISO 8601 Duration Format (z.B. "PT1H45M", "PT105M", "PT1H")
            if let minutes = Self.parseISO8601Duration(from: stringValue) {
                return minutes
            }
            
            // 2. Prüfe auf menschenlesbares Format (z.B. "1 Stunde 45 Minuten", "2h 30m", "90 min")
            if let minutes = Self.parseHumanReadableTime(from: stringValue) {
                return minutes
            }
            
            // 3. Fallback: Extrahiere erste Zahl
            return Self.extractFirstNumber(from: stringValue)
        }
        
        return nil
    }
    
    /// Parst ISO 8601 Duration Strings (z.B. "PT1H45M" → 105 Minuten)
    private static func parseISO8601Duration(from string: String) -> Int? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // ISO 8601 Duration Format: PT[n]H[n]M[n]S
        // Beispiele: "PT1H45M", "PT105M", "PT1H30M15S", "PT2H"
        guard trimmed.hasPrefix("PT") || trimmed.hasPrefix("P") else { 
            return nil 
        }
        
        var totalMinutes = 0
        var workingString = trimmed
        
        // Entferne "PT" oder "P" Prefix
        if workingString.hasPrefix("PT") {
            workingString = String(workingString.dropFirst(2))
        } else if workingString.hasPrefix("P") {
            workingString = String(workingString.dropFirst(1))
        }
        
        // Parse Stunden (z.B. "1H")
        if let hourRange = workingString.range(of: #"(\d+)H"#, options: .regularExpression) {
            let hourString = workingString[hourRange].dropLast() // Entferne "H"
            if let hours = Int(hourString) {
                totalMinutes += hours * 60
            }
        }
        
        // Parse Minuten (z.B. "45M")
        if let minuteRange = workingString.range(of: #"(\d+)M"#, options: .regularExpression) {
            let minuteString = workingString[minuteRange].dropLast() // Entferne "M"
            if let minutes = Int(minuteString) {
                totalMinutes += minutes
            }
        }
        
        // Parse Sekunden (z.B. "30S") - konvertiere zu Minuten (gerundet)
        if let secondRange = workingString.range(of: #"(\d+)S"#, options: .regularExpression) {
            let secondString = workingString[secondRange].dropLast() // Entferne "S"
            if let seconds = Int(secondString) {
                totalMinutes += (seconds + 30) / 60 // Runde auf nächste Minute
            }
        }
        
        return totalMinutes > 0 ? totalMinutes : nil
    }
    
    /// Parst menschenlesbare Zeitformate (z.B. "1 Stunde 45 Minuten", "2h 30m", "90 min")
    private static func parseHumanReadableTime(from string: String) -> Int? {
        let lowercased = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var totalMinutes = 0
        var foundHours = false
        var foundMinutes = false
        
        #if DEBUG
        print("🕒 Parsing time string: '\(string)'")
        #endif
        
        // Deutsch & Englisch: Stunden
        let hourPatterns = [
            #"(\d+)\s*(?:stunde|stunden|std\.?|hour|hours|hr|hrs\.?)\b"#
        ]
        
        for pattern in hourPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: lowercased, range: NSRange(location: 0, length: lowercased.utf16.count))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: lowercased) {
                        if let hours = Int(lowercased[range]) {
                            totalMinutes += hours * 60
                            foundHours = true
                            #if DEBUG
                            print("  → Found hours: \(hours) → \(hours * 60) minutes")
                            #endif
                        }
                    }
                }
            }
        }
        
        // Deutsch & Englisch: Minuten
        let minutePatterns = [
            #"(\d+)\s*(?:minute|minuten|min\.?|m)\b"#
        ]
        
        for pattern in minutePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: lowercased, range: NSRange(location: 0, length: lowercased.utf16.count))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: lowercased) {
                        if let minutes = Int(lowercased[range]) {
                            totalMinutes += minutes
                            foundMinutes = true
                            #if DEBUG
                            print("  → Found minutes: \(minutes)")
                            #endif
                        }
                    }
                }
            }
        }
        
        // Wenn keine Einheit gefunden wurde, aber es gibt eine Zahl mit "h" oder "m" am Ende
        if !foundHours && !foundMinutes {
            // Versuche "2h", "30m" Format
            if let regex = try? NSRegularExpression(pattern: #"(\d+)h\b"#, options: .caseInsensitive),
               let match = regex.firstMatch(in: lowercased, range: NSRange(location: 0, length: lowercased.utf16.count)),
               let range = Range(match.range(at: 1), in: lowercased) {
                if let hours = Int(lowercased[range]) {
                    totalMinutes += hours * 60
                    foundHours = true
                }
            }
            
            if let regex = try? NSRegularExpression(pattern: #"(\d+)m\b"#, options: .caseInsensitive),
               let match = regex.firstMatch(in: lowercased, range: NSRange(location: 0, length: lowercased.utf16.count)),
               let range = Range(match.range(at: 1), in: lowercased) {
                if let minutes = Int(lowercased[range]) {
                    totalMinutes += minutes
                    foundMinutes = true
                }
            }
        }
        
        #if DEBUG
        if totalMinutes > 0 {
            print("  → Total: \(totalMinutes) minutes")
        }
        #endif
        
        return totalMinutes > 0 ? totalMinutes : nil
    }

    static func decodeServings(container: KeyedDecodingContainer<CodingKeys>) -> Double? {
        if let val = try? container.decodeIfPresent(Double.self, forKey: .recipeServings) { return val > 0 ? val : nil }
        if let stringVal = try? container.decodeIfPresent(String.self, forKey: .recipeServings),
           let number = Self.extractFirstNumber(from: stringVal) {
            return Double(number)
        }
        return nil
    }
    
    // MARK: - Date Decoder Helper
    private static func createDateDecoder() -> FlexibleDateDecoder {
        return FlexibleDateDecoder()
    }
    
    struct FlexibleDateDecoder {
        func decodeIfPresent(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Date? {
            // Versuche verschiedene ISO8601-Formate
            if let dateString = try? container.decodeIfPresent(String.self, forKey: key) {
                let formatters: [Any] = [
                    ISO8601DateFormatter(),
                    {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        return formatter
                    }(),
                    {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
                        formatter.timeZone = TimeZone(secondsFromGMT: 0)
                        return formatter
                    }(),
                    {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                        formatter.timeZone = TimeZone(secondsFromGMT: 0)
                        return formatter
                    }(),
                    {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                        formatter.timeZone = TimeZone(secondsFromGMT: 0)
                        return formatter
                    }(),
                    {
                        // Einfaches Datum ohne Zeit (z.B. "2025-12-07")
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        formatter.timeZone = TimeZone(secondsFromGMT: 0)
                        return formatter
                    }()
                ]
                
                for formatter in formatters {
                    if let formatter = formatter as? ISO8601DateFormatter,
                       let date = formatter.date(from: dateString) {
                        return date
                    } else if let formatter = formatter as? DateFormatter,
                              let date = formatter.date(from: dateString) {
                        return date
                    }
                }
            }
            return nil
        }
    }

    private static func extractFirstNumber(from string: String) -> Int? {
        let pattern = #"(\d+([.,]\d+)?)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: string, range: NSRange(location: 0, length: string.utf16.count)),
           let range = Range(match.range(at: 1), in: string) {
            let value = string[range].replacingOccurrences(of: ",", with: ".")
            return Int(Double(value) ?? 0)
        }
        return nil
    }
}

// MARK: - Komfortfunktionen für Zutaten-Matching + Anzeige
extension RecipeDetail {
    func hasAllMatchingIngredients(_ inputNames: [String]) -> Bool {
        let lowercasedInput = inputNames.map { $0.lowercased() }
        return lowercasedInput.allSatisfy { input in
            ingredients.contains { $0.note?.lowercased().contains(input) == true }
        }
    }

    func matchingIngredientCount(haveIngredients: [String]) -> Int {
        let lowercasedInput = haveIngredients.map { $0.lowercased() }
        return ingredients.filter { ing in
            lowercasedInput.contains { ing.note?.lowercased().contains($0) == true }
        }.count
    }

    func matchingIngredientPercentage(haveIngredients: [String]) -> Double {
        let total = max(1, ingredients.count)
        let count = matchingIngredientCount(haveIngredients: haveIngredients)
        return Double(count) / Double(total) * 100.0
    }

    /// Für eine einfache Anzeige in der UI (Liste von Strings)
    func displayIngredients() -> [String] {
        ingredients.map { ing in
            let qty = ing.quantity.map { Self.trimZeros($0) } ?? ""
            let unit = ing.unit ?? ""
            let name = (ing.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = [qty, unit, name].filter { !$0.isEmpty }
            let line = parts.joined(separator: " ")
            return line.isEmpty ? "Zutat" : line
        }
    }

    private static func trimZeros(_ value: Double) -> String {
        String(format: "%g", value)
    }
}

// MARK: - kleine String-Hilfe
private extension String {
    func nilIfEmpty() -> String? { isEmpty ? nil : self }
}

// MARK: - QuantityParser (integriert)
struct QuantityParser {
    
    struct ParseResult {
        let qty: Double?
        let unit: String?
        let cleaned: String
    }
    
    /// Parst einen Zutaten-String und extrahiert Menge, Einheit und Name
    static func parse(from text: String) -> ParseResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Versuch 1: Dezimalzahl mit Einheit
        // Muster: "2.5 kg Mehl" oder "2 EL Öl"
        let decimalPattern = #"^(\d+(?:[.,]\d+)?)\s*([a-zA-ZäöüßÄÖÜ]+)?\s+(.+)$"#
        if let regex = try? NSRegularExpression(pattern: decimalPattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            
            var quantity: Double? = nil
            var unit: String? = nil
            var name: String? = nil
            
            // Menge
            if let qtyRange = Range(match.range(at: 1), in: trimmed) {
                let qtyStr = String(trimmed[qtyRange])
                    .replacingOccurrences(of: ",", with: ".")
                quantity = Double(qtyStr)
            }
            
            // Einheit (optional)
            if let unitRange = Range(match.range(at: 2), in: trimmed),
               match.range(at: 2).length > 0 {
                unit = String(trimmed[unitRange])
            }
            
            // Name (Rest)
            if let nameRange = Range(match.range(at: 3), in: trimmed) {
                name = String(trimmed[nameRange]).trimmingCharacters(in: .whitespaces)
            }
            
            return ParseResult(
                qty: quantity,
                unit: unit,
                cleaned: name ?? trimmed
            )
        }
        
        // Versuch 2: Bruch-Notation
        // Muster: "1/2 TL Salz"
        let fractionPattern = #"^(\d+)/(\d+)\s*([a-zA-ZäöüßÄÖÜ]+)?\s+(.+)$"#
        if let regex = try? NSRegularExpression(pattern: fractionPattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            
            var quantity: Double? = nil
            var unit: String? = nil
            var name: String? = nil
            
            // Bruch berechnen
            if let numeratorRange = Range(match.range(at: 1), in: trimmed),
               let denominatorRange = Range(match.range(at: 2), in: trimmed),
               let numerator = Double(String(trimmed[numeratorRange])),
               let denominator = Double(String(trimmed[denominatorRange])),
               denominator != 0 {
                quantity = numerator / denominator
            }
            
            // Einheit (optional)
            if let unitRange = Range(match.range(at: 3), in: trimmed),
               match.range(at: 3).length > 0 {
                unit = String(trimmed[unitRange])
            }
            
            // Name
            if let nameRange = Range(match.range(at: 4), in: trimmed) {
                name = String(trimmed[nameRange]).trimmingCharacters(in: .whitespaces)
            }
            
            return ParseResult(
                qty: quantity,
                unit: unit,
                cleaned: name ?? trimmed
            )
        }
        
        // Kein Match: Gib Original-Text zurück
        return ParseResult(
            qty: nil,
            unit: nil,
            cleaned: trimmed
        )
    }
    
    /// Formatiert eine Menge für die Anzeige (entfernt .0 bei ganzen Zahlen)
    static func formatQuantity(_ quantity: Double) -> String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(quantity))
        } else {
            // 1-2 Dezimalstellen
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            return formatter.string(from: NSNumber(value: quantity)) ?? String(format: "%.2f", quantity)
        }
    }
}


// MARK: - Ingredient Extensions
extension Ingredient {
    // Hilfsfunktion: Prüft ob strukturiert
    var isStructured: Bool {
        return quantity != nil || (unit != nil && !unit!.isEmpty)
    }
    
    // Hilfsfunktion: Extrahiere den Anzeigetext (vollständig mit Menge + Einheit + Name)
    var displayText: String {
        var parts: [String] = []
        
        // Menge hinzufügen
        if let quantity = quantity {
            parts.append(QuantityParser.formatQuantity(quantity))
        }
        
        // Einheit hinzufügen
        if let unit = unit, !unit.isEmpty {
            parts.append(unit)
        }
        
        // Zutat/Name hinzufügen (food ist der Hauptname)
        if let food = food, !food.isEmpty {
            parts.append(food)
        }
        
        return parts.isEmpty ? "Zutat" : parts.joined(separator: " ")
    }
    
    // 🆕 Display-Text mit zusätzlicher Note
    var displayTextWithNote: String {
        var text = displayText
        
        if hasNote, let noteText = note {
            text += " (\(noteText))"
        }
        
        return text
    }
    
    // Hilfsfunktion: Kann strukturiert angezeigt werden
    var canShowStructured: Bool {
        if isStructured {
            return true
        }
        
        // Versuche zu parsen
        if let food = food, !food.isEmpty {
            let parsed = Ingredient.parseFromText(food)
            return parsed.quantity != nil || (parsed.unit != nil && !parsed.unit!.isEmpty)
        }
        
        return false
    }
    
    // Factory-Methoden
    static func newStructured() -> Ingredient {
        return Ingredient(
            food: "",
            note: nil,
            quantity: nil,
            unit: "",
            isCompleted: false,
            foodID: nil,
            unitID: nil,
            referenceId: nil  // ✅ Neue Zutat hat keine referenceId
        )
    }
    
    static func newSimple() -> Ingredient {
        return Ingredient(
            food: "",
            note: nil,
            quantity: nil,
            unit: nil,
            isCompleted: false,
            foodID: nil,
            unitID: nil,
            referenceId: nil  // ✅ Neue Zutat hat keine referenceId
        )
    }
    
    // Versuche eine Zutat aus Text zu parsen
    static func parseFromText(_ text: String) -> Ingredient {
        let parsed = QuantityParser.parse(from: text)
        
        return Ingredient(
            food: parsed.cleaned,
            note: nil,
            quantity: parsed.qty,
            unit: parsed.unit,
            isCompleted: false,
            foodID: nil,
            unitID: nil,
            referenceId: nil  // ✅ Geparste Zutat hat keine referenceId
        )
    }
}
