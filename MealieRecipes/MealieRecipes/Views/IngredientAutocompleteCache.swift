//
//  IngredientAutocompleteCache.swift
//  MealieRecipes
//
//  Enhanced autocomplete with server-backed Units and Foods
//

import Foundation

// MARK: - Models

/// Mealie Unit (from API)
struct MealieUnit: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let abbreviation: String?
    let useAbbreviation: Bool?
    
    var displayName: String {
        if useAbbreviation == true, let abbr = abbreviation, !abbr.isEmpty {
            return abbr
        }
        return name
    }
}

/// Mealie Food (from API)
struct MealieFood: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
}

// MARK: - Autocomplete Cache with API Integration

@MainActor
class IngredientAutocompleteCache: ObservableObject {
    static let shared = IngredientAutocompleteCache()
    
    // Server-backed data
    @Published private(set) var units: [MealieUnit] = []
    @Published private(set) var foods: [MealieFood] = []
    
    // Local cache keys
    private let unitsKey = "cachedIngredientUnits"
    private let notesKey = "cachedIngredientNotes"
    private let maxCacheSize = 500
    
    @Published private(set) var cachedUnits: Set<String> = []
    @Published private(set) var cachedNotes: Set<String> = []
    
    // Loading state
    @Published private(set) var isLoading = false
    
    private init() {
        loadCache()
    }
    
    // MARK: - Preload All Data
    
    /// Lädt Units und Foods vom Server
    func preloadAll() async throws {
        isLoading = true
        defer { isLoading = false }
        
        async let unitsTask = fetchUnits()
        async let foodsTask = fetchFoods()
        
        let (fetchedUnits, fetchedFoods) = try await (unitsTask, foodsTask)
        
        self.units = fetchedUnits
        self.foods = fetchedFoods
        
        #if DEBUG
        print("✅ Preloaded \(units.count) units and \(foods.count) foods from server")
        #endif
    }
    
    // MARK: - Fetch from Server
    
    /// Lädt alle Units vom Server
    func fetchUnits(query: String? = nil) async throws -> [MealieUnit] {
        guard let baseURL = APIService.shared.getBaseURL(),
              let token = APIService.shared.getToken() else {
            throw NSError(domain: "IngredientAutocompleteCache", code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: "API not configured"])
        }
        
        var path = "api/units"
        if let query = query, !query.isEmpty {
            path += "?search=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        }
        
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct Response: Codable {
            let items: [MealieUnit]
        }
        
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.items
    }
    
    /// Lädt alle Foods vom Server
    func fetchFoods(query: String? = nil) async throws -> [MealieFood] {
        guard let baseURL = APIService.shared.getBaseURL(),
              let token = APIService.shared.getToken() else {
            throw NSError(domain: "IngredientAutocompleteCache", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "API not configured"])
        }
        
        var path = "api/foods"
        if let query = query, !query.isEmpty {
            path += "?search=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        }
        
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct Response: Codable {
            let items: [MealieFood]
        }
        
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.items
    }
    
    // MARK: - Search (Local Filter)
    
    /// Sucht Units (filtert lokale Daten)
    func searchUnits(query: String) -> [MealieUnit] {
        guard !query.isEmpty else { return Array(units.prefix(8)) }
        
        let lowercaseQuery = query.lowercased()
        
        return units
            .filter { unit in
                unit.name.lowercased().contains(lowercaseQuery) ||
                unit.displayName.lowercased().contains(lowercaseQuery)
            }
            .prefix(8)
            .map { $0 }
    }
    
    /// Sucht Foods (filtert lokale Daten)
    func searchFoods(query: String) -> [MealieFood] {
        guard !query.isEmpty else { return Array(foods.prefix(8)) }
        
        let lowercaseQuery = query.lowercased()
        
        return foods
            .filter { $0.name.lowercased().contains(lowercaseQuery) }
            .prefix(8)
            .map { $0 }
    }
    
    // MARK: - Create New (if not exists)
    
    /// Erstellt eine neue Unit auf dem Server (falls sie nicht existiert)
    func createUnit(name: String) async throws -> MealieUnit {
        // Prüfe ob bereits vorhanden
        if let existing = units.first(where: { $0.name.lowercased() == name.lowercased() }) {
            #if DEBUG
            print("✅ Unit '\(name)' already exists with id: \(existing.id)")
            #endif
            return existing
        }
        
        guard let baseURL = APIService.shared.getBaseURL(),
              let token = APIService.shared.getToken() else {
            throw NSError(domain: "IngredientAutocompleteCache", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "API not configured"])
        }
        
