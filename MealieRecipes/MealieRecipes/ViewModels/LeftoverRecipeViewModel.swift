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
class LeftoverRecipeViewModel: ObservableObject {
    @Published var allRecipes: [RecipeDetail] = []
    @Published var isLoading: Bool = false
    @Published var loadProgress: Double = 0
    @Published var error: Error?
    @Published var ingredientTrigger = UUID()

    let inputModel: IngredientInputModel
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared

    init(inputModel: IngredientInputModel = IngredientInputModel()) {
        self.inputModel = inputModel

        // Reaktives Triggern bei Eingabeänderung
        inputModel.$enteredIngredients
            .sink { [weak self] _ in
                self?.ingredientTrigger = UUID()
            }
            .store(in: &cancellables)
    }

    var filteredRecipes: [RecipeDetail] {
        let names = inputModel.enteredIngredients.map { $0.name }
        guard !names.isEmpty else { return [] }

        return allRecipes
            .filter { $0.hasAllMatchingIngredients(names) }
            .sorted {
                $0.matchingIngredientPercentage(haveIngredients: names) >
                $1.matchingIngredientPercentage(haveIngredients: names)
            }
    }

    func loadCachedOrFetchRecipes() {
        let cached = RecipeCacheManager.shared.load()
        if !cached.isEmpty {
            self.allRecipes = cached
            logMessage("✅ Aus Cache geladen: \(cached.count) Rezepte")
        } else {
            Task {
                await loadRecipesIncrementally(batchSize: 10)
            }
        }
    }

    /// Holt alle Rezept-Summaries und lädt dann Details batched (mit kurzen Pausen)
    func loadRecipesIncrementally(batchSize: Int = 10) async {
        isLoading = true
        error = nil

        do {
            let summaries = try await apiService.fetchAllRecipes()
            let total = summaries.count
            var loaded: [RecipeDetail] = []

            logMessage("➡️ Starte Ladevorgang: \(total) Rezepte insgesamt")

            for batchStart in stride(from: 0, to: total, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, total)
                let batch = summaries[batchStart..<batchEnd]

                // Details für diesen Batch laden
                for (index, summary) in batch.enumerated() {
                    do {
                        let detail = try await apiService.fetchRecipeDetail(id: summary.id)
                        loaded.append(detail)
                        logMessage("   ✔️ Detail geladen (\(batchStart + index + 1)/\(total)): \(detail.name)")
                    } catch {
                        logMessage("   ⚠️ Fehler bei Detail \(summary.id): \(error)")
                    }

                    let progress = Double(batchStart + index + 1) / Double(total)
                    self.loadProgress = progress
                    self.allRecipes = loaded
                }

                // Kurze Pause nach jedem Batch
                if batchEnd < total {
                    logMessage("⏸️  Kurze Pause nach Batch (\(batchEnd)/\(total))")
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 Sekunden
                }
            }

            // Am Ende: ALLE geladenen Rezepte speichern
            RecipeCacheManager.shared.save(recipes: loaded)
            logMessage("✅ Alle geladen & gecached: \(loaded.count) Rezepte")
        } catch {
            self.error = error
            logMessage("❌ Fehler beim Laden der Summaries: \(error)")
        }

        isLoading = false
    }

    func refreshRecipes() {
        RecipeCacheManager.shared.clear()
        Task {
            await loadRecipesIncrementally(batchSize: 10)
        }
    }

    func percentageText(for recipe: RecipeDetail) -> String {
        let names = inputModel.enteredIngredients.map { $0.name }
        let matchCount = recipe.matchingIngredientCount(haveIngredients: names)
        let total = recipe.ingredients.count
        let percent = Int(recipe.matchingIngredientPercentage(haveIngredients: names))

        return "\(percent)% passend (\(matchCount)/\(total))"
    }
}
