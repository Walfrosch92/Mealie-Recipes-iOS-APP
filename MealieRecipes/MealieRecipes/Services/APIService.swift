import Foundation
import UIKit

// MARK: - API Error Types
enum APIError: LocalizedError {
    case invalidResponse
    case missingConfiguration
    case httpError(statusCode: Int, message: String)
    case encodingFailed
    case decodingFailed(Error)
    case invalidURL
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Keine HTTP Response erhalten"
        case .missingConfiguration:
            return "Base URL oder Token fehlt"
        case .httpError(let statusCode, let message):
            return "HTTP Fehler \(statusCode): \(message)"
        case .encodingFailed:
            return "Encoding fehlgeschlagen"
        case .decodingFailed(let error):
            return "Decoding fehlgeschlagen: \(error.localizedDescription)"
        case .invalidURL:
            return "Ungültige URL"
        case .networkError(let error):
            return "Netzwerkfehler: \(error.localizedDescription)"
        }
    }
}

enum MealieAPIVersion: String {
    case v2_8 = "2.8"
    case v3 = "3"
}

// MARK: - APIService
class APIService {
    
    // MARK: - Singleton
    static let shared = APIService()
    
    // MARK: - Constants
    private enum Constants {
        static let localNetworkPrefixes = ["192.168.", "10.", "127.", "172."]
        static let defaultCompressionQuality: CGFloat = 0.8
    }
    
    // MARK: - Properties
    private var baseURL: URL?
    private var token: String?
    private var optionalHeaders: [String: String] = [:]
    private var apiVersion: MealieAPIVersion = .v2_8
    private var cachedUserId: String?
    
    // MARK: - Public Accessors
    var getOptionalHeaders: [String: String] {
        optionalHeaders
    }
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Configuration
    
    func configure(baseURL: URL, token: String, optionalHeaders: [String: String] = [:]) {
        // Normalisiere URL-Scheme zu lowercase
        let normalizedURL = normalizeURLScheme(baseURL)
        
        self.baseURL = normalizedURL
        self.token = token
        
        // Filtere leere Header
        let cleanedHeaders = optionalHeaders.filter { !$0.key.isEmpty && !$0.value.isEmpty }
        
        // Nur bei nicht-lokalen URLs optionale Header verwenden
        if isLocalNetwork(normalizedURL) {
            self.optionalHeaders = [:]
        } else {
            self.optionalHeaders = cleanedHeaders
        }
        
        // Cache bei Neukonfiguration zurücksetzen
        clearUserIdCache()
    }
    
    // MARK: - Private Helpers
    
    /// Bestimmt die bevorzugte Sprache für API-Requests (z.B. OCR-Import)
    /// - Returns: BCP 47 Sprach-Code (z.B. "en-US", "de-DE", "es-ES")
    private func determinePreferredLanguage() -> String {
        // 1. Prüfe AppSettings (falls vorhanden)
        let appLanguage = AppSettings.shared.selectedLanguage
        
        // 2. Konvertiere zu BCP 47 Format
        let languageMapping: [String: String] = [
            "de": "de-DE",
            "en": "en-US",
            "es": "es-ES",
            "fr": "fr-FR",
            "nl": "nl-NL",
            "it": "it-IT",
            "pt": "pt-PT",
            "pl": "pl-PL",
            "ru": "ru-RU",
            "zh": "zh-CN",
            "ja": "ja-JP",
            "ko": "ko-KR"
        ]
        
        // 3. Bestimme Basis-Sprachcode (z.B. "de" aus "de-DE")
        let baseLanguage = appLanguage.components(separatedBy: "-").first ?? "en"
        
        // 4. Verwende Mapping oder Default
        let mappedLanguage = languageMapping[baseLanguage] ?? "en-US"
        
        #if DEBUG
        log("🌍 Ermittelte Import-Sprache: \(mappedLanguage) (aus App-Sprache: \(appLanguage))")
        #endif
        
        return mappedLanguage
    }
    
    /// Normalisiert URL-Scheme zu lowercase
    private func normalizeURLScheme(_ url: URL) -> URL {
        guard let scheme = url.scheme?.lowercased(),
              scheme != url.scheme,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        
        components.scheme = scheme
        
        if let correctedURL = components.url {
            #if DEBUG
            log("🔧 URL-Scheme normalisiert: \(url.absoluteString) → \(correctedURL.absoluteString)")
            #endif
            return correctedURL
        }
        
        return url
    }
    