        struct CreatePayload: Codable {
            let name: String
        }
        
        let payload = CreatePayload(name: name)
        let body = try JSONEncoder().encode(payload)
        
        let url = baseURL.appendingPathComponent("api/units")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let newUnit = try JSONDecoder().decode(MealieUnit.self, from: data)
        
        // Zur lokalen Liste hinzufügen
        units.append(newUnit)
        
        #if DEBUG
        print("✅ Created new unit '\(name)' with id: \(newUnit.id)")
        #endif
        
        return newUnit
    }
    
    /// Erstellt ein neues Food auf dem Server (falls es nicht existiert)
    func createFood(name: String) async throws -> MealieFood {
        // Prüfe ob bereits vorhanden
        if let existing = foods.first(where: { $0.name.lowercased() == name.lowercased() }) {
            #if DEBUG
            print("✅ Food '\(name)' already exists with id: \(existing.id)")
            #endif
            return existing
        }
        
        guard let baseURL = APIService.shared.getBaseURL(),
              let token = APIService.shared.getToken() else {
            throw NSError(domain: "IngredientAutocompleteCache", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "API not configured"])
        }
        
        struct CreatePayload: Codable {
            let name: String
        }
        
        let payload = CreatePayload(name: name)
        let body = try JSONEncoder().encode(payload)
        
        let url = baseURL.appendingPathComponent("api/foods")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let newFood = try JSONDecoder().decode(MealieFood.self, from: data)
        
        // Zur lokalen Liste hinzufügen
        foods.append(newFood)
        
        #if DEBUG
        print("✅ Created new food '\(name)' with id: \(newFood.id)")
        #endif
        
        return newFood
    }
    
    // MARK: - Local Cache (Legacy Support)
    
    private func loadCache() {
        if let unitsData = UserDefaults.standard.data(forKey: unitsKey),
           let units = try? JSONDecoder().decode(Set<String>.self, from: unitsData) {
            cachedUnits = units
        }
        
        if let notesData = UserDefaults.standard.data(forKey: notesKey),
           let notes = try? JSONDecoder().decode(Set<String>.self, from: notesData) {
            cachedNotes = notes
        }
    }
    
    private func saveCache() {
        if let unitsData = try? JSONEncoder().encode(cachedUnits) {
            UserDefaults.standard.set(unitsData, forKey: unitsKey)
        }
        
        if let notesData = try? JSONEncoder().encode(cachedNotes) {
            UserDefaults.standard.set(notesData, forKey: notesKey)
        }
    }
    
    func addUnit(_ unit: String) {
        let trimmed = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        cachedUnits.insert(trimmed)
        
        if cachedUnits.count > maxCacheSize {
            cachedUnits = Set(cachedUnits.sorted().suffix(maxCacheSize))
        }
        
        saveCache()
    }
    
    func addNote(_ note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count > 2 else { return }
        
        cachedNotes.insert(trimmed)
        
        if cachedNotes.count > maxCacheSize {
            cachedNotes = Set(cachedNotes.sorted().suffix(maxCacheSize))
        }
        
        saveCache()
    }
    
    func addIngredient(_ ingredient: Ingredient) {
        if let unit = ingredient.unit, !unit.isEmpty {
            addUnit(unit)
        }
        if let note = ingredient.note, !note.isEmpty {
            addNote(note)
        }
    }
    
    func unitSuggestions(for query: String) -> [String] {
        guard !query.isEmpty else { return [] }
        
        let lowercaseQuery = query.lowercased()
        
        // Kombiniere Server-Units und cachedUnits
        var allUnitNames = Set(units.map { $0.displayName })
        allUnitNames.formUnion(cachedUnits)
        
        return allUnitNames
            .filter { $0.lowercased().hasPrefix(lowercaseQuery) }
            .sorted()
            .prefix(8)
            .map { $0 }
    }
    
    func noteSuggestions(for query: String) -> [String] {
        guard !query.isEmpty else { return [] }
        
        let lowercaseQuery = query.lowercased()
        
        return cachedNotes
            .filter { $0.lowercased().hasPrefix(lowercaseQuery) }
            .sorted()
            .prefix(8)
            .map { $0 }
    }
    
    func clearCache() {
        cachedUnits.removeAll()
        cachedNotes.removeAll()
        units.removeAll()
        foods.removeAll()
        saveCache()
    }
}
