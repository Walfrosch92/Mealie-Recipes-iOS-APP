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

struct AddMealEntryView: View {
    @Environment(\.dismiss) var dismiss

    let defaultDate: Date
    let defaultRecipeId: String?
    let defaultNote: String?
    let onAdd: (_ date: Date, _ slot: String, _ recipeId: String?, _ note: String?) -> Void

    @State private var selectedDate: Date
    @State private var selectedSlot: String = "lunch"
    @State private var recipes: [RecipeSummary] = []
    @State private var isLoading = false
    @State private var searchText: String = ""

    var filteredRecipes: [RecipeSummary] {
        if searchText.isEmpty {
            return recipes
        } else {
            return recipes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    init(
        defaultDate: Date = Date(),
        defaultRecipeId: String? = nil,
        defaultNote: String? = nil,
        onAdd: @escaping (_ date: Date, _ slot: String, _ recipeId: String?, _ note: String?) -> Void
    ) {
        self.defaultDate = defaultDate
        self.defaultRecipeId = defaultRecipeId
        self.defaultNote = defaultNote
        self.onAdd = onAdd

        _selectedDate = State(initialValue: defaultDate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                // 🔝 Vorgewähltes Rezept ganz oben anzeigen (wenn vorhanden)
                if let lockedRecipeId = defaultRecipeId,
                   let lockedRecipe = findRecipeById(lockedRecipeId) {

                    VStack(spacing: 8) {
                        Text(LocalizedStringProvider.localized("selected_recipe"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            Text(lockedRecipe.name)
                                .font(.headline)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }

                // 📅 Datumsauswahl
                DatePicker(LocalizedStringProvider.localized("select_date"), selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding(.horizontal)

                // 🍽 Slot-Auswahl
                Picker(LocalizedStringProvider.localized("select_slot"), selection: $selectedSlot) {
                    Text("🍳 \(LocalizedStringProvider.localized("breakfast"))").tag("breakfast")
                    Text("🥪 \(LocalizedStringProvider.localized("lunch"))").tag("lunch")
                    Text("🍽 \(LocalizedStringProvider.localized("dinner"))").tag("dinner")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // 🧩 Rezeptwahl oder Liste
                if isLoading {
                    ProgressView(LocalizedStringProvider.localized("loading_recipes"))
                        .padding()
                } else {
                    // Prüfe ob ein Rezept vorausgewählt ist
                    if let lockedRecipeId = defaultRecipeId {
                        // Vorausgewähltes Rezept → Button zum Einplanen
                        Button {
                            logMessage("📅 Plane Rezept ein: ID=\(lockedRecipeId), Datum=\(selectedDate), Slot=\(selectedSlot)")
                            onAdd(selectedDate, selectedSlot, lockedRecipeId, defaultNote)
                            dismiss()
                        } label: {
                            Label(LocalizedStringProvider.localized("confirm_meal"), systemImage: "checkmark.circle.fill")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .disabled(isLoading) // Deaktivieren während des Ladens

                    } else {
                        // 🔍 Kein Rezept vorausgewählt → normale Rezeptliste mit Suche
                        List {
                            ForEach(filteredRecipes) { recipe in
                                Button {
                                    onAdd(selectedDate, selectedSlot, recipe.id, nil)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text(recipe.name)
                                        Spacer()
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }

                            if !searchText.isEmpty && filteredRecipes.isEmpty {
                                Section {
                                    Button {
                                        onAdd(selectedDate, selectedSlot, nil, searchText)
                                        dismiss()
                                    } label: {
                                        HStack {
                                            Text("➕ \(LocalizedStringProvider.localized("add_custom_meal")) \"\(searchText)\"")
                                                .multilineTextAlignment(.leading)
                                            Spacer()
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .searchable(text: $searchText, prompt: LocalizedStringProvider.localized("search_recipes"))
                    }
                }
            }
            .navigationTitle(LocalizedStringProvider.localized("plan_meal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringProvider.localized("cancel")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadRecipes()
            }
        }
    }

    func loadRecipes() {
        Task {
            isLoading = true
            do {
                recipes = try await APIService.shared.fetchRecipes()

                // ✅ Debug-Ausgabe hier:
                logMessage("✅ Loaded recipes:")
                for recipe in recipes {
                    logMessage("• \(recipe.name) → ID: \(recipe.id)")
                }
                logMessage("🔍 Default ID to match: \(defaultRecipeId ?? "nil")")
                
                // Überprüfe ob das vorgewählte Rezept gefunden wurde
                if let lockedId = defaultRecipeId {
                    if let found = findRecipeById(lockedId) {
                        logMessage("✅ Vorgewähltes Rezept gefunden: \(found.name)")
                    } else {
                        logMessage("⚠️ Vorgewähltes Rezept mit ID \(lockedId) nicht in der Liste gefunden!")
                    }
                }

            } catch {
                logMessage("❌ Fehler beim Laden der Rezepte: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }
    
    // MARK: - Helper-Funktion zum Finden von Rezepten
    
    /// Findet ein Rezept anhand seiner ID (case-insensitive Vergleich für UUID-Strings)
    private func findRecipeById(_ recipeId: String) -> RecipeSummary? {
        return recipes.first { $0.id.lowercased() == recipeId.lowercased() }
    }
}
