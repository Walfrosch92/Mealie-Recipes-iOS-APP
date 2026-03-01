//
//  RecipeUpdatePayload.swift
//  MealieRecipes
//
//  Beinhaltet sowohl strukturierte Zutaten (v3.x) als auch optional legacy ingredientStrings (v2.8)
//

import Foundation

struct RecipeUpdatePayload: Codable {
    struct TextItem: Codable { let text: String }

    struct Instruction: Codable {
        let id: String?  // Optional: Mealie generiert IDs wenn nil
        let text: String
        let title: String?
        let summary: String?
        let ingredientReferences: [String]
        
        // 🔧 Custom Encoding: Sende id NUR wenn != nil
        enum CodingKeys: String, CodingKey {
            case id, text, title, summary, ingredientReferences
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            // ✅ KRITISCH: id nur senden wenn != nil (niemals leeren String!)
            try container.encodeIfPresent(id, forKey: .id)
            
            // Text ist Pflichtfeld
            try container.encode(text, forKey: .text)
            
            // ✅ FIXED: title/summary nur senden wenn nicht leer, sonst null
            if let title = title, !title.isEmpty {
                try container.encode(title, forKey: .title)
            } else {
                try container.encodeNil(forKey: .title)
            }
            
            if let summary = summary, !summary.isEmpty {
                try container.encode(summary, forKey: .summary)
            } else {
                try container.encodeNil(forKey: .summary)
            }
            
            try container.encode(ingredientReferences, forKey: .ingredientReferences)
        }
    }

    /// Mealie v3.x Ingredient (nur API-konforme Felder)
    struct Ingredient: Codable {
        struct FoodRef: Codable {
            let id: String
            let name: String
        }
        
        struct UnitRef: Codable {
            let id: String
            let name: String
        }
        
        let referenceId: String?
        let note: String?
        let quantity: Double?
        let unit: UnitRef?      // ✅ KORRIGIERT: Objekt mit ID + Name
        let food: FoodRef?      // ✅ KORRIGIERT: Objekt mit ID + Name
        
        // 🔧 Benutzerdefiniertes Encoding: Entferne nil-Werte und ungültige Felder
        enum CodingKeys: String, CodingKey {
            case referenceId, note, quantity, unit, food
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            // ✅ KRITISCH: Alle Felder als null wenn nicht vorhanden
            // Mealie API v3.x rejected leere Strings als ungültig!
            try container.encode(referenceId, forKey: .referenceId)
            try container.encode(quantity, forKey: .quantity)
            try container.encode(unit, forKey: .unit)
            try container.encode(food, forKey: .food)
            
            // ✅ FIXED: note nur senden wenn nicht leer, sonst null
            if let note = note, !note.isEmpty {
                try container.encode(note, forKey: .note)
            } else {
                try container.encodeNil(forKey: .note)
            }
        }
    }


    struct Settings: Codable {
        let showAssets: Bool
        let `public`: Bool
        let showNutrition: Bool
        let landscapeView: Bool
        let disableComments: Bool
        let locked: Bool
        
        // ⚠️ WICHTIG: disableAmount wird NICHT mehr gesendet
        // Mealie v3.x verwendet dieses Feld nicht mehr in der API
        // (Es existiert nur noch in der UI, wird aber vom Server ignoriert/abgelehnt)
    }

    // Pflichtfelder/Metadaten
    let id: String
    let slug: String
    let name: String
    let description: String?
    let image: String?

    // Klassifikation (optional, nur wenn nicht leer)
    let tags: [RecipeTag]?
    let recipeCategory: [Category]?

    // Mengen/Zeiten
    let recipeServings: Int?        // ✅ Als Int statt Double (Mealie-konform)
    let recipeYieldQuantity: Int?   // ✅ Optional (nur senden wenn > 0)
    let prepTime: String?
    let performTime: String?        // ✅ performTime statt cookTime (Mealie verwendet performTime!)
    let totalTime: String?
    // ⚠️ rating wird NICHT hier gesendet, sondern über POST /api/users/{id}/ratings/{slug}

    // Optionen & Zusatz (optional, nur wenn nicht leer)
    let settings: Settings?
    let comments: [TextItem]?
    let notes: [TextItem]?
    let tools: [TextItem]?

    // Schritte & Zutaten
    let recipeInstructions: [Instruction]