    /// Prüft ob URL ein lokales Netzwerk ist
    private func isLocalNetwork(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        return Constants.localNetworkPrefixes.contains { host.hasPrefix($0) }
    }
    
    /// Zentrale Logging-Funktion
    private func log(_ message: String) {
        Swift.print(message)
        if AppSettings.shared.enableLogging {
            LogManager.shared.logPrint(message)
        }
    }
    
    // MARK: - API Version Management
    
    func setAPIVersion(_ version: MealieAPIVersion) {
        self.apiVersion = version
    }

    func getAPIVersion() -> MealieAPIVersion {
        return apiVersion
    }

    func getBaseURL() -> URL? { baseURL }
    func getToken() -> String? { token }
    
    // MARK: - User Info
    
    /// Ruft die aktuelle User-ID vom Server ab und cached sie
    func getCurrentUserId() async throws -> String {
        // Verwende gecachte User-ID falls vorhanden
        if let cached = cachedUserId {
            return cached
        }
        
        // Abrufen vom Server
        let request = try createRequest(path: "api/users/self")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        struct UserSelfResponse: Codable {
            let id: String
            let username: String?
            let email: String?
        }
        
        let userInfo = try JSONDecoder().decode(UserSelfResponse.self, from: data)
        
        #if DEBUG
        log("✅ User-ID abgerufen: \(userInfo.id)")
        if let username = userInfo.username {
            log("   Username: \(username)")
        }
        #endif
        
        // Cache für zukünftige Requests
        cachedUserId = userInfo.id
        
        return userInfo.id
    }
    
    /// Setzt die gecachte User-ID zurück (z.B. bei Logout)
    func clearUserIdCache() {
        cachedUserId = nil
    }
    
    // MARK: - Path Versioning
    
    private func versionedPath(_ path: String) -> String {
        guard apiVersion == .v3 else { return path }
        
        // Rating-Endpoints und /self müssen unverändert bleiben
        if path.contains("/ratings/") || path == "api/users/self" {
            return path
        }
        
        // Mealie v3.x: api/users -> api/admin/users
        if path.hasPrefix("api/users") {
            return path.replacingOccurrences(of: "api/users", with: "api/admin/users")
        }
        
        // Log bei Mealplan-Endpunkt für v3
        if path == "api/households/mealplans" {
            #if DEBUG
            log("🔧 API v3: Verwende Mealplan-Endpunkt mit Query-Parameter")
            #endif
        }
        
        return path
    }
    
    // MARK: - Request Creation
    
    func createRequest(path: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        guard let baseURL, let token else {
            throw APIError.missingConfiguration
        }

        let resolvedPath = versionedPath(path)
        let url = try buildURL(baseURL: baseURL, path: resolvedPath)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        // Optionale Header hinzufügen
        for (key, value) in optionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }
    
    /// Erstellt URL mit korrektem Query-Parameter-Handling
    private func buildURL(baseURL: URL, path: String) throws -> URL {
        // Trenne Path und Query-Parameter
        if let queryIndex = path.firstIndex(of: "?") {
            let basePath = String(path.prefix(upTo: queryIndex))
            let query = String(path.suffix(from: queryIndex))
            
            let url = baseURL.appendingPathComponent(basePath)
            
            guard let urlWithQuery = URL(string: url.absoluteString + query) else {
                throw APIError.invalidURL
            }
            
            return urlWithQuery
        } else {
            return baseURL.appendingPathComponent(path)
        }
    }
    // MARK: - Einkaufslisten

    func fetchShoppingListItems() async throws -> [ShoppingItem] {
        let request = try createRequest(path: "api/households/shopping/items")
        let (data, _) = try await URLSession.shared.data(for: request)
        struct Response: Decodable { let items: [ShoppingItem] }
        return try JSONDecoder().decode(Response.self, from: data).items
    }

    func addShoppingItem(note: String, labelId: String?) async throws -> ShoppingItem {
        struct Payload: Encodable {
            let note: String
            let shoppingListId: String
            let labelId: String?
        }

        let payload = Payload(
            note: note,
            shoppingListId: AppSettings.shared.shoppingListId,
            labelId: labelId
        )

        let body = try JSONEncoder().encode(payload)
        let request = try createRequest(path: "api/households/shopping/items", method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let msg = String(data: data, encoding: .utf8) ?? "Unbekannter Fehler"
            throw NSError(domain: "AddItem", code: status, userInfo: [
                NSLocalizedDescriptionKey: msg
            ])
        }


        return try JSONDecoder().decode(ShoppingItem.self, from: data)
    }

