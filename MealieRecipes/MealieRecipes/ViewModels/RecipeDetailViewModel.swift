import Foundation

// 🔧 Lokale Logging-Hilfe (falls globale nicht gefunden wird)
private func logMessage(_ message: String) {
    Swift.print(message)
    
    if AppSettings.shared.enableLogging {
        LogManager.shared.logPrint(message)
    }
}

private func logMessage(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let output = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(output, terminator: terminator)
    
    if AppSettings.shared.enableLogging {
        LogManager.shared.logPrint(output)
    }
}

@MainActor
class RecipeDetailViewModel: ObservableObject {
    @Published var recipe: RecipeDetail?
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private let apiService = APIService.shared

    func fetchRecipe(by id: String) async {
        isLoading = true
        error = nil

        do {
            let fetched = try await apiService.fetchRecipeDetail(id: id)
            self.recipe = fetched

            // 🔥 Debug: Logge Ingredient-Status
            #if DEBUG
            logMessage("📊 Ingredient Debug für '\(fetched.name)':")
            logMessage("   Total: \(fetched.ingredients.count)")
            let withNotes = fetched.ingredients.filter { $0.hasNote }
            logMessage("   Mit note: \(withNotes.count)")
            
            if !withNotes.isEmpty {
                logMessage("   Ingredients mit Notes:")
                for ing in withNotes {
                    logMessage("      - \(ing.food ?? "nil") → Note: \(ing.note ?? "nil")")
                }
            }
            
            let withoutData = fetched.ingredients.filter { 
                $0.quantity == nil && ($0.unit == nil || $0.unit!.isEmpty) 
            }
            if !withoutData.isEmpty {
                logMessage("   ⚠️ \(withoutData.count) Ingredients ohne strukturierte Daten")
            }
            #endif
           
            var cache = RecipeCacheManager.shared.load()
            cache.removeAll { $0.id == fetched.id }
            cache.append(fetched)
            RecipeCacheManager.shared.save(recipes: cache)

            logMessage("✅ [ViewModel] Rezept aus API geladen und gespeichert: \(fetched.name)")
            logMessage("prepTime:", fetched.prepTime as Any)
            logMessage("totalTime:", fetched.totalTime as Any)
        } catch {
            logMessage("⚠️ [ViewModel] API fehlgeschlagen, versuche Cache...")

            // 🔁 Cache-Fallback
            let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let cached = RecipeCacheManager.shared
                .load()
                .first(where: { $0.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedID }) {
                self.recipe = cached
                logMessage("📦 [ViewModel] Rezept aus Cache geladen: \(cached.name)")
            } else {
                logMessage("❌ [ViewModel] Kein passender Cache-Eintrag für ID: \(id)")
                self.error = URLError(.fileDoesNotExist)
            }
        }

        isLoading = false
    }

    @Published var allTags: [RecipeTag] = []
    @Published var allCategories: [Category] = []

    func fetchTags() async {
        do {
            let tags = try await APIService.shared.fetchTags()
            self.allTags = tags
        } catch {
            logMessage("Fehler beim Laden der Tags: \(error)")
        }
    }
    func fetchCategories() async {
        do {
            let cats = try await APIService.shared.fetchCategories()
            self.allCategories = cats
        } catch {
            logMessage("Fehler beim Laden der Kategorien: \(error)")
        }
    }

    
}
