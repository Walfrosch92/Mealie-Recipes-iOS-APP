//
//  ShoppingListCache.swift
//  MealieRecipes
//
//  Created by Michael Haiszan on 19.05.25.
//


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

struct ShoppingListCache {
    private static let filename = "shoppingListCache.json"

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent(filename)
    }

    static func save(_ items: [ShoppingItem]) {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: [.atomicWrite])
        } catch {
            logMessage("❌ Fehler beim Speichern des Einkaufslisten-Caches:", error)
        }
    }

    static func load() -> [ShoppingItem] {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([ShoppingItem].self, from: data)
        } catch {
            logMessage("⚠️ Kein gültiger Cache gefunden oder Fehler beim Laden:", error)
            return []
        }
    }
}