    // ► Neu: beide Varianten erlaubt (nur eine sollte gesetzt sein)
    let recipeIngredient: [Ingredient]?
    let ingredientStrings: [String]?

    // Zeitstempel (optional)
    let dateUpdated: Date?
    
    // MARK: - Custom Encoding
    enum CodingKeys: String, CodingKey {
        case id, slug, name, description, image
        case tags, recipeCategory
        case recipeServings, recipeYieldQuantity
        case prepTime, performTime, totalTime  // ✅ performTime statt cookTime (Mealie-konform)
        case settings, comments, notes, tools
        case recipeInstructions, recipeIngredient, ingredientStrings
        case dateUpdated
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Pflichtfelder
        try container.encode(id, forKey: .id)
        try container.encode(slug, forKey: .slug)
        try container.encode(name, forKey: .name)
        
        // ✅ FIXED: description nur senden wenn nicht leer, sonst null
        if let desc = description, !desc.isEmpty {
            try container.encode(desc, forKey: .description)
        } else {
            try container.encodeNil(forKey: .description)
        }
        
        // ✅ KRITISCH: Image NIEMALS bei PATCH senden!
        // Image wird separat über PUT /api/recipes/{slug}/image hochgeladen
        // Wenn hier gesendet wird ein ValueError auf dem Server!
        // try container.encodeIfPresent(image, forKey: .image) // ❌ DEAKTIVIERT
        
        // Arrays nur wenn nicht nil UND nicht leer
        if let tags = tags, !tags.isEmpty {
            try container.encode(tags, forKey: .tags)
        }
        if let categories = recipeCategory, !categories.isEmpty {
            try container.encode(categories, forKey: .recipeCategory)
        }
        
        // Zeiten & Mengen
        try container.encodeIfPresent(recipeServings, forKey: .recipeServings)
        try container.encodeIfPresent(recipeYieldQuantity, forKey: .recipeYieldQuantity)
        try container.encodeIfPresent(prepTime, forKey: .prepTime)
        try container.encodeIfPresent(performTime, forKey: .performTime)  // ✅ performTime statt cookTime
        try container.encodeIfPresent(totalTime, forKey: .totalTime)
        // ⚠️ rating wird separat über POST /api/users/{id}/ratings/{slug} gesendet
        
        // Settings nur wenn nicht nil
        try container.encodeIfPresent(settings, forKey: .settings)
        
        // Optionale Arrays (nur wenn nicht leer)
        if let comments = comments, !comments.isEmpty {
            try container.encode(comments, forKey: .comments)
        }
        if let notes = notes, !notes.isEmpty {
            try container.encode(notes, forKey: .notes)
        }
        if let tools = tools, !tools.isEmpty {
            try container.encode(tools, forKey: .tools)
        }
        
        // Schritte & Zutaten
        try container.encode(recipeInstructions, forKey: .recipeInstructions)
        
        if let ingredients = recipeIngredient {
            try container.encode(ingredients, forKey: .recipeIngredient)
        } else if let strings = ingredientStrings {
            try container.encode(strings, forKey: .ingredientStrings)
        }
        
        // Zeitstempel
        try container.encodeIfPresent(dateUpdated, forKey: .dateUpdated)
    }
}

// MARK: - Komfort-Initialisierer aus RecipeDetail
extension RecipeUpdatePayload {
    /// Konvertiert Minuten in menschenlesbares Zeitformat (wie Mealie es erwartet)
    /// Beispiele: 
    ///   - 45 → "45 Minuten"
    ///   - 60 → "1 Stunde"
    ///   - 105 → "1 Stunde 45 Minuten"
    ///   - 120 → "2 Stunden"
    private static func minutesToHumanReadableTime(_ minutes: Int) -> String {
        // ✅ Sonderfall: 0 Minuten → leerer String (Mealie löscht das Feld)
        if minutes == 0 {
            return ""
        }
        
        // ✅ Negative Werte nicht erlaubt
        guard minutes > 0 else {
            #if DEBUG
            print("⚠️ Negative time value: \(minutes) → returning empty string")
            #endif
            return ""
        }
        
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        var parts: [String] = []
        
        // Stunden hinzufügen (falls vorhanden)
        if hours > 0 {
            if hours == 1 {
                parts.append("1 Stunde")
            } else {
                parts.append("\(hours) Stunden")
            }
        }
        
        // Minuten hinzufügen (falls vorhanden)
        if remainingMinutes > 0 {
            if remainingMinutes == 1 {
                parts.append("1 Minute")
            } else {
                parts.append("\(remainingMinutes) Minuten")
            }
        }
        
        let result = parts.joined(separator: " ")
        
        #if DEBUG
        print("⏱️ Converting \(minutes) minutes to human-readable: '\(result)'")
        #endif
        
        return result
    }
    
