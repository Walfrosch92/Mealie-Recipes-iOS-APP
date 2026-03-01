//
//  IngredientLookupService.swift
//  MealieRecipes
//
//  Service für Unit/Food Lookup und Auto-Creation
//

import Foundation

/// Repräsentiert eine Mealie Unit (Einheit)
struct MealieUnit: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let pluralName: String?
    let abbreviation: String?
    let useAbbreviation: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, name, pluralName, abbreviation, useAbbreviation
    }
}

/// Repräsentiert ein Mealie Food (Zutat)
struct MealieFood: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let pluralName: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, pluralName
    }
}

/// Service für Unit/Food Lookup und Normalisierung
@MainActor
class IngredientLookupService: ObservableObject, IngredientLookupProtocol {
    static let shared = IngredientLookupService()
    
    @Published private(set) var units: [MealieUnit] = []
    @Published private(set) var foods: [MealieFood] = []
    
    private var lastFetch: Date?
    private let cacheLifetime: TimeInterval = 300 // 5 Minuten
    
    private init() {}
    
    // MARK: - Public API
    
    /// Findet die passende Unit oder legt sie an
    func resolveUnit(_ unitString: String?) async throws -> String? {
        guard let unitString = unitString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !unitString.isEmpty else {
            return nil
        }
        
        // Lade Units falls nötig
        try await fetchUnitsIfNeeded()
        
        // Suche nach exakter Übereinstimmung
        if let exact = findExactUnit(unitString) {
            return exact.name // ✅ Gebe den offiziellen Namen zurück
        }
        
        // Suche nach Abkürzung
        if let byAbbreviation = findUnitByAbbreviation(unitString) {
            return byAbbreviation.name
        }
        
        // Suche fuzzy (ähnliche Namen)
        if let fuzzy = findFuzzyUnit(unitString) {
            #if DEBUG
            print("🔍 Fuzzy Match: '\(unitString)' → '\(fuzzy.name)'")
            #endif
            return fuzzy.name
        }
        
        // ❌ Unit existiert nicht → Erstelle sie
        #if DEBUG
        print("➕ Creating new unit: '\(unitString)'")
        #endif
        
        do {
            let newUnit = try await createUnit(name: unitString)
            units.append(newUnit)
            return newUnit.name
        } catch {
            // Falls Creation fehlschlägt: Verwende Original-String
            #if DEBUG
            print("⚠️ Failed to create unit '\(unitString)': \(error)")
            #endif
            return unitString
        }
    }
    
    /// Findet das passende Food oder legt es an
    func resolveFood(_ foodString: String?) async throws -> String? {
        guard let foodString = foodString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !foodString.isEmpty else {
            return nil
        }
        
        // Lade Foods falls nötig
        try await fetchFoodsIfNeeded()
        
        // Suche nach exakter Übereinstimmung
        if let exact = findExactFood(foodString) {
            return exact.name
        }
        
        // Suche fuzzy (ähnliche Namen)
        if let fuzzy = findFuzzyFood(foodString) {
            #if DEBUG
            print("🔍 Fuzzy Match: '\(foodString)' → '\(fuzzy.name)'")
            #endif
            return fuzzy.name
        }
        
        // ❌ Food existiert nicht → Erstelle es
        #if DEBUG
        print("➕ Creating new food: '\(foodString)'")
        #endif
        
        do {
            let newFood = try await createFood(name: foodString)
            foods.append(newFood)
            return newFood.name
        } catch {
            // Falls Creation fehlschlägt: Verwende Original-String
            #if DEBUG
            print("⚠️ Failed to create food '\(foodString)': \(error)")
            #endif
            return foodString
        }
    }
    
    // MARK: - Fetching
    
    private func fetchUnitsIfNeeded() async throws {
        // Cache-Check
        if let lastFetch = lastFetch,
           Date().timeIntervalSince(lastFetch) < cacheLifetime,
           !units.isEmpty {
            return
        }
        
        try await fetchUnits()
    }
    
    private func fetchFoodsIfNeeded() async throws {
        // Cache-Check
        if let lastFetch = lastFetch,
           Date().timeIntervalSince(lastFetch) < cacheLifetime,
           !foods.isEmpty {
            return
        }
        
        try await fetchFoods()
    }
    
    private func fetchUnits() async throws {
        let request = try APIService.shared.createRequest(
            path: "api/organizers/units?perPage=9999"
        )
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct Response: Decodable {
            let items: [MealieUnit]
        }
        
        let response = try JSONDecoder().decode(Response.self, from: data)
        units = response.items
        lastFetch = Date()
        
        #if DEBUG
        print("✅ Loaded \(units.count) units from server")
        #endif
    }
    
    private func fetchFoods() async throws {
        let request = try APIService.shared.createRequest(
            path: "api/organizers/foods?perPage=9999"
        )
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct Response: Decodable {
            let items: [MealieFood]
        }
        
        let response = try JSONDecoder().decode(Response.self, from: data)
        foods = response.items
        lastFetch = Date()
        
        #if DEBUG
        print("✅ Loaded \(foods.count) foods from server")
        #endif
    }
    
