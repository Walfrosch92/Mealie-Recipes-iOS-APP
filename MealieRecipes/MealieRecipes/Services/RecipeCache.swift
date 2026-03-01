//
//  RecipeCache.swift
//  MealieRecipes
//
//  Created by Michael Haiszan on 19.05.25.
//

import Foundation

// Füge diese Hilfsfunktion hier hinzu
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

struct RecipeCache: Codable {
    let recipes: [RecipeDetail]
}

class RecipeCacheManager {
    static let shared = RecipeCacheManager()
    private init() {}

    private let cacheFileName = "recipeCache.json"

    private var cacheFolderURL: URL {
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MealieCache", isDirectory: true)

        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )
        }

        return folder
    }

    private var cacheURL: URL {
        cacheFolderURL.appendingPathComponent("recipeCache.json")
    }

    func save(recipes: [RecipeDetail]) {
        let cache = RecipeCache(recipes: recipes)
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: cacheURL)
            logMessage("💾 Rezepte gecached: \(recipes.count)")
        } catch {
            logMessage("❌ Fehler beim Cachen: \(error)")
        }
    }
    
    func loadSummaries() -> [RecipeSummary] {
        load().compactMap { detail in
            // Prüfe, ob die ID gültig ist
            guard UUID(uuidString: detail.id) != nil else {
                return nil
            }
            
            // Erstelle RecipeSummary mit dem memberwise Initializer
            return RecipeSummary(
                id: detail.id,
                name: detail.name,
                description: detail.description,
                tags: detail.tags,
                recipeCategory: detail.recipeCategory,
                dateAdded: detail.dateAdded,
                dateUpdated: detail.dateUpdated,
                createdAt: detail.createdAt,
                updatedAt: detail.updatedAt,
                lastMade: nil,  // lastMade ist nur in RecipeSummary verfügbar
                rating: detail.rating  // ⭐ Rating aus RecipeDetail übernehmen
            )
        }
    }

    func load() -> [RecipeDetail] {
        do {
            let data = try Data(contentsOf: cacheURL)
            let cache = try JSONDecoder().decode(RecipeCache.self, from: data)
            logMessage("📦 Rezepte aus Cache geladen: \(cache.recipes.count)")
            return cache.recipes
        } catch {
            logMessage("⚠️ Kein Cache oder ungültig: \(error)")
            return []
        }
    }

    func clear() {
        do {
            try FileManager.default.removeItem(at: cacheURL)
            logMessage("🧹 Rezept-Cache-Datei gelöscht")
        } catch {
            logMessage("⚠️ Konnte Cache-Datei nicht löschen: \(error)")
        }
    }
}

extension RecipeCacheManager {
    /// Holt ein einzelnes Rezept von der API und ersetzt es im lokalen Cache
    @MainActor
    func reloadRecipe(with id: String) async {
        // 1. Alle Rezepte laden
        var cachedRecipes = load()
        
        // 2. Rezept aus der API nachladen (nutze hier deine APIService-Logik)
        do {
            let updatedRecipe = try await APIService.shared.fetchRecipeDetail(id: id)
            
            // 3. Rezept im Array ersetzen (nach id suchen)
            if let index = cachedRecipes.firstIndex(where: { $0.id == id }) {
                cachedRecipes[index] = updatedRecipe
            } else {
                // Falls es noch nicht im Cache war: anhängen
                cachedRecipes.append(updatedRecipe)
            }
            
            // 4. Gesamten Cache speichern
            save(recipes: cachedRecipes)
            logMessage("🔄 Einzelnes Rezept neu gecached: \(updatedRecipe.name)")
        } catch {
            logMessage("❌ Rezept konnte nicht neu geladen werden: \(error)")
        }
    }
    
    /// Holt ein einzelnes Rezept aus dem Cache anhand der UUID
    func getRecipe(byId id: UUID) -> RecipeDetail? {
        let recipes = load()
        return recipes.first { $0.id == id.uuidString }
    }
}
