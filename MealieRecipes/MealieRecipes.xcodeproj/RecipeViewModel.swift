import Foundation
import Combine

// MARK: - Recipe ViewModel

@MainActor
class RecipeViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var recipe: Recipe?
    @Published private(set) var ingredients: [Ingredient] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: MealieError?
    
    // MARK: - Dependencies
    
    private let apiClient: MealieAPIClient
    private var cancellables = Set<AnyCancellable>()
    
    init(apiClient: MealieAPIClient = .shared) {
        self.apiClient = apiClient
    }
    
    // MARK: - Public Methods
    
    func loadRecipe(id: String) async {
        isLoading = true
        error = nil
        
        do {
            let dto = try await apiClient.fetchRecipe(id: id)
            
            // Debug: Logge fehlende Notes
            dto.allIngredients.logMissingNotes()
            
            // Convert to domain model
            let recipe = Recipe.from(dto: dto)
            
            // 🔥 Wichtig: Update auf Main Thread
            self.recipe = recipe
            self.ingredients = recipe.ingredients
            
            // Debug-Ausgabe
            print("✅ Loaded recipe: \(recipe.name)")
            print("   Ingredients: \(ingredients.count)")
            print("   With notes: \(ingredients.filter { $0.hasNote }.count)")
            
        } catch {
            self.error = .networkError(error)
            print("❌ Failed to load recipe: \(error)")
        }
        
        isLoading = false
    }
    
    /// Lädt nur Ingredients neu (für partielle Updates)
    func refreshIngredients() async {
        guard let recipeId = recipe?.id else { return }
        await loadRecipe(id: recipeId)
    }
}

// MARK: - API Client

class MealieAPIClient {
    static let shared = MealieAPIClient()
    
    private let baseURL: URL
    private let session: URLSession
    
    init(
        baseURL: URL = URL(string: "https://your-mealie-instance.com")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }
    
    func fetchRecipe(id: String) async throws -> MealieRecipeDTO {
        let url = baseURL.appendingPathComponent("api/recipes/\(id)")
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Authentifizierung (anpassen!)
        if let token = UserDefaults.standard.string(forKey: "mealie_token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        // Debug: Raw Response loggen
        #if DEBUG
        MealieAPIDebugger.logRawResponse(data, endpoint: "recipes/\(id)")
        #endif
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MealieError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw MealieError.httpError(httpResponse.statusCode)
        }
        
        // Decoding mit Error-Handling
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys // Wir nutzen custom CodingKeys
            
            let dto = try decoder.decode(MealieRecipeDTO.self, from: data)
            return dto
            
        } catch let decodingError as DecodingError {
            print("❌ Decoding Error:")
            MealieAPIDebugger.printDecodingError(decodingError)
            throw MealieError.decodingError(decodingError)
        }
    }
}

// MARK: - Error Types

enum MealieError: LocalizedError {
    case networkError(Error)
    case invalidResponse
    case httpError(Int)
    case decodingError(DecodingError)
    case noData
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Netzwerkfehler: \(error.localizedDescription)"
        case .invalidResponse:
            return "Ungültige Serverantwort"
        case .httpError(let code):
            return "HTTP Fehler: \(code)"
        case .decodingError(let error):
            return "Daten konnten nicht verarbeitet werden: \(error.localizedDescription)"
        case .noData:
            return "Keine Daten erhalten"
        }
    }
}

// MARK: - Persistence Layer (Optional)

actor RecipeCache {
    private var cache: [String: Recipe] = [:]
    private let maxCacheSize = 50
    
    func get(_ id: String) -> Recipe? {
        cache[id]
    }
    
    func set(_ recipe: Recipe) {
        // LRU eviction (vereinfacht)
        if cache.count >= maxCacheSize {
            cache.removeValue(forKey: cache.keys.first!)
        }
        cache[recipe.id] = recipe
    }
    
    func clear() {
        cache.removeAll()
    }
}

// MARK: - ViewModel mit Caching

@MainActor
class CachedRecipeViewModel: ObservableObject {
    @Published private(set) var recipe: Recipe?
    @Published private(set) var isLoading = false
    @Published private(set) var error: MealieError?
    
    private let apiClient: MealieAPIClient
    private let cache = RecipeCache()
    
    init(apiClient: MealieAPIClient = .shared) {
        self.apiClient = apiClient
    }
    
    func loadRecipe(id: String, forceRefresh: Bool = false) async {
        // Zeige gecachtes Recipe sofort
        if !forceRefresh, let cached = await cache.get(id) {
            self.recipe = cached
            print("📦 Loaded from cache: \(cached.name)")
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let dto = try await apiClient.fetchRecipe(id: id)
            let recipe = Recipe.from(dto: dto)
            
            // Cache & publish
            await cache.set(recipe)
            self.recipe = recipe
            
        } catch {
            self.error = .networkError(error)
        }
        
        isLoading = false
    }
}