    // MARK: - Searching
    
    private func findExactUnit(_ name: String) -> MealieUnit? {
        units.first { $0.name.lowercased() == name.lowercased() }
    }
    
    private func findUnitByAbbreviation(_ abbr: String) -> MealieUnit? {
        units.first { 
            guard let abbreviation = $0.abbreviation else { return false }
            return abbreviation.lowercased() == abbr.lowercased()
        }
    }
    
    private func findFuzzyUnit(_ name: String) -> MealieUnit? {
        let normalized = name.lowercased()
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ä", with: "a")
            .replacingOccurrences(of: "ß", with: "ss")
        
        // Suche nach Plural-Namen
        if let byPlural = units.first(where: { 
            $0.pluralName?.lowercased() == normalized 
        }) {
            return byPlural
        }
        
        // Suche nach partieller Übereinstimmung
        return units.first { unit in
            let unitNormalized = unit.name.lowercased()
                .replacingOccurrences(of: "ü", with: "u")
                .replacingOccurrences(of: "ö", with: "o")
                .replacingOccurrences(of: "ä", with: "a")
                .replacingOccurrences(of: "ß", with: "ss")
            
            return unitNormalized.contains(normalized) || normalized.contains(unitNormalized)
        }
    }
    
    private func findExactFood(_ name: String) -> MealieFood? {
        foods.first { $0.name.lowercased() == name.lowercased() }
    }
    
    private func findFuzzyFood(_ name: String) -> MealieFood? {
        let normalized = name.lowercased()
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ä", with: "a")
            .replacingOccurrences(of: "ß", with: "ss")
        
        // Suche nach Plural-Namen
        if let byPlural = foods.first(where: { 
            $0.pluralName?.lowercased() == normalized 
        }) {
            return byPlural
        }
        
        // Suche nach partieller Übereinstimmung (nur wenn > 80% Match)
        return foods.first { food in
            let foodNormalized = food.name.lowercased()
                .replacingOccurrences(of: "ü", with: "u")
                .replacingOccurrences(of: "ö", with: "o")
                .replacingOccurrences(of: "ä", with: "a")
                .replacingOccurrences(of: "ß", with: "ss")
            
            // Levenshtein-ähnliche Prüfung
            let similarity = stringSimilarity(foodNormalized, normalized)
            return similarity > 0.8
        }
    }
    
    // MARK: - Creation
    
    private func createUnit(name: String) async throws -> MealieUnit {
        struct CreatePayload: Encodable {
            let name: String
            let fraction: Bool = true
        }
        
        let payload = CreatePayload(name: name)
        let encoder = JSONEncoder()
        let body = try encoder.encode(payload)
        
        let request = try APIService.shared.createRequest(
            path: "api/organizers/units",
            method: "POST",
            body: body
        )
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw NSError(domain: "CreateUnit", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create unit '\(name)'"
            ])
        }
        
        return try JSONDecoder().decode(MealieUnit.self, from: data)
    }
    
    private func createFood(name: String) async throws -> MealieFood {
        struct CreatePayload: Encodable {
            let name: String
        }
        
        let payload = CreatePayload(name: name)
        let encoder = JSONEncoder()
        let body = try encoder.encode(payload)
        
        let request = try APIService.shared.createRequest(
            path: "api/organizers/foods",
            method: "POST",
            body: body
        )
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw NSError(domain: "CreateFood", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create food '\(name)'"
            ])
        }
        
        return try JSONDecoder().decode(MealieFood.self, from: data)
    }
    
    // MARK: - Helpers
    
    /// Berechnet String-Ähnlichkeit (0.0 - 1.0)
    private func stringSimilarity(_ s1: String, _ s2: String) -> Double {
        guard !s1.isEmpty && !s2.isEmpty else { return 0 }
        
        let longer = s1.count > s2.count ? s1 : s2
        let shorter = s1.count > s2.count ? s2 : s1
        
        if longer.count == 0 {
            return 1.0
        }
        
        let editDistance = levenshteinDistance(s1, s2)
        return (Double(longer.count) - Double(editDistance)) / Double(longer.count)
    }
    
    /// Levenshtein Distance
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: s2Array.count + 1), 
                           count: s1Array.count + 1)
        
        for i in 0...s1Array.count {
            matrix[i][0] = i
        }
        
        for j in 0...s2Array.count {
            matrix[0][j] = j
        }
        
        for i in 1...s1Array.count {
            for j in 1...s2Array.count {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }
        
        return matrix[s1Array.count][s2Array.count]
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        units = []
        foods = []
        lastFetch = nil
    }
    
    func refreshCache() async throws {
        lastFetch = nil
        try await fetchUnits()
        try await fetchFoods()
    }
}