    // MARK: - Testing Helper (DEBUG only)
    #if DEBUG
    /// Testet die menschenlesbare Zeit-Konvertierung mit verschiedenen Werten
    /// Aufruf in Console: `RecipeUpdatePayload.testTimeConversion()`
    static func testTimeConversion() {
        print("\n🧪 Testing Human-Readable Time Conversion (Mealie Format):")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        let testCases: [(Int, String)] = [
            (0, ""),
            (1, "1 Minute"),
            (5, "5 Minuten"),
            (10, "10 Minuten"),
            (15, "15 Minuten"),
            (25, "25 Minuten"),
            (30, "30 Minuten"),
            (45, "45 Minuten"),
            (60, "1 Stunde"),
            (65, "1 Stunde 5 Minuten"),
            (90, "1 Stunde 30 Minuten"),
            (105, "1 Stunde 45 Minuten"),
            (120, "2 Stunden"),
            (135, "2 Stunden 15 Minuten"),
            (180, "3 Stunden"),
            (195, "3 Stunden 15 Minuten")
        ]
        
        var allPassed = true
        for (minutes, expected) in testCases {
            let result = minutesToHumanReadableTime(minutes)
            let passed = result == expected
            let icon = passed ? "✅" : "❌"
            
            print("\(icon) \(minutes) min → '\(result)' \(passed ? "" : "(expected: '\(expected)')")")
            
            if !passed {
                allPassed = false
            }
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print(allPassed ? "✅ All tests passed!" : "❌ Some tests failed!")
        print("")
    }
    #endif
    
    /// Normalisiert eine Einheit (inline implementation to avoid dependency issues)
    /// ✅ Konvertiert verschiedene Schreibweisen zu Mealie-konformen Namen
    private static func normalizeUnit(_ unit: String?) -> String? {
        guard let unit = unit?.trimmingCharacters(in: .whitespacesAndNewlines),
              !unit.isEmpty else {
            return nil
        }
        
        let lowercased = unit.lowercased()
        
        // ✅ Prüfe ob Unit entfernt werden soll (nicht in Mealie-DB)
        if unitsToRemove.contains(lowercased) {
            #if DEBUG
            print("🚫 Removing unsupported unit: '\(unit)' → nil")
            #endif
            return nil
        }
        
        // ✅ Verwende Mapping falls vorhanden (bevorzugt!)
        if let mapped = unitMapping[lowercased] {
            #if DEBUG
            if mapped != unit {
                print("🔄 Unit normalized: '\(unit)' → '\(mapped)'")
            }
            #endif
            return mapped
        }
        
        // ✅ Wenn nicht im Mapping: behalte Original (könnte bereits korrekt sein)
        // z.B. "Stück" bleibt "Stück", "Gramm" bleibt "Gramm"
        return unit
    }
    
    /// Mapping von verschiedenen Schreibweisen zu Standard-Einheiten
    /// ✅ Verwendet die EXAKTEN Namen aus der Mealie-Datenbank
    private static let unitMapping: [String: String] = [
        // Gewicht (Mealie verwendet volle Namen)
        "gramm": "Gramm", "gram": "Gramm", "grams": "Gramm", 
        "gr": "Gramm", "g": "Gramm",  // Abkürzungen → voller Name
        "kilogramm": "Kilogramm", "kilogram": "Kilogramm", "kilo": "Kilogramm",
        "kg": "Kilogramm",  // Abkürzung → voller Name
        "milligramm": "Milligramm", "milligram": "Milligramm",
        "mg": "Milligramm",  // Abkürzung → voller Name
        
        // Volumen (Mealie verwendet volle Namen)
        "milliliter": "Milliliter", "millilitre": "Milliliter",
        "ml": "Milliliter",  // Abkürzung → voller Name
        "liter": "Liter", "litre": "Liter",
        "l": "Liter",  // Abkürzung → voller Name
        "deziliter": "Deziliter", "deciliter": "Deziliter",
        "dl": "Deziliter",  // Abkürzung → voller Name
        "centiliter": "Centiliter", "cl": "Centiliter",
        
        // Löffel (Mealie verwendet volle Namen)
        "esslöffel": "Esslöffel", "essloffel": "Esslöffel", 
        "tablespoon": "Esslöffel", "tablespoons": "Esslöffel", 
        "tbsp": "Esslöffel", "tbs": "Esslöffel", "el": "Esslöffel",
        "teelöffel": "Teelöffel", "teeloffel": "Teelöffel", 
        "teaspoon": "Teelöffel", "teaspoons": "Teelöffel", 
        "tsp": "Teelöffel", "tl": "Teelöffel",
        
        // Tassen
        "tasse": "Tasse", "tassen": "Tasse", "cup": "Tasse", "cups": "Tasse",
        
        // Packung/Beutel (Mealie verwendet volle Namen)
        "packung": "Packung", "packungen": "Packung", 
        "pkg": "Packung", "package": "Packung", "pkt": "Packung",
        "beutel": "Beutel", "bag": "Beutel",
        
        // Stück (Mealie hat "Stück" in der DB!)
        "stück": "Stück", "stuck": "Stück", 
        "piece": "Stück", "pieces": "Stück",
        
        // Spezielle
        "prise": "Prise", "pinch": "Prise",
        "spritzer": "Spritzer", "dash": "Spritzer",
        "schuss": "Schuss", "splash": "Schuss",
        
        // Dosen/Gläser
        "dose": "Dose", "dosen": "Dose", "can": "Dose", "cans": "Dose",
        "glas": "Glas", "gläser": "Glas", "glaser": "Glas", "jar": "Glas", "jars": "Glas",
        
        // Bund/Zweig
        "bund": "Bund", "bunch": "Bund",
        "zweig": "Zweig", "zweige": "Zweig", "sprig": "Zweig", "sprigs": "Zweig",
        
        // Scheiben/Slices
        "scheibe": "Scheibe", "scheiben": "Scheibe", "slice": "Scheibe", "slices": "Scheibe",
        
        // Blätter
        "blatt": "Blatt", "blätter": "Blatt", "blatter": "Blatt", "leaf": "Blatt", "leaves": "Blatt",
        
        // Zehe (Knoblauch)
        "zehe": "Zehe", "zehen": "Zehe", "clove": "Zehe", "cloves": "Zehe"
    ]
    
    /// Units die zu nil konvertiert werden sollen (nicht in Mealie-DB)
    /// ⚠️ VORSICHT: Nur Begriffe entfernen, die definitiv keine validen Units sind!
    private static let unitsToRemove: Set<String> = [
        // Abkürzungen die mehrdeutig sind (könnte Stück sein, aber unklar)
        "stk", "stck", "pcs",
        
        // Farben (sollten ins Food-Feld)
        "rote", "gelbe", "grüne", "große", "kleine", "mittelgroße",
        
        // Adjektive (sollten ins Food/Note-Feld)
        "gelbe", "rote", "grüne", "weiße", "schwarze",
        "große", "kleine", "mittelgroße", "ganze", "halbe",
        
        // Mehrdeutige Begriffe
        "msp", "msp.", "messerspitze"
    ]
    
    /// Synchrone Initializer (Legacy - ohne Unit/Food Lookup)
    /// ⚠️ WARNUNG: Dieser Initializer funktioniert NICHT korrekt mit Mealie v3.x!
    /// Verwende stattdessen: RecipeUpdatePayload.create(from:apiService:)
    init(from detail: RecipeDetail, updatePrepTime: Bool = true, updateCookTime: Bool = true, updateTotalTime: Bool = true) {
        self.init(
            from: detail,
            resolvedUnits: [:],
            resolvedFoods: [:],
            updatePrepTime: updatePrepTime,
            updateCookTime: updateCookTime,
            updateTotalTime: updateTotalTime
        )
    }
    
    /// Asynchrone Initializer MIT Unit/Food ID Lookup
    /// ✅ KRITISCH: Mealie v3.x erwartet Objekte mit {id, name}, NICHT nur Strings!
    @MainActor
    static func create(
        from detail: RecipeDetail,
        apiService: APIService,
        updatePrepTime: Bool = true,
        updateCookTime: Bool = true,
        updateTotalTime: Bool = true,
        originalPrepTime: Int? = nil,
        originalCookTime: Int? = nil,
        originalTotalTime: Int? = nil
    ) async throws -> RecipeUpdatePayload {
        #if DEBUG
        print("🔍 Starte Ingredient Resolve-Phase...")
        #endif
        
        // Phase 1: Sammle alle einzigartigen Unit/Food Namen
        var uniqueUnitNames = Set<String>()
        var uniqueFoodNames = Set<String>()
        
        for ingredient in detail.ingredients {
            if let unit = ingredient.unit?.trimmingCharacters(in: .whitespacesAndNewlines),
               !unit.isEmpty {
                uniqueUnitNames.insert(unit)
            }
            if let food = ingredient.food?.trimmingCharacters(in: .whitespacesAndNewlines),
               !food.isEmpty {
                uniqueFoodNames.insert(food)
            }
        }
        
        #if DEBUG
        print("   📊 Zu resolvende Items:")
        print("      Units: \(uniqueUnitNames.count) → \(Array(uniqueUnitNames).joined(separator: ", "))")
        print("      Foods: \(uniqueFoodNames.count) → \(Array(uniqueFoodNames).joined(separator: ", "))")
        #endif
        
        // Phase 2: Resolve Units und Foods parallel
        var resolvedUnits: [String: Ingredient.UnitRef] = [:]
        var resolvedFoods: [String: Ingredient.FoodRef] = [:]
        
        // Lade alle Units und Foods vom Server
        let cache = IngredientAutocompleteCache.shared
        
        // Prüfe ob Cache geladen ist, wenn nicht: jetzt laden
        if cache.units.isEmpty || cache.foods.isEmpty {
            try await cache.preloadAll()
        }
        
        // Phase 2a: Resolve Units
        for unitName in uniqueUnitNames {
            if let resolved = try await resolveUnit(name: unitName, cache: cache) {
                resolvedUnits[unitName] = resolved
                #if DEBUG
                print("      ✅ Unit: '\(unitName)' → ID: \(resolved.id)")
                #endif
            } else {
                #if DEBUG
                print("      ⚠️ Unit: '\(unitName)' nicht gefunden, wird übersprungen")
                #endif
            }
        }
        
        // Phase 2b: Resolve Foods
        for foodName in uniqueFoodNames {
            if let resolved = try await resolveFood(name: foodName, cache: cache) {
                resolvedFoods[foodName] = resolved
                #if DEBUG
                print("      ✅ Food: '\(foodName)' → ID: \(resolved.id)")
                #endif
            } else {
                #if DEBUG
                print("      ⚠️ Food: '\(foodName)' nicht gefunden, wird übersprungen")
                #endif
            }
        }
        
        #if DEBUG
        print("✅ Resolve-Phase abgeschlossen:")
        print("   Units resolved: \(resolvedUnits.count)/\(uniqueUnitNames.count)")
        print("   Foods resolved: \(resolvedFoods.count)/\(uniqueFoodNames.count)")
        #endif
        
        return RecipeUpdatePayload(
            from: detail,
            resolvedUnits: resolvedUnits,
            resolvedFoods: resolvedFoods,
            updatePrepTime: updatePrepTime,
            updateCookTime: updateCookTime,
            updateTotalTime: updateTotalTime
        )
    }
    
    /// Resolved eine Unit: Sucht in Cache, erstellt falls nicht vorhanden
    @MainActor
    private static func resolveUnit(name: String, cache: IngredientAutocompleteCache) async throws -> Ingredient.UnitRef? {
        let normalized = normalizeUnit(name) ?? name
        
        // Suche im Cache (case-insensitive)
        if let existing = cache.units.first(where: { 
            $0.name.lowercased() == normalized.lowercased() 
        }) {
            return Ingredient.UnitRef(id: existing.id, name: existing.name)
        }
        
        // Nicht im Cache: Erstelle neue Unit über API
        #if DEBUG
        print("      🆕 Erstelle neue Unit: '\(normalized)'")
        #endif
        
        do {
            let newUnit = try await createUnit(name: normalized)
            return Ingredient.UnitRef(id: newUnit.id, name: newUnit.name)
        } catch {
            #if DEBUG
            print("      ❌ Fehler beim Erstellen von Unit '\(normalized)': \(error)")
            #endif
            return nil
        }
    }
    
    /// Resolved ein Food: Sucht in Cache, erstellt falls nicht vorhanden
    @MainActor
    private static func resolveFood(name: String, cache: IngredientAutocompleteCache) async throws -> Ingredient.FoodRef? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Suche im Cache (case-insensitive)
        if let existing = cache.foods.first(where: { 
            $0.name.lowercased() == trimmed.lowercased() 
        }) {
            return Ingredient.FoodRef(id: existing.id, name: existing.name)
        }
        
        // Nicht im Cache: Erstelle neues Food über API
        #if DEBUG
        print("      🆕 Erstelle neues Food: '\(trimmed)'")
        #endif
        
        do {
            let newFood = try await createFood(name: trimmed)
            return Ingredient.FoodRef(id: newFood.id, name: newFood.name)
        } catch {
            #if DEBUG
            print("      ❌ Fehler beim Erstellen von Food '\(trimmed)': \(error)")
            #endif
            return nil
        }
    }
    
