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

// MARK: - Pending-Änderungen für jede Aktion
struct PendingCheckChange: Codable, Equatable { let itemId: UUID; let checked: Bool }
struct PendingQuantityChange: Codable, Equatable { let itemId: UUID; let quantity: Double }
struct PendingDeleteChange: Codable, Equatable { let itemId: UUID }
struct PendingAddChange: Codable, Equatable, Identifiable {let id: UUID; let note: String; let labelId:String?}
struct PendingCategoryChange: Codable, Equatable { let itemId: UUID; let labelId: String? }

@MainActor
class ShoppingListViewModel: ObservableObject {
    @Published var shoppingList: [ShoppingItem] = []
    @Published var archivedLists: [[ShoppingItem]] = []
    @Published var availableLabels: [ShoppingItem.LabelWrapper] = []
    @Published var availableShoppingLists: [ShoppingList] = []
    @Published var isOffline: Bool = false
    @Published var selectedItemForEditing: ShoppingItem?

    @Published var pendingCheckChanges: [PendingCheckChange] = []
    @Published var pendingQuantityChanges: [PendingQuantityChange] = []
    @Published var pendingDeleteChanges: [PendingDeleteChange] = []
    @Published var pendingAddChanges: [PendingAddChange] = []
    @Published var pendingCategoryChanges: [PendingCategoryChange] = []
    @Published var serverSnapshot: [ShoppingItem] = []
    


    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()

    private static let pendingCheckKey = "pendingCheckChanges"
    private static let pendingQuantityKey = "pendingQuantityChanges"
    private static let pendingDeleteKey = "pendingDeleteChanges"
    private static let pendingAddKey = "pendingAddChanges"
    private static let pendingCategoryKey = "pendingCategoryChanges"

    init() {
        loadAllPendingChanges()
        logMessage("🎒 ShoppingListViewModel initialisiert")
        observeConnectionRestore()
        Task {
            await loadLabels()
            await loadShoppingListFromServer()
        }
    }

    func toggleIngredientCompletion(_ item: ShoppingItem) {
        guard let index = shoppingList.firstIndex(where: { $0.id == item.id }) else { return }
        shoppingList[index].checked.toggle()
        ShoppingListCache.save(self.shoppingList)
        let updatedItem = shoppingList[index]
        Task {
            do {
                try await apiService.updateShoppingItem(updatedItem)
            } catch {
                let change = PendingCheckChange(itemId: item.id, checked: updatedItem.checked)
                if !pendingCheckChanges.contains(change) {
                    pendingCheckChanges.append(change)
                    savePendingCheckChanges()
                }
            }
        }
    }

    func updateQuantity(for item: ShoppingItem, to newQuantity: Double) {
        guard let index = shoppingList.firstIndex(where: { $0.id == item.id }) else { return }
        shoppingList[index].quantity = newQuantity
        ShoppingListCache.save(self.shoppingList)
        let updatedItem = shoppingList[index]
        Task {
            do {
                try await apiService.updateShoppingItem(updatedItem)
            } catch {
                let change = PendingQuantityChange(itemId: item.id, quantity: newQuantity)
                if !pendingQuantityChanges.contains(change) {
                    pendingQuantityChanges.append(change)
                    savePendingQuantityChanges()
                }
            }
        }
    }

    func deleteIngredient(at offsets: IndexSet) {
        let items = offsets.map { shoppingList[$0] }
        for item in items {
            Task {
                do {
                    try await apiService.deleteShoppingItem(id: item.id)
                } catch {
                    let change = PendingDeleteChange(itemId: item.id)
                    if !pendingDeleteChanges.contains(change) {
                        pendingDeleteChanges.append(change)
                        savePendingDeleteChanges()
                    }
                }
            }
        }
        shoppingList.remove(atOffsets: offsets)
        ShoppingListCache.save(self.shoppingList)
    }