    func updateShoppingItem(_ item: ShoppingItem) async throws {
        struct Payload: Codable {
            let id: UUID
            let note: String
            let shoppingListId: String
            let checked: Bool
            let labelId: String?
            let quantity: Double?
        }

        let payload = Payload(
            id: item.id,
            note: item.note ?? "",
            shoppingListId: item.shoppingListId,
            checked: item.checked,
            labelId: item.label?.id,
            quantity: item.quantity ?? 1
        )

        let body = try JSONEncoder().encode(payload)
        let request = try createRequest(
            path: "api/households/shopping/items/\(item.id.uuidString)",
            method: "PUT",
            body: body
        )
        _ = try await URLSession.shared.data(for: request)
    }
    
    func updateShoppingItemCategory(itemId: UUID, labelId: String?) async throws {
        struct Payload: Encodable {
            let labelId: String?
        }

        let payload = Payload(labelId: labelId)
        let body = try JSONEncoder().encode(payload)
        let request = try createRequest(
            path: "api/households/shopping/items/\(itemId.uuidString)",
            method: "PATCH", // PATCH reicht!
            body: body
        )
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "UpdateCategory", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [
                NSLocalizedDescriptionKey: "Fehler beim Aktualisieren der Kategorie"
            ])
        }
    }


    func deleteShoppingItem(id: UUID) async throws {
        let request = try createRequest(path: "api/households/shopping/items/\(id.uuidString)", method: "DELETE")
        _ = try await URLSession.shared.data(for: request)
    }

    func deleteShoppingItems(_ items: [ShoppingItem]) async {
        for item in items where item.checked {
            do {
                try await deleteShoppingItem(id: item.id)
            } catch {
                log("❌ Fehler beim Löschen: \(error)")
            }
        }
    }

    func fetchShoppingLabels() async throws -> [ShoppingItem.LabelWrapper] {
        let request = try createRequest(path: "api/groups/labels")
        let (data, _) = try await URLSession.shared.data(for: request)

        struct LabelResponse: Decodable {
            let id: String
            let name: String
            let slug: String?
            let color: String?
        }

        struct PageResponse: Decodable {
            let items: [LabelResponse]
        }

        let result = try JSONDecoder().decode(PageResponse.self, from: data)
        return result.items.map {
            ShoppingItem.LabelWrapper(id: $0.id, name: $0.name, slug: $0.slug, color: $0.color)
        }
    }

    func fetchShoppingLists() async throws -> [ShoppingList] {
        let request = try createRequest(path: "api/households/shopping/lists")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ShoppingListResponse.self, from: data).items
    }
    
    func fetchMinimalShoppingLists() async throws -> [ShoppingList] {
        let request = try createRequest(path: "api/households/shopping/lists")
        let (data, _) = try await URLSession.shared.data(for: request)

        struct SlimList: Decodable {
            let id: String
            let name: String
        }

        struct SlimListResponse: Decodable {
            let items: [SlimList]
        }

        let slimLists = try JSONDecoder().decode(SlimListResponse.self, from: data).items
        return slimLists.map { ShoppingList(id: $0.id, name: $0.name) }
    }

    // Im APIService:
    func createTag(name: String) async throws -> RecipeTag {
        struct Payload: Encodable { let name: String }
        let payload = Payload(name: name)
        let body = try JSONEncoder().encode(payload)
        let request = try createRequest(path: "api/organizers/tags", method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "CreateTag", code: status, userInfo: [
                NSLocalizedDescriptionKey: "Fehler beim Anlegen eines Tags"
            ])
        }
        return try JSONDecoder().decode(RecipeTag.self, from: data)
    }

    func createCategory(name: String) async throws -> Category {
        struct Payload: Encodable { let name: String }
        let payload = Payload(name: name)
        let body = try JSONEncoder().encode(payload)
        let request = try createRequest(path: "api/organizers/categories", method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "CreateCategory", code: status, userInfo: [
                NSLocalizedDescriptionKey: "Fehler beim Anlegen einer Kategorie"
            ])
        }
        return try JSONDecoder().decode(Category.self, from: data)
    }

    // MARK: - Units & Foods
    
    struct UnitResponse: Codable {
        let id: String
        let name: String
        let description: String?
        let fraction: Bool?
        let abbreviation: String?
        let useAbbreviation: Bool?
    }
    
    struct FoodResponse: Codable {
        let id: String
        let name: String
        let description: String?
        let labelId: String?
    }
    
    func fetchAllUnits() async throws -> [UnitResponse] {
        let request = try createRequest(path: "api/units")
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct Response: Decodable {
            let items: [UnitResponse]
        }
        
        return try JSONDecoder().decode(Response.self, from: data).items
    }
    
    func fetchAllFoods() async throws -> [FoodResponse] {
        let request = try createRequest(path: "api/foods")
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct Response: Decodable {
            let items: [FoodResponse]
        }
        
        return try JSONDecoder().decode(Response.self, from: data).items
    }
    
    func findUnitID(name: String) async throws -> String? {
        let units = try await fetchAllUnits()
        return units.first(where: { 
            $0.name.lowercased() == name.lowercased() 
        })?.id
    }
    
    func findFoodID(name: String) async throws -> String? {
        let foods = try await fetchAllFoods()
        return foods.first(where: { 
            $0.name.lowercased() == name.lowercased() 
        })?.id
    }
    
    // MARK: - Create Unit
    
    /// Erstellt eine neue Unit in Mealie
    /// - Parameter name: Name der Unit (wird getrimmt)
    /// - Returns: Die neu erstellte Unit-Response mit ID
    func createUnit(name: String) async throws -> UnitResponse {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            throw NSError(domain: "CreateUnit", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Unit name cannot be empty"
            ])
        }
        
        struct CreateUnitRequest: Encodable {
            let name: String
            let description: String?
            let fraction: Bool
            let abbreviation: String?
            let useAbbreviation: Bool
        }
        
        let payload = CreateUnitRequest(
            name: trimmedName,
            description: nil,
            fraction: false,
            abbreviation: nil,
            useAbbreviation: false
        )
        
        let encoder = JSONEncoder()
        let body = try encoder.encode(payload)
        
        let request = try createRequest(path: "api/units", method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "CreateUnit", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Invalid response"
            ])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "CreateUnit", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create unit: HTTP \(httpResponse.statusCode)",
                "responseBody": errorBody
            ])
        }
        
        #if DEBUG
        print("✅ Unit created: '\(trimmedName)'")
        #endif
        
        return try JSONDecoder().decode(UnitResponse.self, from: data)
    }
    
    /// Sucht eine Unit oder erstellt sie automatisch wenn nicht vorhanden
    /// - Parameter name: Name der Unit
    /// - Returns: Die Unit ID (bestehend oder neu erstellt)
    func resolveOrCreateUnit(name: String) async throws -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            throw NSError(domain: "ResolveUnit", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Unit name cannot be empty"
            ])
        }
        
        // 1. Versuche existierende Unit zu finden
        if let existingID = try await findUnitID(name: trimmedName) {
            #if DEBUG
            print("✅ Unit found: '\(trimmedName)' → ID: \(existingID)")
            #endif
            return existingID
        }
        
        // 2. Wenn nicht gefunden, erstelle neue Unit
        #if DEBUG
        print("🆕 Creating new unit: '\(trimmedName)'")
        #endif
        
        let newUnit = try await createUnit(name: trimmedName)
        
        #if DEBUG
        print("✅ Unit created: '\(trimmedName)' → ID: \(newUnit.id)")
        #endif
        
        return newUnit.id
    }
    
    // MARK: - Create Food
    
    /// Erstellt eine neue Food-Zutat in Mealie
    /// - Parameter name: Name der Zutat (wird getrimmt)
    /// - Returns: Die neu erstellte Food-Response mit ID
    func createFood(name: String) async throws -> FoodResponse {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            throw NSError(domain: "CreateFood", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Food name cannot be empty"
            ])
        }
        
        struct CreateFoodRequest: Encodable {
            let name: String
            let description: String?
        }
        
        let payload = CreateFoodRequest(name: trimmedName, description: nil)
        let encoder = JSONEncoder()
        let body = try encoder.encode(payload)
        
        let request = try createRequest(path: "api/foods", method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "CreateFood", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Invalid response"
            ])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "CreateFood", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create food: HTTP \(httpResponse.statusCode)",
                "responseBody": errorBody
            ])
        }
        
        #if DEBUG
        print("✅ Food created: '\(trimmedName)'")
        #endif
        
        return try JSONDecoder().decode(FoodResponse.self, from: data)
    }
    
    /// Sucht eine Food-Zutat oder erstellt sie automatisch wenn nicht vorhanden
    /// - Parameter name: Name der Zutat
    /// - Returns: Die Food ID (bestehend oder neu erstellt)
    func resolveOrCreateFood(name: String) async throws -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            throw NSError(domain: "ResolveFood", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Food name cannot be empty"
            ])
        }
        
        // 1. Versuche existierende Food zu finden
        if let existingID = try await findFoodID(name: trimmedName) {
            #if DEBUG
            print("✅ Food found: '\(trimmedName)' → ID: \(existingID)")
            #endif
            return existingID
        }
        
        // 2. Wenn nicht gefunden, erstelle neue Food
        #if DEBUG
        print("🆕 Creating new food: '\(trimmedName)'")
        #endif
        
        let newFood = try await createFood(name: trimmedName)
        
        #if DEBUG
        print("✅ Food created: '\(trimmedName)' → ID: \(newFood.id)")
        #endif
        
        return newFood.id
    }

    // MARK: - Rezepte

    func fetchRecipes() async throws -> [RecipeSummary] {
        let request = try createRequest(path: "api/recipes")
        let (data, _) = try await URLSession.shared.data(for: request)
        struct Response: Decodable { let items: [RecipeSummary] }
        return try JSONDecoder().decode(Response.self, from: data).items
    }

    func fetchRecipeDetail(id: String) async throws -> RecipeDetail {
        let request = try createRequest(path: "api/recipes/\(id)")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(RecipeDetail.self, from: data)
    }
    
        func fetchAllRecipes() async throws -> [RecipeSummary] {
            var allRecipes: [RecipeSummary] = []
            var page = 1
            let perPage = 50

            while true {
                let path = "api/recipes?page=\(page)&perPage=\(perPage)"
                let request = try createRequest(path: path)
                let (data, response) = try await URLSession.shared.data(for: request)
                
                #if DEBUG
                if page == 1, let jsonString = String(data: data, encoding: .utf8) {
                    // Zeige nur die ersten 1000 Zeichen des ersten Rezepts
                    let preview = String(jsonString.prefix(1000))
                    log("📦 API Response (erste 1000 Zeichen):\n\(preview)")
                }
                #endif

                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    let msg = String(data: data, encoding: .utf8) ?? "Unbekannter Fehler"
                    log("❌ Fehler-Response (\(http.statusCode)) auf Seite \(page): \(msg)")
                    throw NSError(domain: "fetchAllRecipes", code: http.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: msg
                    ])
                }

                struct Response: Decodable {
                    let items: [RecipeSummary]
                    let total_pages: Int?
                    let page: Int?
                }
                let result = try JSONDecoder().decode(Response.self, from: data)
                allRecipes.append(contentsOf: result.items)

                // ➤ Pause nach jeder 3. Seite (z. B. nach je 150 Rezepten kurz warten)
                if page % 3 == 0 {
                    log("⏳ Warte 1 Sekunde zur Entlastung der API …")
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 Sekunde
                }

                if let totalPages = result.total_pages, let currentPage = result.page, currentPage >= totalPages {
                    break
                }
                if result.items.count < perPage { break }
                page += 1
            }
            return allRecipes
        }



    func fetchAllRecipeDetails() async throws -> [RecipeDetail] {
        let summaries = try await fetchRecipes()
        return try await withThrowingTaskGroup(of: RecipeDetail.self) { group in
            for summary in summaries {
                group.addTask {
                    return try await self.fetchRecipeDetail(id: summary.id)
                }
            }

            var results: [RecipeDetail] = []
            for try await detail in group {
                results.append(detail)
            }
            return results
        }
    }
    
    func updateFullRecipe(originalSlug: String, payload: RecipeUpdatePayload) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let body = try encoder.encode(payload)

        #if DEBUG
        // 📝 Log die tatsächliche JSON Payload
        if let jsonString = String(data: body, encoding: .utf8) {
            log("📦 PATCH Payload JSON:\n\(jsonString)")
        }
        #endif

        let request = try createRequest(
            path: "api/recipes/\(originalSlug)",
            method: "PATCH",
            body: body
        )
        
        log("🔁 PATCH Request Details:")
        log("   URL: \(request.url?.absoluteString ?? "nil")")
        log("   Method: \(request.httpMethod ?? "nil")")
        log("   Content-Type: \(request.value(forHTTPHeaderField: "Content-Type") ?? "nil")")
        log("   Accept: \(request.value(forHTTPHeaderField: "Accept") ?? "nil")")
        log("   Payload Size: \(body.count) bytes")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let http = response as? HTTPURLResponse else {
                throw NSError(domain: "UpdateRecipe", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Keine HTTP Response erhalten"
                ])
            }
            
            // ✅ VOLLSTÄNDIGES Response Logging
            let responseBody = String(data: data, encoding: .utf8) ?? "<no body>"
            
            log("📥 HTTP Response:")
            log("   Status Code: \(http.statusCode)")
            log("   Response Size: \(data.count) bytes")
            log("   Content-Type: \(http.value(forHTTPHeaderField: "Content-Type") ?? "nil")")
            
            if !(200...299).contains(http.statusCode) {
                // ❌ Fehlerfall: Response Body ausgeben
                log("❌ API Fehler - Vollständiger Response Body:")
                log(responseBody)
                
                // Parse Mealie API Error Format
                if let errorData = data.isEmpty ? nil : data,
                   let errorJson = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any] {
                    if let detail = errorJson["detail"] {
                        log("   Error Detail: \(detail)")
                    }
                }
                
                throw NSError(domain: "UpdateRecipe", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "API Fehler \(http.statusCode): \(responseBody)",
                    "responseBody": responseBody,
                    "statusCode": http.statusCode
                ])
            }
            
            // ✅ Erfolgsfall: Response Body ebenfalls ausgeben für Debugging
            log("✅ Rezept erfolgreich aktualisiert")
            #if DEBUG
            if !responseBody.isEmpty && responseBody != "<no body>" {
                log("   Response Body (first 500 chars): \(String(responseBody.prefix(500)))")
            }
            #endif
            
        } catch let urlError as URLError {
            log("❌ Network Error:")
            log("   Code: \(urlError.code.rawValue)")
            log("   Description: \(urlError.localizedDescription)")
            throw urlError
        } catch let nsError as NSError {
            log("❌ Error: \(nsError.localizedDescription)")
            if let responseBody = nsError.userInfo["responseBody"] as? String {
                log("   Response: \(responseBody)")
            }
            throw nsError
        }
    }



    func deleteRecipe(recipeId: UUID) async throws {
        let request = try createRequest(path: "api/recipes/\(recipeId.uuidString)", method: "DELETE")
        _ = try await URLSession.shared.data(for: request)
    }
    
    func fetchCategories() async throws -> [Category] {
        let request = try createRequest(path: "api/organizers/categories")
        let (data, _) = try await URLSession.shared.data(for: request)
        struct Page: Decodable {
            let items: [Category]
        }
        return try JSONDecoder().decode(Page.self, from: data).items
    }

    func fetchTags() async throws -> [RecipeTag] {
        let request = try createRequest(path: "api/organizers/tags")
        let (data, _) = try await URLSession.shared.data(for: request)
        struct Page: Decodable {
            let items: [RecipeTag]
        }
        return try JSONDecoder().decode(Page.self, from: data).items
    }


    // MARK: - Upload: JSON, URL, Bild

    func uploadRecipeJSON(_ json: String) async throws {
        let escaped = json.replacingOccurrences(of: "\"", with: "\\\"")
        let payload = "{ \"data\": \"\(escaped)\" }"

        guard let body = payload.data(using: .utf8) else {
            throw NSError(domain: "Upload", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Encoding fehlgeschlagen."
            ])
        }

        let request = try createRequest(path: "api/recipes/create/html-or-json", method: "POST", body: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func uploadRecipeFromURL(url: String) async throws -> String {
        let body = try JSONEncoder().encode(["url": url])
        let request = try createRequest(path: "api/recipes/create/url", method: "POST", body: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\""))) ?? ""
    }

    func uploadRecipeImage(_ image: UIImage, translateLanguage: String? = nil) async throws -> String {
        guard let baseURL, let token else { throw URLError(.badURL) }

        // ✅ KORREKTER Endpoint: /api/recipes/create/image (unterstützt OpenAI)
        let url = baseURL.appendingPathComponent("api/recipes/create/image")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        
        // ✅ Verwende die vom User gewählte Sprache oder die System-Sprache als Fallback
        let effectiveLanguage = translateLanguage ?? determinePreferredLanguage()
        components.queryItems = [URLQueryItem(name: "translateLanguage", value: effectiveLanguage)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120 // OpenAI-Analyse kann länger dauern

        let boundary = UUID().uuidString
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        for (key, value) in optionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "Upload", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Bild konnte nicht konvertiert werden."
            ])
        }
        
        log("ℹ️ Upload-Bildgröße: \(ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file))")

        var body = Data()
        body.append("--\(boundary)\r\n")
        // ⚠️ WICHTIG: Feld heißt "images" (Plural), wie in der Mealie API-Doku!
        body.append("Content-Disposition: form-data; name=\"images\"; filename=\"image.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")

        request.httpBody = body
        
        log("🌐 Upload URL: \(components.url?.absoluteString ?? "nil")")

        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        log("📡 HTTP Status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unbekannter Fehler"
            log("❌ Upload-Fehler: \(errorMsg)")
            
            if httpResponse.statusCode == 500 {
                log("⚠️ Server-Fehler. Mögliche Ursachen:")
                log("   - OpenAI API Key fehlt in Mealie")
                log("   - OpenAI API Quota überschritten")
            }
            
            throw NSError(domain: "Upload", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: errorMsg
            ])
        }
        
        log("✅ Upload erfolgreich!")
        log("🎉 ALLES GEKLAPPT! Rezept wurde mit OpenAI erstellt.")
        log("📝 Response: \(String(data: data, encoding: .utf8)?.prefix(200) ?? "keine Daten")")
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\""))) ?? ""
    }
    

    func uploadRecipeImageForExistingRecipe(slug: String, image: UIImage) async throws {
        guard let baseURL, let token else { throw URLError(.badURL) }
        
        let url = baseURL.appendingPathComponent("api/recipes/\(slug)/image")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        
        let boundary = UUID().uuidString
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "Upload", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Bild konnte nicht konvertiert werden."
            ])
        }
        
        var body = Data()
        // --- Bild
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n")
        
        // --- Extension
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"extension\"\r\n\r\n")
        body.append("jpg") // oder "png", je nach Bildtyp!
        body.append("\r\n")
        
        body.append("--\(boundary)--\r\n")
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unbekannter Fehler"
            throw NSError(domain: "UploadImage", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [
                NSLocalizedDescriptionKey: msg
            ])
        }
    }

    // MARK: - Mealplan

    func fetchMealplanEntries() async throws -> [MealplanEntry] {
        log("📥 API: fetchMealplanEntries aufgerufen")
        
        let request = try createRequest(path: "api/households/mealplans")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // HTTP Status überprüfen
        if let httpResponse = response as? HTTPURLResponse {
            log("   ✅ Status Code: \(httpResponse.statusCode)")
        }
        
        // Raw JSON ausgeben für Debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            log("   📦 Raw JSON Response:")
            log(jsonString)
        }
        
        struct Response: Decodable { let items: [MealplanEntry] }
        
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(Response.self, from: data)
            log("   ✅ Erfolgreich \(response.items.count) Einträge dekodiert")
            
            // Details zu jedem Eintrag ausgeben
            for entry in response.items {
                log("   📌 Entry ID: \(entry.id)")
                log("      Datum: \(entry.date)")
                log("      Typ: \(entry.entryType)")
                log("      Recipe: \(entry.recipe?.name ?? "nil")")
                log("      Title: \(entry.title ?? "nil")")
            }
            
            return response.items
        } catch {
            log("   ❌ Fehler beim Dekodieren: \(error)")
            if let decodingError = error as? DecodingError {
                log("   🔍 Decoding Error Details: \(decodingError)")
            }
            throw error
        }
    }

    func addMealEntry(date: Date, slot: String, recipeId: String?, note: String?) async throws {
        // ✅ Verwende lokale Zeitzone und normalisiere auf Mitternacht
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = TimeZone.current  // ✅ Explizite Zeitzone setzen

        struct Payload: Codable {
            let date: String
            let entryType: String
            let recipeId: String?
            let title: String?
        }

        let payload = Payload(
            date: formatter.string(from: normalizedDate),
            entryType: slot,
            recipeId: recipeId,
            title: recipeId == nil ? note : nil
        )

        // 📝 Debug-Logging
        log("📤 API: addMealEntry aufgerufen")
        log("   📅 Datum: \(formatter.string(from: date))")
        log("   🍽 Slot: \(slot)")
        log("   🆔 RecipeId: \(recipeId ?? "nil")")
        log("   📝 Note/Title: \(note ?? "nil")")
        
        let body = try JSONEncoder().encode(payload)
        
        // Payload als JSON ausgeben
        if let jsonString = String(data: body, encoding: .utf8) {
            log("   📦 Payload JSON: \(jsonString)")
        }
        
        let request = try createRequest(path: "api/households/mealplans", method: "POST", body: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                log("   ✅ Status Code: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
                    log("   📥 Response: \(responseString)")
                }
            }
        } catch {
            log("   ❌ Fehler bei addMealEntry: \(error.localizedDescription)")
            throw error
        }
    }

    func deleteMealEntry(_ entryId: Int) async throws {
        let request = try createRequest(path: "api/households/mealplans/\(entryId)", method: "DELETE")
        _ = try await URLSession.shared.data(for: request)
    }
    
    // MARK: - Rating API
    
    /// Setzt oder aktualisiert die Bewertung für ein Rezept
    /// - Parameters:
    ///   - recipeId: Die UUID des Rezepts
    ///   - slug: Der Slug des Rezepts (für URL)
    ///   - rating: Die Bewertung (1-5 Sterne)
    ///   - userId: Die Benutzer-ID (Standard: aktueller User vom Server)
    func setRecipeRating(recipeId: String, slug: String, rating: Double, userId: String? = nil) async throws {
        guard rating >= 1.0 && rating <= 5.0 else {
            throw NSError(domain: "API", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Ungültiges Rating: \(rating). Erlaubt sind Werte zwischen 1.0 und 5.0."
            ])
        }
        
        // ✅ Ermittle User-ID vom Server falls nicht angegeben
        let effectiveUserId: String
        if let userId = userId {
            effectiveUserId = userId
        } else {
            effectiveUserId = try await getCurrentUserId()
        }
        
        #if DEBUG
        log("⭐ Setze Rating für Rezept '\(slug)': \(rating) Sterne")
        log("   User-ID: \(effectiveUserId)")
        log("   API Version: \(apiVersion.rawValue)")
        #endif
        
        // ✅ Mealie v3.x: POST /api/users/{user_id}/ratings/{slug}
        // Body: {"rating": Int}
        let path = "api/users/\(effectiveUserId)/ratings/\(slug)"
        
        struct RatingPayload: Codable {
            let rating: Int
        }
        
        let payload = RatingPayload(rating: Int(rating))
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let body = try encoder.encode(payload)
        
        #if DEBUG
        if let jsonString = String(data: body, encoding: .utf8) {
            log("   📦 Payload:\n\(jsonString)")
        }
        #endif
        
        let request = try createRequest(path: path, method: "POST", body: body)
        
        #if DEBUG
        log("   🌐 URL: \(request.url?.absoluteString ?? "nil")")
        #endif
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            #if DEBUG
            log("   📡 Status Code: \(httpResponse.statusCode)")
            #endif
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                #if DEBUG
                log("✅ Rating erfolgreich gesetzt")
                #endif
            } else {
                let errorBody = String(data: data, encoding: .utf8) ?? ""
                #if DEBUG
                log("❌ Rating-Fehler (\(httpResponse.statusCode)): \(errorBody)")
                #endif
                throw NSError(domain: "API", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Rating konnte nicht gesetzt werden (HTTP \(httpResponse.statusCode))",
                    "responseBody": errorBody
                ])
            }
        }
    }
    
    /// Löscht die Bewertung für ein Rezept
    /// - Parameters:
    ///   - slug: Der Slug des Rezepts (für URL)
    ///   - userId: Die Benutzer-ID (Standard: aktueller User vom Server)
    func deleteRecipeRating(slug: String, userId: String? = nil) async throws {
        // ✅ Ermittle User-ID vom Server falls nicht angegeben
        let effectiveUserId: String
        if let userId = userId {
            effectiveUserId = userId
        } else {
            effectiveUserId = try await getCurrentUserId()
        }
        
        #if DEBUG
        log("🗑️ Lösche Rating für Rezept '\(slug)'")
        log("   User-ID: \(effectiveUserId)")
        log("   API Version: \(apiVersion.rawValue)")
        #endif
        
        // ✅ Mealie v3.x: DELETE /api/users/{user_id}/ratings/{slug}
        let path = "api/users/\(effectiveUserId)/ratings/\(slug)"
        let request = try createRequest(path: path, method: "DELETE")
        
        #if DEBUG
        log("   🌐 URL: \(request.url?.absoluteString ?? "nil")")
        #endif
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            #if DEBUG
            log("   📡 Status Code: \(httpResponse.statusCode)")
            #endif
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                #if DEBUG
                log("✅ Rating erfolgreich gelöscht")
                #endif
            } else {
                let errorBody = String(data: data, encoding: .utf8) ?? ""
                #if DEBUG
                log("❌ Rating-Lösch-Fehler (\(httpResponse.statusCode)): \(errorBody)")
                #endif
                throw NSError(domain: "API", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Rating konnte nicht gelöscht werden (HTTP \(httpResponse.statusCode))",
                    "responseBody": errorBody
                ])
            }
        }
    }
}

// MARK: - Multipart-Erweiterung

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