    /// Erstellt eine neue Unit über die API
    private static func createUnit(name: String) async throws -> MealieUnit {
        guard let baseURL = APIService.shared.getBaseURL(),
              let token = APIService.shared.getToken() else {
            throw NSError(domain: "RecipeUpdatePayload", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "API not configured"])
        }
        
        let url = baseURL.appendingPathComponent("api/units")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let payload: [String: Any] = [
            "name": name,
            "abbreviation": "",
            "useAbbreviation": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(MealieUnit.self, from: data)
    }
    
    /// Erstellt ein neues Food über die API
    private static func createFood(name: String) async throws -> MealieFood {
        guard let baseURL = APIService.shared.getBaseURL(),
              let token = APIService.shared.getToken() else {
            throw NSError(domain: "RecipeUpdatePayload", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "API not configured"])
        }
        
        let url = baseURL.appendingPathComponent("api/foods")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let payload: [String: Any] = [
            "name": name,
            "description": ""
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(MealieFood.self, from: data)
    }
    
    // MARK: - Async Creation (Currently Disabled - IngredientLookupService not implemented)
    /*
    /// Asynchrone Initializer mit Unit/Food Lookup (convenience - ohne expliziten Service-Parameter)
    @MainActor
    static func create(from detail: RecipeDetail) async throws -> RecipeUpdatePayload {
        // ✅ Verwende den Shared Lookup-Service (nicht die duplizierte Klasse!)
        let lookupService = IngredientLookupService.shared
        return try await create(from: detail, lookupService: lookupService)
    }
    
    /// Asynchrone Initializer mit Unit/Food Lookup (mit explizitem Service)
    @MainActor
    static func create(from detail: RecipeDetail, lookupService: IngredientLookupProtocol?) async throws -> RecipeUpdatePayload {
        // Sammle alle Units/Foods die resolved werden müssen
        var resolvedUnits: [String: String] = [:]  // original → resolved name
        var resolvedFoods: [String: String] = [:]  // original → resolved name
        
        if let service = lookupService {
            // Sammle einzigartige Unit/Food Namen
            var unitStrings = Set<String>()
            var foodStrings = Set<String>()
            
            for ingredient in detail.ingredients {
                if let unit = ingredient.unit, !unit.isEmpty {
                    unitStrings.insert(unit)
                }
                if let food = ingredient.food, !food.isEmpty {
                    foodStrings.insert(food)
                }
            }
            
            // Resolve alle Units/Foods parallel
            try await withThrowingTaskGroup(of: Void.self) { group in
                // Units resolven
                for unitString in unitStrings {
                    group.addTask {
                        if let resolvedName = try await service.resolveUnit(unitString) {
                            resolvedUnits[unitString] = resolvedName
                        }
                    }
                }
                
                // Foods resolven
                for foodString in foodStrings {
                    group.addTask {
                        if let resolvedName = try await service.resolveFood(foodString) {
                            resolvedFoods[foodString] = resolvedName
                        }
                    }
                }
                
                // Warte auf alle Tasks
                try await group.waitForAll()
            }
            
            #if DEBUG
            if !resolvedUnits.isEmpty {
                print("🔍 Resolved Units:")
                for (original, name) in resolvedUnits {
                    print("   '\(original)' → '\(name)'")
                }
            }
            
            if !resolvedFoods.isEmpty {
                print("🔍 Resolved Foods:")
                for (original, name) in resolvedFoods {
                    print("   '\(original)' → '\(name)'")
                }
            }
            #endif
        }
        
        return RecipeUpdatePayload(from: detail, resolvedUnits: resolvedUnits, resolvedFoods: resolvedFoods)
    }
    */
    