    func addManualIngredient(note: String, label: ShoppingItem.LabelWrapper?) {
        Task {
            do {
                // Versuch, Artikel online hinzuzufügen
                let item: ShoppingItem
                do {
                    // API-Aufruf
                    item = try await apiService.addShoppingItem(note: note, labelId: label?.id)
                } catch {
                    // Speziell behandeln, wenn kein Response-Body zurückkommt
                    if let urlError = error as? URLError, urlError.code == .zeroByteResource {
                        // Dummy-Item erzeugen, falls Mealie keinen Body zurückgibt
                        item = ShoppingItem(
                            id: UUID(),
                            note: note,
                            checked: false,
                            shoppingListId: "",
                            label: label,
                            quantity: 1
                        )
                    } else {
                        throw error // Weiterwerfen bei echten Fehlern
                    }
                }

                var finalItem = item
                finalItem.label = label
                finalItem.quantity = 1
                DispatchQueue.main.async {
                    self.shoppingList.append(finalItem)
                    ShoppingListCache.save(self.shoppingList)
                }

            } catch {
                logMessage("❌ Fehler beim Hinzufügen: \(error.localizedDescription)")

                // Nur bei aktiver Offline-Erkennung PendingChange erzeugen
                if self.isOffline {
                    let change = PendingAddChange(id: UUID(), note: note, labelId: label?.id)
                    if !pendingAddChanges.contains(change) {
                        pendingAddChanges.append(change)
                        savePendingAddChanges()
                    }

                    let newItem = ShoppingItem(
                        id: UUID(),
                        note: note,
                        checked: false,
                        shoppingListId: "",
                        label: label,
                        quantity: 1
                    )

                    DispatchQueue.main.async {
                        self.shoppingList.append(newItem)
                        ShoppingListCache.save(self.shoppingList)
                    }
                }
            }
        }
    }


    func loadLabels() async {
        do {
            let labels = try await apiService.fetchShoppingLabels()
            self.availableLabels = labels
            LabelCache.save(labels)
        } catch {
            logMessage("❌ Fehler beim Laden der Labels: \(error.localizedDescription)")
            let fallback = LabelCache.load()
            self.availableLabels = fallback
            logMessage("📦 Labels aus Cache geladen: \(fallback.count)")
        }
    }

