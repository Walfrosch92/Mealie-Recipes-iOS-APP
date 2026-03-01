import Foundation
import SwiftUI

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
class MealplanViewModel: ObservableObject {
    @Published var entriesByDay: [Date: [MealplanEntry]] = [:]
    @Published var isLoading = false

    init() {
        fetchMealplan()
    }

    func fetchMealplan() {
        Task {
            await fetchMealplanAsync()
        }
    }

    func fetchMealplanAsync() async {
        isLoading = true
        logMessage("🔄 MealplanViewModel: Lade Mealplan-Einträge...")
        
        do {
            let entries = try await APIService.shared.fetchMealplanEntries()
            logMessage("📦 Empfangen: \(entries.count) Einträge")
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            
            // Alternative Formatter für verschiedene Datumsformate
            let dateFormatterYMD = DateFormatter()
            dateFormatterYMD.dateFormat = "yyyy-MM-dd"
            dateFormatterYMD.timeZone = TimeZone(secondsFromGMT: 0)
            
            let grouped = Dictionary(grouping: entries, by: { entry in
                // Versuche verschiedene Formate
                if let date = formatter.date(from: entry.date) {
                    logMessage("   ✅ Datum geparsed (ISO8601): \(entry.date) → \(date)")
                    return date
                } else if let date = dateFormatterYMD.date(from: entry.date) {
                    logMessage("   ✅ Datum geparsed (yyyy-MM-dd): \(entry.date) → \(date)")
                    return date
                } else {
                    logMessage("   ⚠️ Konnte Datum nicht parsen: \(entry.date)")
                    return Date.distantPast
                }
            })
            
            entriesByDay = grouped
            logMessage("✅ Einträge gruppiert nach \(grouped.keys.count) Tagen")
            
            // Details ausgeben
            for (date, entries) in grouped.sorted(by: { $0.key < $1.key }) {
                logMessage("   📅 \(date): \(entries.count) Einträge")
            }
            
        } catch {
            logMessage("❌ Fehler beim Laden des Mealplans: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                logMessage("   🔍 Details: \(decodingError)")
            }
            // WICHTIG: Behalte alte Daten bei Fehler, leere sie nicht!
            // entriesByDay = [:] ❌ Das nicht mehr machen
        }
        isLoading = false
    }

    func refresh() {
        fetchMealplan()
    }

    func localizedDate(_ date: Date) -> String {
        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: AppSettings.shared.selectedLanguage)
        displayFormatter.dateFormat = "EEEE, d. MMMM yyyy"
        return displayFormatter.string(from: date)
    }

    func addMeal(date: Date, recipeId: String?, slot: String, note: String?) {
        Task {
            do {
                try await APIService.shared.addMealEntry(
                    date: date,
                    slot: slot,
                    recipeId: recipeId,
                    note: note
                )
                await fetchMealplanAsync()
            } catch {
                logMessage("❌ Fehler beim Einplanen: \(error.localizedDescription)")
            }
        }
    }

    func recipeImageURL(for imageId: String) -> URL? {
        guard let base = APIService.shared.getBaseURL() else { return nil }
        return base.appendingPathComponent("api/media/recipes/\(imageId)")
    }

    func removeMeal(_ entry: MealplanEntry) {
        Task {
            do {
                try await APIService.shared.deleteMealEntry(entry.id)
                await fetchMealplanAsync()
            } catch {
                logMessage("❌ Fehler beim Entfernen der Mahlzeit: \(error.localizedDescription)")
            }
        }
    }
}
