import Foundation
import Combine

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
class RecipeListViewModel: ObservableObject {
    @Published var allRecipes: [RecipeDetail] = []
    @Published var isLoading: Bool = false
    @Published var loadProgress: Double = 0
    @Published var errorMessage: String? = nil
    
    @Published var categories: [Category] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    func loadCachedOrFetchRecipes(batchSize: Int = 10) {
        let cached = RecipeCacheManager.shared.load()
        if !cached.isEmpty {
            self.allRecipes = cached
            logMessage("✅ Aus Cache geladen: \(cached.count) Rezepte")
        } else {
            Task {
                await loadRecipesIncrementally(batchSize: batchSize)
            }
        }
    }
    
    func loadRecipesIncrementally(batchSize: Int = 10) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let summaries = try await apiService.fetchAllRecipes()
            let total = summaries.count
            var loaded: [RecipeDetail] = []
            
            logMessage("➡️ Starte Ladevorgang: \(total) Rezepte insgesamt")
            
            for batchStart in stride(from: 0, to: total, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, total)
                let batch = summaries[batchStart..<batchEnd]
                
                for (index, summary) in batch.enumerated() {
                    do {
                        var detail = try await apiService.fetchRecipeDetail(id: summary.id)
                        
                        // 📅 Übertrage Datums-Felder von Summary zu Detail
                        // (falls Detail keine hat, nutze die aus Summary)
                        if detail.dateAdded == nil { detail.dateAdded = summary.dateAdded }
                        if detail.dateUpdated == nil { detail.dateUpdated = summary.dateUpdated }
                        if detail.createdAt == nil { detail.createdAt = summary.createdAt }
                        if detail.updatedAt == nil { detail.updatedAt = summary.updatedAt }
                        
                        // Debug-Logging für Datums-Felder
                        if AppSettings.shared.enableLogging {
                            let df = DateFormatter()
                            df.dateStyle = .short
                            df.timeStyle = .short
                            
                            logMessage("   📅 Datums-Felder für '\(detail.name)':")
                            logMessage("      dateAdded: \(detail.dateAdded.map { df.string(from: $0) } ?? "nil")")
                            logMessage("      dateUpdated: \(detail.dateUpdated.map { df.string(from: $0) } ?? "nil")")
                            logMessage("      createdAt: \(detail.createdAt.map { df.string(from: $0) } ?? "nil")")
                            logMessage("      updatedAt: \(detail.updatedAt.map { df.string(from: $0) } ?? "nil")")
                        }
                        
                        loaded.append(detail)
                        logMessage("   ✔️ Detail geladen (\(batchStart + index + 1)/\(total)): \(detail.name)")
                    } catch {
                        logMessage("   ⚠️ Fehler bei Detail \(summary.id): \(error)")
                    }
                    let progress = Double(batchStart + index + 1) / Double(total)
                    self.loadProgress = progress
                    self.allRecipes = loaded
                }
                
                if batchEnd < total {
                    logMessage("⏸️  Kurze Pause nach Batch (\(batchEnd)/\(total))")
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 Sekunden Pause
                }
            }
            
            RecipeCacheManager.shared.save(recipes: loaded)
            logMessage("✅ Alle geladen & gecached: \(loaded.count) Rezepte")
        } catch {
            self.errorMessage = "Fehler beim Laden der Rezepte: \(error.localizedDescription)"
            logMessage("❌ Fehler beim Laden der Summaries: \(error)")
        }
        
        isLoading = false
    }
    
    func fetchCategories() {
        Task {
            do {
                let fetched = try await apiService.fetchCategories()
                self.categories = fetched
            } catch {
                logMessage("❌ Fehler beim Laden der Kategorien: \(error)")
            }
        }
    }
    
    func clearCacheAndReload() {
        RecipeCacheManager.shared.clear()
        allRecipes = []
        loadCachedOrFetchRecipes(batchSize: 10)
    }
    
    func refreshRecipes(batchSize: Int = 10) {
        RecipeCacheManager.shared.clear()
        allRecipes = []
        loadCachedOrFetchRecipes(batchSize: batchSize)
    }
    
    private func cacheAllRecipeDetails() async throws {
        let summaries = self.allRecipes
        var details: [RecipeDetail] = []

        for summary in summaries {
            do {
                let detail = try await apiService.fetchRecipeDetail(id: summary.id)
                details.append(detail)
            } catch {
                logMessage("Fehler beim Caching von Rezept \(summary.name): \(error.localizedDescription)")
            }
        }

        RecipeCacheManager.shared.save(recipes: details)
    }
}