    /// Interner Initializer mit resolvierten Unit/Food IDs
    private init(
        from detail: RecipeDetail,
        resolvedUnits: [String: Ingredient.UnitRef],
        resolvedFoods: [String: Ingredient.FoodRef],
        updatePrepTime: Bool = true,
        updateCookTime: Bool = true,
        updateTotalTime: Bool = true
    ) {
        // Schritte: KEINE ID senden! Mealie generiert die IDs automatisch
        let steps: [Instruction] = detail.instructions.map { instruction in
            Instruction(
                id: nil,  // ✅ Keine ID - Mealie erstellt automatisch neue IDs
                text: instruction.text,
                title: nil,
                summary: nil,
                ingredientReferences: []
            )
        }

        // Zutaten: v3.x bevorzugen → wenn Mengen/Einheit verfügbar
        // Wir generieren daraus „structured“ Zutaten; ansonsten legacy Strings.
        let hasStructured = !detail.ingredients.isEmpty  // ✅ Aktiviert - verwende IDs wenn verfügbar

        #if DEBUG
        print("✅ Strukturierte Zutaten werden gesendet (Mealie erstellt Foods/Units automatisch)")
        print("   Ingredients: \(detail.ingredients.count)")
        #endif

        // Strukturierte Zutaten: Verwende resolved IDs
        let structured: [Ingredient]? = hasStructured ? detail.ingredients.compactMap { ingredient -> Ingredient? in
            let qMaybe = ingredient.quantity
            let food = (ingredient.food ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let unit = (ingredient.unit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let note = (ingredient.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip komplett leere Zutaten
            if qMaybe == nil && unit.isEmpty && food.isEmpty && note.isEmpty {
                #if DEBUG
                print("⚠️ Skipping completely empty ingredient")
                #endif
                return nil
            }
            
            // ✅ WICHTIG: Mindestens food ODER note muss vorhanden sein!
            if food.isEmpty && note.isEmpty {
                #if DEBUG
                print("⚠️ Skipping ingredient without food or note")
                #endif
                return nil
            }
            
            // ✅ Verwende resolved Unit/Food IDs
            let unitRef: Ingredient.UnitRef? = unit.isEmpty ? nil : resolvedUnits[unit]
            let foodRef: Ingredient.FoodRef? = food.isEmpty ? nil : resolvedFoods[food]
            
            // Food muss vorhanden sein (entweder resolved oder fehlgeschlagen)
            guard let foodRef = foodRef else {
                #if DEBUG
                print("⚠️ SKIPPED: Food '\(food)' konnte nicht resolved werden")
                #endif
                return nil
            }
            
            let sendNote = note.isEmpty ? nil : note
            let sendQuantity = qMaybe

            // ✅ KRITISCH: referenceId erhalten (für existierende Zutaten) oder neue generieren
            let refId = ingredient.referenceId ?? UUID().uuidString
            
            #if DEBUG
            if ingredient.referenceId != nil {
                print("♻️ Bestehende Zutat: referenceId=\(refId) erhalten")
            } else {
                print("🆕 Neue Zutat: referenceId=\(refId) generiert")
            }
            #endif

            // Debug: Zeige was gesendet wird
            #if DEBUG
            if let u = unitRef {
                print("📝 Unit: '\(u.name)' (ID: \(u.id))")
            }
            print("📝 Food: '\(foodRef.name)' (ID: \(foodRef.id))")
            #endif

            let result = Ingredient(
                referenceId: refId,    // ✅ KRITISCH: referenceId erhalten!
                note: sendNote,
                quantity: sendQuantity,
                unit: unitRef,      // ✅ Objekt mit {id, name}
                food: foodRef       // ✅ Objekt mit {id, name}
            )
            
            // ✅ DEBUG: Log was gesendet wird
            #if DEBUG
            var displayParts: [String] = []
            if let q = sendQuantity { displayParts.append(String(format: "%.1f", q)) }
            if let u = unitRef { displayParts.append(u.name) }
            displayParts.append(foodRef.name)
            if let n = sendNote { displayParts.append("(\(n))") }
            
            print("📤 Sending: \(displayParts.joined(separator: " "))")
            #endif
            
            return result
        } : nil


        let legacy: [String]? = hasStructured ? nil : detail.ingredients.map { $0.food ?? $0.note ?? "" }.filter { !$0.isEmpty }

        // ✅ Konvertiere recipeServings zu Int (Mealie-konform)
        let servingsInt = detail.recipeServings.map { Int($0.rounded()) }
        
        // ✅ Nur nicht-leere Arrays senden
        let tagsToSend = detail.tags.isEmpty ? nil : detail.tags
        let categoriesToSend = detail.recipeCategory.isEmpty ? nil : detail.recipeCategory
        let commentsToSend = detail.comments.isEmpty ? nil : detail.comments.map { TextItem(text: $0.text) }
        let notesToSend = detail.notes.isEmpty ? nil : detail.notes.map { TextItem(text: $0.text) }
        let toolsToSend = detail.tools.isEmpty ? nil : detail.tools.map { TextItem(text: $0.text) }
        
        // ✅ Nur senden wenn recipeYieldQuantity > 0
        let yieldToSend = detail.recipeYieldQuantity > 0 ? detail.recipeYieldQuantity : nil
        
        // ✅ NEU: Smart Time Handling für ALLE Zeitfelder
        // Nur wenn explizit updatePrepTime/updateCookTime/updateTotalTime gesetzt ist,
        // wird der Wert als menschenlesbares Format konvertiert und gesendet.
        // Ansonsten wird nil gesendet, was Mealie dazu bringt, den existierenden Wert zu behalten.
        let prepTimeToSend: String? = updatePrepTime
            ? detail.prepTime.map { Self.minutesToHumanReadableTime($0) }
            : nil
        
        let performTimeToSend: String? = updateCookTime
            ? detail.cookTime.map { Self.minutesToHumanReadableTime($0) }
            : nil
        
        let totalTimeToSend: String? = updateTotalTime
            ? detail.totalTime.map { Self.minutesToHumanReadableTime($0) }
            : nil
        
        #if DEBUG
        if !updatePrepTime {
            print("⏱️ prepTime NICHT geändert → nil gesendet (Server behält Original)")
        } else if let pt = prepTimeToSend {
            print("⏱️ prepTime geändert → '\(pt)' gesendet")
        }
        
        if !updateCookTime {
            print("⏱️ performTime NICHT geändert → nil gesendet (Server behält Original)")
        } else if let ct = performTimeToSend {
            print("⏱️ performTime geändert → '\(ct)' gesendet")
        }
        
        if !updateTotalTime {
            print("⏱️ totalTime NICHT geändert → nil gesendet (Server behält Original)")
        } else if let tt = totalTimeToSend {
            print("⏱️ totalTime geändert → '\(tt)' gesendet")
        }
        #endif
        
        // ✅ Image: NIEMALS senden bei PATCH (würde zu ValueError führen)
        // Image wird separat über PUT /api/recipes/{slug}/image hochgeladen
        let imageToSend: String? = nil
        
        #if DEBUG
        if detail.image != nil && !detail.image!.isEmpty {
            print("🖼️ Image field ignored for PATCH (sent separately via PUT)")
        }
        #endif

        self.init(
            id: detail.id,
            slug: detail.slug,
            name: detail.name,
            description: detail.description,
            image: imageToSend,
            tags: tagsToSend,
            recipeCategory: categoriesToSend,
            recipeServings: servingsInt,
            recipeYieldQuantity: yieldToSend,
            prepTime: prepTimeToSend,
            performTime: performTimeToSend,  // ✅ FIXED: performTime statt cookTime (Mealie-Standard)
            totalTime: totalTimeToSend,
            // ⚠️ rating wird NICHT hier gesendet - siehe setRating() für separaten API-Call
            settings: .init(
                showAssets: detail.settings.showAssets,
                public: detail.settings.public,
                showNutrition: detail.settings.showNutrition,
                landscapeView: detail.settings.landscapeView,
                disableComments: detail.settings.disableComments,
                locked: detail.settings.locked
            ),
            comments: commentsToSend,
            notes: notesToSend,
            tools: toolsToSend,
            recipeInstructions: steps,
            recipeIngredient: structured,
            ingredientStrings: legacy,
            dateUpdated: Date()
        )
    }
}
