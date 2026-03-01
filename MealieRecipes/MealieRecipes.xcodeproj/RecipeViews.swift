import SwiftUI

// MARK: - Recipe Detail View

struct RecipeDetailView: View {
    @StateObject private var viewModel = RecipeViewModel()
    let recipeId: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("Lade Rezept...")
                        .frame(maxWidth: .infinity)
                } else if let recipe = viewModel.recipe {
                    recipeContent(recipe)
                } else if let error = viewModel.error {
                    errorView(error)
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.recipe?.name ?? "Rezept")
        .task {
            await viewModel.loadRecipe(id: recipeId)
        }
        .refreshable {
            await viewModel.refreshIngredients()
        }
    }
    
    @ViewBuilder
    private func recipeContent(_ recipe: Recipe) -> some View {
        // Header
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.name)
                .font(.title)
                .bold()
            
            if !recipe.description.isEmpty {
                Text(recipe.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        
        Divider()
        
        // Ingredients Section
        ingredientsSection(recipe.ingredients)
    }
    
    @ViewBuilder
    private func ingredientsSection(_ ingredients: [Ingredient]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Zutaten")
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                Text("\(ingredients.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if ingredients.isEmpty {
                emptyIngredientsView
            } else {
                // 🔥 Wichtig: Stabile IDs verwenden!
                ForEach(ingredients) { ingredient in
                    IngredientRow(ingredient: ingredient)
                }
            }
        }
    }
    
    private var emptyIngredientsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("Keine Zutaten vorhanden")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func errorView(_ error: MealieError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            
            Text(error.errorDescription ?? "Unbekannter Fehler")
                .multilineTextAlignment(.center)
            
            Button("Erneut versuchen") {
                Task {
                    await viewModel.loadRecipe(id: recipeId)
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Ingredient Row

struct IngredientRow: View {
    let ingredient: Ingredient
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox (optional, für Einkaufsliste)
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                // Haupttext
                Text(ingredient.displayText)
                    .font(.body)
                
                // Note hervorgehoben (falls vorhanden)
                // 🔥 Dies war oft das Problem: Notes wurden nicht angezeigt!
                if ingredient.hasNote {
                    Label(ingredient.note, systemImage: "note.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                }
                
                // Debug-Info (nur in DEBUG builds)
                #if DEBUG
                if let originalText = ingredient.originalText.isEmpty ? nil : ingredient.originalText {
                    Text("Original: \(originalText)")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                #endif
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle()) // Für besseres Tap-Target
    }
}

// MARK: - Alternative: Kompakte Liste

struct CompactIngredientsList: View {
    let ingredients: [Ingredient]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Zutaten")
                .font(.headline)
            
            // 🔥 Kein compactMap - zeige ALLE Zutaten!
            ForEach(ingredients) { ingredient in
                HStack(spacing: 8) {
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text(ingredient.compactDisplayText)
                        .font(.body)
                    
                    if ingredient.hasNote {
                        Image(systemName: "note.text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Grouped Ingredients (nach Kategorie)

struct GroupedIngredientsView: View {
    let ingredients: [Ingredient]
    
    // Gruppierung nach erstem Buchstaben (Beispiel)
    private var groupedIngredients: [(String, [Ingredient])] {
        let grouped = Dictionary(grouping: ingredients) { ingredient in
            String(ingredient.name.prefix(1).uppercased())
        }
        return grouped.sorted { $0.key < $1.key }
    }
    
    var body: some View {
        List {
            ForEach(groupedIngredients, id: \.0) { letter, items in
                Section(letter) {
                    // 🔥 Wichtig: id muss unique sein
                    ForEach(items) { ingredient in
                        IngredientRow(ingredient: ingredient)
                    }
                }
            }
        }
    }
}

// MARK: - Editable Ingredients List (für Rezeptbearbeitung)

struct EditableIngredientsView: View {
    @Binding var ingredients: [Ingredient]
    
    var body: some View {
        List {
            ForEach(ingredients) { ingredient in
                IngredientRow(ingredient: ingredient)
            }
            .onDelete(perform: deleteIngredients)
            .onMove(perform: moveIngredients)
            
            Button(action: addIngredient) {
                Label("Zutat hinzufügen", systemImage: "plus.circle.fill")
            }
        }
        .toolbar {
            EditButton()
        }
    }
    
    private func deleteIngredients(at offsets: IndexSet) {
        ingredients.remove(atOffsets: offsets)
    }
    
    private func moveIngredients(from source: IndexSet, to destination: Int) {
        ingredients.move(fromOffsets: source, toOffset: destination)
    }
    
    private func addIngredient() {
        let newIngredient = Ingredient(
            id: UUID(),
            quantityText: "",
            unit: "",
            name: "Neue Zutat",
            note: "",
            originalText: "",
            quantityValue: nil,
            referenceId: nil,
            shouldDisplayAmount: true
        )
        ingredients.append(newIngredient)
    }
}

// MARK: - Preview

#Preview("Recipe Detail") {
    NavigationStack {
        RecipeDetailView(recipeId: "test-recipe-id")
    }
}

#Preview("Ingredient Row") {
    VStack(spacing: 0) {
        // Mit Note
        IngredientRow(
            ingredient: Ingredient(
                id: UUID(),
                quantityText: "2",
                unit: "kg",
                name: "Mehl",
                note: "Type 405, Bio",
                originalText: "",
                quantityValue: 2,
                referenceId: nil,
                shouldDisplayAmount: true
            )
        )
        
        Divider()
        
        // Ohne Note
        IngredientRow(
            ingredient: Ingredient(
                id: UUID(),
                quantityText: "1",
                unit: "TL",
                name: "Salz",
                note: "",
                originalText: "",
                quantityValue: 1,
                referenceId: nil,
                shouldDisplayAmount: true
            )
        )
        
        Divider()
        
        // Ohne Menge
        IngredientRow(
            ingredient: Ingredient(
                id: UUID(),
                quantityText: "",
                unit: "",
                name: "Prise Pfeffer",
                note: "frisch gemahlen",
                originalText: "Prise Pfeffer (frisch gemahlen)",
                quantityValue: nil,
                referenceId: nil,
                shouldDisplayAmount: false
            )
        )
    }
    .padding()
}