    func addIngredients(_ ingredients: [Ingredient]) {
        Task {
            var newNotes: [String] = []
            for ingredient in ingredients {
                // ✅ Extrahiere nur den Zutatennamen (ohne Menge/Einheit)
                let ingredientName = buildIngredientName(for: ingredient)
                
                // Prüfe, ob die Zutat leer ist
                guard !ingredientName.isEmpty else { 
                    logMessage("⚠️ Zutat übersprungen: Kein Name vorhanden")
                    continue 
                }
                
                // Prüfe, ob die Zutat bereits auf der Liste ist
                if !shoppingList.contains(where: { $0.note?.lowercased() == ingredientName.lowercased() }) {
                    do {
                        _ = try await apiService.addShoppingItem(note: ingredientName, labelId: nil)
                        newNotes.append(ingredientName)
                        logMessage("✅ Zutat hinzugefügt: '\(ingredientName)'")
                    } catch {
                        // 🔍 Prüfe, ob es ein ECHTER Offline-Fehler ist
                        let isRealOfflineError = isNetworkError(error)
                        
                        if isRealOfflineError {
                            // ✅ Nur bei echten Netzwerkfehlern: PendingChange erstellen
                            logMessage("❌ Offline-Fehler für '\(ingredientName)': \(error.localizedDescription)")
                            let change = PendingAddChange(id: UUID(), note: ingredientName, labelId: nil)
                            if !pendingAddChanges.contains(change) {
                                pendingAddChanges.append(change)
                                savePendingAddChanges()
                            }
                            let newItem = ShoppingItem(
                                id: UUID(),
                                note: ingredientName,
                                checked: false,
                                shoppingListId: "",
                                label: nil,
                                quantity: 1
                            )
                            self.shoppingList.append(newItem)
                            ShoppingListCache.save(self.shoppingList)
                        } else {
                            // ⚠️ Server-Response-Problem, aber Item wurde wahrscheinlich hinzugefügt
                            logMessage("⚠️ Server-Response-Fehler für '\(ingredientName)', Item wurde vermutlich hinzugefügt")
                            // Füge zu newNotes hinzu, damit Liste neu geladen wird
                            newNotes.append(ingredientName)
                        }
                    }
                } else {
                    logMessage("⚠️ '\(ingredientName)' ist bereits auf der Liste.")
                }
            }
            
            // 🔄 Liste neu laden (auch bei Response-Fehlern)
            if !newNotes.isEmpty {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 Sekunden warten
                do {
                    let updatedItems = try await apiService.fetchShoppingListItems()
                    self.shoppingList = updatedItems
                    logMessage("✅ Liste aktualisiert: \(updatedItems.count) Einträge")
                } catch {
                    logMessage("❌ Fehler beim Neuladen der Liste: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Prüft, ob ein Fehler ein echter Netzwerk-/Offline-Fehler ist
    /// - Parameter error: Der aufgetretene Fehler
    /// - Returns: true bei echten Offline-Fehlern, false bei Server-Response-Problemen
    private func isNetworkError(_ error: Error) -> Bool {
        // URLError-Codes für Netzwerkprobleme
        if let urlError = error as? URLError {
            switch urlError.code {
            // ✅ Echte Offline-Fehler
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .cannotConnectToHost,
                 .timedOut,
                 .dnsLookupFailed,
                 .cannotFindHost:
                return true
                
            // ❌ Server-Response-Probleme (kein Offline-Fehler!)
            case .zeroByteResource,
                 .badServerResponse,
                 .cannotDecodeContentData,
                 .cannotDecodeRawData:
                return false
                
            default:
                return false
            }
        }
        
        // NSError für weitere Netzwerk-Checks
        let nsError = error as NSError
        
        // Prüfe Domain
        if nsError.domain == NSURLErrorDomain {
            // Weitere Offline-Codes
            return [
                NSURLErrorNotConnectedToInternet,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorTimedOut
            ].contains(nsError.code)
        }
        
        // Standard: Kein Offline-Fehler
        return false
    }
    
    /// Extrahiert nur den Zutatennamen (OHNE Menge/Einheit) für die Einkaufsliste
    /// - Parameter ingredient: Die Zutat aus dem Rezept
    /// - Returns: Nur der Name der Zutat (z.B. "Mehl" statt "250 g Mehl")
    private func buildIngredientName(for ingredient: Ingredient) -> String {
        // 1. Priorität: `food` Feld (enthält den Hauptnamen der Zutat)
        if let food = ingredient.food?.trimmingCharacters(in: .whitespacesAndNewlines), !food.isEmpty {
            // Optional: Zusätzliche Notiz in Klammern anhängen (z.B. "Mehl (Type 405)")
            if let note = ingredient.note?.trimmingCharacters(in: .whitespacesAndNewlines), 
               !note.isEmpty,
               !food.lowercased().contains(note.lowercased()) {
                return "\(food) (\(note))"
            }
            return food
        }
        
        // 2. Fallback: Wenn `food` leer ist, versuche `note` zu verwenden
        if let note = ingredient.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            return note
        }
        
        // 3. Letzter Fallback: "Zutat" als Platzhalter
        return "Zutat"
    }

    func fetchAvailableShoppingLists() async {
        do {
            let lists = try await apiService.fetchShoppingLists()
            self.availableShoppingLists = lists
        } catch {
            logMessage("❌ Fehler beim Laden der Einkaufsliste(n): \(error.localizedDescription)")
        }
    }

    func archiveList() async {
        let completedItems = shoppingList.filter { $0.checked }
        let remainingItems = shoppingList.filter { !$0.checked }

        if !completedItems.isEmpty {
            archivedLists.append(completedItems)
            shoppingList = remainingItems
            ShoppingListCache.save(self.shoppingList)

            Task {
                await apiService.deleteShoppingItems(completedItems)
            }
        }
    }

    func deleteItem(_ item: ShoppingItem) {
        Task {
            do {
                try await apiService.deleteShoppingItem(id: item.id)
                if let index = shoppingList.firstIndex(where: { $0.id == item.id }) {
                    shoppingList.remove(at: index)
                    ShoppingListCache.save(self.shoppingList)
                }
            } catch {
                let change = PendingDeleteChange(itemId: item.id)
                if !pendingDeleteChanges.contains(change) {
                    pendingDeleteChanges.append(change)
                    savePendingDeleteChanges()
                }
                if let index = shoppingList.firstIndex(where: { $0.id == item.id }) {
                    shoppingList.remove(at: index)
                    ShoppingListCache.save(self.shoppingList)
                }
            }
        }
    }

    func deleteArchivedList(at offsets: IndexSet) {
        archivedLists.remove(atOffsets: offsets)
    }

    func deleteAllArchivedLists() {
        archivedLists = []
    }

    func updateItemCategory(_ item: ShoppingItem, to newLabel: ShoppingItem.LabelWrapper?) {
        guard let index = shoppingList.firstIndex(where: { $0.id == item.id }) else { return }
        if shoppingList[index].label?.id == newLabel?.id { return }
        shoppingList[index].label = newLabel
        ShoppingListCache.save(self.shoppingList)
        let updatedItem = shoppingList[index]
        Task {
            do {
                try await apiService.updateShoppingItem(updatedItem)
                await loadShoppingListFromServer()
            } catch {
                let change = PendingCategoryChange(itemId: item.id, labelId: newLabel?.id)
                if !pendingCategoryChanges.contains(change) {
                    pendingCategoryChanges.append(change)
                    savePendingCategoryChanges()
                }
            }
        }
    }

    func updateShoppingItem(_ item: ShoppingItem) async {
        do {
            try await apiService.updateShoppingItem(item)
        } catch {
            logMessage("❌ Fehler beim Aktualisieren des Items: \(error.localizedDescription)")
        }
    }

    func addLabelIfNeeded(_ label: ShoppingItem.LabelWrapper?) {
        guard let label else { return }
        if !availableLabels.contains(label) {
            availableLabels.append(label)
        }
    }

    func loadShoppingListFromServer() async {
        do {
            let items = try await apiService.fetchShoppingListItems()

            // 👇 Mengen sicherstellen
            let itemsWithQuantity = items.map { item in
                var fixed = item
                fixed.quantity = fixed.quantity ?? 1
                return fixed
            }

            // 👇 Labels zuordnen, auch wenn Label-Objekt fehlt!
            let labelDict = Dictionary(uniqueKeysWithValues: availableLabels.map { ($0.id, $0) })
            let itemsWithLabels = itemsWithQuantity.map { item in
                var fixed = item
                if let id = item.label?.id {
                    fixed.label = labelDict[id]
                } else {
                    fixed.label = nil
                }
                return fixed
            }

            // 💾 Server-Snapshot für Konfliktvergleich speichern
            self.serverSnapshot = itemsWithLabels

            // ✅ Hauptliste aktualisieren
            self.shoppingList = itemsWithLabels
            self.isOffline = false
            ShoppingListCache.save(itemsWithLabels)
            logMessage("✅ Einkaufsliste geladen: \(itemsWithLabels.count) Einträge")

            if hasPendingChanges() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.post(name: .pendingShoppingSync, object: nil)
                }
            }

        } catch {
            logMessage("❌ Fehler beim Laden der Einkaufsliste: \(error.localizedDescription)")
            let cached = ShoppingListCache.load()
            self.shoppingList = cached
            self.isOffline = true
            logMessage("📦 Fallback: \(cached.count) Einträge aus lokalem Cache geladen")
        }
    }


    private func hasPendingChanges() -> Bool {
        return !pendingCheckChanges.isEmpty ||
               !pendingQuantityChanges.isEmpty ||
               !pendingDeleteChanges.isEmpty ||
               !pendingAddChanges.isEmpty ||
               !pendingCategoryChanges.isEmpty
    }

    private func savePendingCheckChanges()    { savePending(pendingCheckChanges, Self.pendingCheckKey) }
    private func savePendingQuantityChanges() { savePending(pendingQuantityChanges, Self.pendingQuantityKey) }
    private func savePendingDeleteChanges()   { savePending(pendingDeleteChanges, Self.pendingDeleteKey) }
    private func savePendingAddChanges()      { savePending(pendingAddChanges, Self.pendingAddKey) }
    private func savePendingCategoryChanges() { savePending(pendingCategoryChanges, Self.pendingCategoryKey) }

    private func loadPendingCheckChanges()    { pendingCheckChanges = loadPending(Self.pendingCheckKey) ?? [] }
    private func loadPendingQuantityChanges() { pendingQuantityChanges = loadPending(Self.pendingQuantityKey) ?? [] }
    private func loadPendingDeleteChanges()   { pendingDeleteChanges = loadPending(Self.pendingDeleteKey) ?? [] }
    private func loadPendingAddChanges()      { pendingAddChanges = loadPending(Self.pendingAddKey) ?? [] }
    private func loadPendingCategoryChanges() { pendingCategoryChanges = loadPending(Self.pendingCategoryKey) ?? [] }

    private func savePending<T: Codable>(_ changes: T, _ key: String) {
        if let data = try? JSONEncoder().encode(changes) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadPending<T: Codable>(_ key: String) -> T? {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(T.self, from: data) {
            return saved
        }
        return nil
    }

    private func loadAllPendingChanges() {
        loadPendingCheckChanges()
        loadPendingQuantityChanges()
        loadPendingDeleteChanges()
        loadPendingAddChanges()
        loadPendingCategoryChanges()
    }

    private func observeConnectionRestore() {
        $isOffline
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] offline in
                guard let self = self else { return }
                if offline == false && self.hasPendingChanges() {
                    DispatchQueue.main.async { [weak self] in
                        guard self != nil else { return }
                        NotificationCenter.default.post(name: .pendingShoppingSync, object: nil)
                    }
                }
            }
            .store(in: &cancellables)
    }

    func syncPendingChangesToServer(
        selectedCheckChanges: [UUID: Bool] = [:],
        selectedQuantityChanges: [UUID: Bool] = [:],
        selectedCategoryChanges: [UUID: Bool] = [:]
    ) async {
        // 🗑️ Delete
        for change in pendingDeleteChanges {
            do {
                try await apiService.deleteShoppingItem(id: change.itemId)
            } catch {
                logMessage("❌ Fehler beim Sync Löschen: \(error.localizedDescription)")
            }
        }
        pendingDeleteChanges.removeAll()
        savePendingDeleteChanges()

        // ➕ Add
        for change in pendingAddChanges {
            do {
                _ = try await apiService.addShoppingItem(note: change.note, labelId: change.labelId)
                logMessage("✅ Sync erfolgreich für: '\(change.note)'")
            } catch {
                logMessage("❌ Fehler beim Sync Hinzufügen: \(error.localizedDescription)")
            }
        }
        pendingAddChanges.removeAll()
        savePendingAddChanges()

        // 🔁 Alle übrigen Änderungen zusammenfassen
        let allChangedIds = Set(pendingCheckChanges.map { $0.itemId })
            .union(pendingQuantityChanges.map { $0.itemId })
            .union(pendingCategoryChanges.map { $0.itemId })

        for itemId in allChangedIds {
            guard var item = shoppingList.first(where: { $0.id == itemId }) else { continue }

            // ✅ Checked
            if let change = pendingCheckChanges.first(where: { $0.itemId == itemId }),
               selectedCheckChanges[itemId] ?? true {
                item.checked = change.checked
            }

            // 🔢 Quantity
            if let change = pendingQuantityChanges.first(where: { $0.itemId == itemId }),
               selectedQuantityChanges[itemId] ?? true {
                item.quantity = change.quantity
            }

            // 🏷️ Category
            if let change = pendingCategoryChanges.first(where: { $0.itemId == itemId }),
               selectedCategoryChanges[itemId] ?? true {
                if let labelId = change.labelId {
                    let label = availableLabels.first(where: { $0.id == labelId }) ??
                                ShoppingItem.LabelWrapper(id: labelId, name: "Unbekannt", slug: nil, color: nil)
                    item.label = label
                } else {
                    item.label = nil
                }
            }

            // 💾 Sync per PUT
            do {
                try await apiService.updateShoppingItem(item)
            } catch {
                logMessage("❌ Fehler beim Sync Item \(item.note ?? "-"): \(error.localizedDescription)")
            }
        }

        // 🧹 Pending zurücksetzen
        pendingCheckChanges.removeAll()
        pendingQuantityChanges.removeAll()
        pendingCategoryChanges.removeAll()
        savePendingCheckChanges()
        savePendingQuantityChanges()
        savePendingCategoryChanges()

        // 📦 Cache aktualisieren
        ShoppingListCache.save(shoppingList)

        // 🔄 Liste vom Server neu laden (entfernt potenzielle Duplikate)
        await loadShoppingListFromServer()
        
        logMessage("✅ Sync abgeschlossen - Liste aktualisiert")
    }



    private func cleanedNote(from rawNote: String) -> String {
        let pattern = "^\\d+([.,]\\d+)?\\s*(g|ml|TL|EL|Stk|Pck\\.?|Msp\\.?|Tasse|Tassen|Prise|Scheiben?|Stück|Dose|Dosen)?\\s+"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let range = NSRange(rawNote.startIndex..<rawNote.endIndex, in: rawNote)
            let cleaned = regex.stringByReplacingMatches(in: rawNote, options: [], range: range, withTemplate: "")
            return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return rawNote
    }
}

private func extractLabelsFromItems(_ items: [ShoppingItem]) -> [ShoppingItem.LabelWrapper] {
    let labels = items.compactMap { $0.label }
    let unique = Array(Set(labels))
    return unique.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
}

extension Notification.Name {
    static let pendingShoppingSync = Notification.Name("pendingShoppingSync")
}
