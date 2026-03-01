
import SwiftUI
import UIKit

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

struct RecipeDetailView: View {
    let recipeId: UUID
    @StateObject private var viewModel = RecipeDetailViewModel()
    @EnvironmentObject var timerModel: TimerViewModel

    @EnvironmentObject var shoppingListViewModel: ShoppingListViewModel
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dismiss) var dismiss

    @State private var showIngredients = false
    @State private var showInstructions = false
    @State private var showSuccessAlert = false
    @State private var showTimerSheet = false
    @State private var showDeleteConfirmation = false
    @State private var timerDurationMinutes: Double = 1
    @State private var completedIngredients: Set<UUID> = []
    @State private var completedInstructions: Set<UUID> = []
    @State private var keepScreenOn = false
    @State private var quantityMultiplier: Double = 1.0
    @State private var showAddMealSheet = false
    @State private var showEditView = false
    @State var cachedTags: [RecipeTag] = []
    @State var cachedCategories: [Category] = []
    
    // Haptic Feedback Generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()


   

 
    struct DurationWrapper: Identifiable {
        let id = UUID()
        let minutes: Double
    }

    @State private var selectedDuration: DurationWrapper? = nil




    var body: some View {
        Group {
            if let recipe = viewModel.recipe {
                content(for: recipe)
            } else if viewModel.isLoading {
                ProgressView(LocalizedStringProvider.localized("loading_recipe"))
            } else {
                Text(LocalizedStringProvider.localized("error_loading_recipe"))
                    .foregroundColor(.red)
            }
        }
        .navigationTitle(LocalizedStringProvider.localized("details"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showEditView = true
                } label: {
                    Image(systemName: "pencil")
                }
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }


        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text(LocalizedStringProvider.localized("confirm_delete_title")),
                message: Text(LocalizedStringProvider.localized("confirm_delete_message")),
                primaryButton: .destructive(Text(LocalizedStringProvider.localized("delete"))) {
                    Task {
                        await deleteRecipe()
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            Task {
                await viewModel.fetchRecipe(by: recipeId.uuidString)
                await viewModel.fetchTags()
                await viewModel.fetchCategories()
                resetCompleted()
            }

        }


        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sheet(isPresented: $showEditView) {
            if let recipe = viewModel.recipe,
               !viewModel.allTags.isEmpty,
               !viewModel.allCategories.isEmpty
            {
                NavigationStack {
                    EditRecipeView(
                        originalSlug: recipe.slug,
                        recipe: recipe,
                        allTags: viewModel.allTags,
                        allCategories: viewModel.allCategories
                    ) { _ in
                        // ✅ Schließe Sheet sofort - Reload passiert in onDismiss
                        showEditView = false
                    }
                }
            } else {
                ProgressView("Lade Schlagworte/Kategorien …")
                    .padding()
            }
        }
        // ✅ NEU: Reload nach Schließen der EditView
        .onChange(of: showEditView) { _, isShowing in
            if !isShowing {
                // Sheet wurde geschlossen → Lade Rezept neu
                Task {
                    // Warte kurz, damit der Cache vom EditRecipeView geschrieben ist
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 Sekunden
                    await viewModel.fetchRecipe(by: recipeId.uuidString)
                    
                    #if DEBUG
                    logMessage("🔄 RecipeDetailView: Rezept nach Edit neu geladen")
                    #endif
                }
            }
        }
        .sheet(isPresented: $showAddMealSheet) {
            if let recipe = viewModel.recipe {
                AddMealEntryView(
                    defaultDate: Date(),
                    defaultRecipeId: recipe.id,
                    defaultNote: nil
                ) { date, slot, recipeId, note in
                    Task {
                        do {
                            logMessage("🔵 RecipeDetailView: onAdd-Closure aufgerufen")
                            logMessage("   Rezept-ID aus AddMealEntryView: \(recipeId ?? "nil")")
                            
                            try await APIService.shared.addMealEntry(
                                date: date,
                                slot: slot,
                                recipeId: recipeId,
                                note: note
                            )
                            
                            logMessage("✅ Mahlzeit erfolgreich eingeplant!")
                            showAddMealSheet = false
                        } catch {
                            logMessage("❌ Fehler beim Einplanen: \(error.localizedDescription)")
                        }
                    }
                }
            } else {
                ProgressView("Lade Rezept …").padding()
            }
        }




    }

    @ViewBuilder
    private func content(for recipe: RecipeDetail) -> some View {
        if UIDevice.current.orientation.isLandscape {
            HStack(alignment: .top) {
                sideBar(for: recipe)
                ScrollView {
                    recipeContent(recipe)
                }.padding()
            }
        } else {
            // ✅ 3️⃣ Portrait-Modus: Header mit Bild + Info
            ScrollView {
                VStack(spacing: 16) {
                    portraitHeader(for: recipe)
                    recipeContent(recipe)
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private func sideBar(for recipe: RecipeDetail) -> some View {
        VStack(spacing: 16) {
            if let url = buildImageURL(recipeID: recipe.id),
               let token = APIService.shared.getToken() {
                AuthenticatedAsyncImage(url: url, token: token)
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Text(recipe.name)
                .font(.headline)
                .multilineTextAlignment(.center)

            // Zeiten nur in Queransicht hier anzeigen, mittig
            recipeTimeAndServingsSummary(recipe)

        }
        .frame(width: 240)
        .padding()
    }

    /// ✅ 3️⃣ Portrait Header: Bild links, Info-Box rechts (wie im Querformat)
    @ViewBuilder
    private func portraitHeader(for recipe: RecipeDetail) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Bild linksbündig - gleiche Größe wie im Querformat
            if let url = buildImageURL(recipeID: recipe.id),
               let token = APIService.shared.getToken() {
                AuthenticatedAsyncImage(url: url, token: token)
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // ✅ Info-Box rechts daneben - exakt wie im Querformat (recipeTimeAndServingsSummary)
            // Diese Box enthält: Zeiten, Portionen und Bewertung in einer kompakten Darstellung
            recipeTimeAndServingsSummaryCompact(recipe)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    /// Kompakte Info-Box für Portrait-Modus (entspricht der Querformat-Ansicht)
    @ViewBuilder
    private func recipeTimeAndServingsSummaryCompact(_ recipe: RecipeDetail) -> some View {
        let hasTime = recipe.totalTime != nil || recipe.prepTime != nil || recipe.cookTime != nil
        let hasServings = recipe.recipeServings != nil && recipe.recipeServings! > 0
        let hasRating = recipe.rating != nil && recipe.rating! > 0

        if hasTime || hasServings || hasRating {
            VStack(spacing: 12) {
                // ✅ Zeit-Anzeige: Icons oben, Werte unten (horizontal)
                if hasTime {
                    let timeElements = buildTimeElements(from: recipe)
                    
                    if !timeElements.isEmpty {
                        VStack(spacing: 4) {
                            // Erste Zeile: Alle Icons horizontal
                            HStack(spacing: 16) {
                                ForEach(Array(timeElements.enumerated()), id: \.offset) { _, element in
                                    Image(systemName: element.icon)
                                        .font(.title3)
                                        .foregroundColor(.accentColor)
                                        .frame(minWidth: 30)
                                }
                            }
                            
                            // Zweite Zeile: Alle Zeitwerte horizontal
                            HStack(spacing: 16) {
                                ForEach(Array(timeElements.enumerated()), id: \.offset) { _, element in
                                    Text(element.value)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .frame(minWidth: 30)
                                }
                            }
                        }
                    }
                }
                
                // ✅ Portionen
                if hasServings, let scaled = scaledServings(for: recipe.recipeServings) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2")
                            .font(.body)
                            .foregroundColor(.accentColor)
                        Text("\(scaled)")
                            .font(.body)
                            .fontWeight(.medium)
                        Text(LocalizedStringProvider.localized("servings"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // ✅ Bewertung (wie im Querformat)
                if hasRating, let rating = recipe.rating {
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                .font(.body)
                                .foregroundColor(.orange)
                        }
                        Text(String(format: "%.0f/5", rating))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    /// ✅ 2️⃣ Zeiten kompakt in EINER Zeile (Portrait-Modus)
    /// Layout: Icons oben, Zeiten unten
    @ViewBuilder
    private func portraitTimeInfo(_ recipe: RecipeDetail) -> some View {
        let timeElements = buildTimeElements(from: recipe)
        
        if !timeElements.isEmpty {
            VStack(spacing: 4) {
                // Erste Zeile: Alle Icons
                HStack(spacing: 12) {
                    ForEach(Array(timeElements.enumerated()), id: \.offset) { _, element in
                        Image(systemName: element.icon)
                            .font(.caption)
                            .foregroundColor(.accentColor)
                            .frame(minWidth: 30)
                    }
                }
                
                // Zweite Zeile: Alle Zeitwerte
                HStack(spacing: 12) {
                    ForEach(Array(timeElements.enumerated()), id: \.offset) { _, element in
                        Text(element.value)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .frame(minWidth: 30)
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }
    
    /// Helper: Baut Zeit-Elemente für die Anzeige
    private func buildTimeElements(from recipe: RecipeDetail) -> [(icon: String, value: String)] {
        var elements: [(icon: String, value: String)] = []
        
        if let prep = recipe.prepTime, prep > 0 {
            elements.append(("fork.knife", formatMinutesCompact(prep)))
        }
        if let cook = recipe.cookTime, cook > 0 {
            elements.append(("flame.fill", formatMinutesCompact(cook)))
        }
        if let total = recipe.totalTime, total > 0 {
            elements.append(("clock.fill", formatMinutesCompact(total)))
        }
        
        return elements
    }
    
    /// Kompaktes Format für Zeit (z.B. "15m" oder "1h 30m")
    private func formatMinutesCompact(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)m"
    }


    @ViewBuilder
    private func recipeContent(_ recipe: RecipeDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let desc = recipe.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
            }
            ingredientButtons()
            ingredientGroup(recipe)
            timerButton()
            instructionGroup(recipe)
            
            Button {
                showAddMealSheet = true
            } label: {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .symbolRenderingMode(.hierarchical)
                    Text(LocalizedStringProvider.localized("plan_meal"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }

            Toggle(LocalizedStringProvider.localized("display_always_on"), isOn: $keepScreenOn)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .onChange(of: keepScreenOn) { _, newValue in
                    UIApplication.shared.isIdleTimerDisabled = newValue
                }


           
            if !recipe.tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringProvider.localized("tags"))
                        .font(.headline)
                    WrapHStack(tags: recipe.tags.map { $0.name })
                }
            }

        }
    }

    private func ingredientButtons() -> some View {
        Menu {
            Button {
                addIngredientsToShoppingList(onlyCompleted: false)
            } label: {
                Label(LocalizedStringProvider.localized("add_all_ingredients"), systemImage: "cart.badge.plus")
            }
            Button {
                addIngredientsToShoppingList(onlyCompleted: true)
            } label: {
                Label(LocalizedStringProvider.localized("add_selected_ingredients"), systemImage: "checkmark.circle")
            }
        } label: {
            HStack {
                Image(systemName: "cart.badge.plus")
                    .symbolRenderingMode(.hierarchical)
                Text(LocalizedStringProvider.localized("ingredients"))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .alert(isPresented: $showSuccessAlert) {
            Alert(
                title: Text(LocalizedStringProvider.localized("add_ingredients_title")),
                message: Text(LocalizedStringProvider.localized("add_ingredients_message")),
                dismissButton: .default(Text(LocalizedStringProvider.localized("ok")))
            )
        }
    }

    private func ingredientGroup(_ recipe: RecipeDetail) -> some View {
        customDisclosureGroup(
            title: LocalizedStringProvider.localized("ingredients"),
            systemImage: "list.bullet",
            isExpanded: $showIngredients
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text(LocalizedStringProvider.localized("adjust_quantity"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach([0.5, 1.0, 1.5, 2.0, 2.5, 3.0], id: \.self) { factor in
                            quantityMultiplierButton(for: factor)
                        }
                    }
                    .padding(.horizontal, 4)
                }

                // 🚀 Performance: LazyVStack für große Zutatenlisten
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(recipe.ingredients) { ingredient in
                        IngredientRowView(
                            ingredient: ingredient,
                            isCompleted: completedIngredients.contains(ingredient.id),
                            quantityMultiplier: quantityMultiplier,
                            onToggle: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    toggleIngredient(ingredient)
                                }
                            }
                        )
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    /// Button für Mengen-Multiplikator
    private func quantityMultiplierButton(for factor: Double) -> some View {
        let isSelected = quantityMultiplier == factor
        let displayText = factor == floor(factor) ? "\(Int(factor))×" : String(format: "%.1f×", factor)
        
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                quantityMultiplier = factor
            }
        }) {
            Text(displayText)
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(buttonBackground(isSelected: isSelected))
                .foregroundColor(isSelected ? .white : .primary)
                .overlay(buttonOverlay(isSelected: isSelected))
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .shadow(
                    color: isSelected ? Color.accentColor.opacity(0.3) : .clear,
                    radius: isSelected ? 6 : 0,
                    x: 0,
                    y: isSelected ? 3 : 0
                )
        }
        .buttonStyle(.plain)
    }
    
    private func buttonBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isSelected ? Color.accentColor : Color(.systemGray5))
    }
    
    private func buttonOverlay(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(
                isSelected ? Color.accentColor.opacity(0.3) : .clear,
                lineWidth: 2
            )
    }

    // timerButton()
    private func timerButton() -> some View {
        Button(action: {
            showTimerSheet = true
        }) {
            HStack {
                Image(systemName: "timer")
                    .symbolRenderingMode(.hierarchical)
                    .imageScale(.medium)
                Text(timerButtonLabel)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: timerModel.timerActive
                        ? [Color.green, Color.green.opacity(0.8)]
                        : [Color.orange, Color.orange.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(
                color: (timerModel.timerActive ? Color.green : Color.orange).opacity(0.3),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .sheet(isPresented: $showTimerSheet) {
            TimerView(durationMinutes: $timerDurationMinutes, recipeId: recipeId)
                .environmentObject(timerModel)
        }
    }

    // instructionGroup(...)
    private func instructionGroup(_ recipe: RecipeDetail) -> some View {
        customDisclosureGroup(
            title: LocalizedStringProvider.localized("instructions"),
            systemImage: "book",
            isExpanded: $showInstructions
        ) {
            InstructionListView(
                instructions: recipe.instructions,
                completed: completedInstructions,
                toggle: toggleInstruction,
                selectTimer: { minutes in
                    selectedDuration = DurationWrapper(minutes: Double(minutes))
                }
            )
            .sheet(item: $selectedDuration) { wrapper in
                TimerView(durationMinutes: .constant(wrapper.minutes), recipeId: recipeId)
                    .environmentObject(timerModel)
            }
        }
    }



    private var timerButtonLabel: String {
        if timerModel.timerActive {
            let minutes = Int(timerModel.timeRemaining) / 60
            let seconds = Int(timerModel.timeRemaining) % 60
            return String(format: LocalizedStringProvider.localized("running_timer"), minutes, seconds)
        } else {
            return LocalizedStringProvider.localized("start_timer")
        }
    }

    private func buildImageURL(recipeID: String) -> URL? {
        guard let base = APIService.shared.getBaseURL() else { return nil }
        return base
            .appendingPathComponent("api/media/recipes")
            .appendingPathComponent(recipeID)
            .appendingPathComponent("images/original.webp")
    }

    private func resetCompleted() {
        completedIngredients = []
        completedInstructions = []
    }

    private func addIngredientsToShoppingList(onlyCompleted: Bool) {
        guard let recipe = viewModel.recipe else { return }
        let toAdd = onlyCompleted
            ? recipe.ingredients.filter { completedIngredients.contains($0.id) }
            : recipe.ingredients
        shoppingListViewModel.addIngredients(toAdd)
        notificationFeedback.notificationOccurred(.success)
        showSuccessAlert = true
    }

    private func toggleIngredient(_ ingredient: Ingredient) {
        if completedIngredients.contains(ingredient.id) {
            completedIngredients.remove(ingredient.id)
            impactLight.impactOccurred()
        } else {
            completedIngredients.insert(ingredient.id)
            impactMedium.impactOccurred()
        }
    }

    private func toggleInstruction(_ instruction: Instruction) {
        if completedInstructions.contains(instruction.id) {
            completedInstructions.remove(instruction.id)
            impactLight.impactOccurred()
        } else {
            completedInstructions.insert(instruction.id)
            impactMedium.impactOccurred()
        }
    }

    private func scaledNote(for note: String?) -> String {
        guard let note = note else { return "-" }
        let pattern = "^([\\d.,/]+)(\\s?[a-zA-Z]*)?(.*)$"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: note, range: NSRange(note.startIndex..., in: note)) {
            let numberRange = Range(match.range(at: 1), in: note)
            let unitRange = Range(match.range(at: 2), in: note)
            let restRange = Range(match.range(at: 3), in: note)

            if let numberStr = numberRange.map({ String(note[$0]) }) {
                let parsedNumber: Double? = {
                    if numberStr.contains("/") {
                        let parts = numberStr.split(separator: "/").compactMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
                        return parts.count == 2 ? parts[0] / parts[1] : nil
                    } else {
                        return Double(numberStr.replacingOccurrences(of: ",", with: "."))
                    }
                }()

                if let amount = parsedNumber {
                    let newAmount = amount * quantityMultiplier
                    let unit = unitRange.map { String(note[$0]).trimmingCharacters(in: .whitespaces) } ?? ""
                    let rest = restRange.map { String(note[$0]) } ?? ""
                    let formatted = newAmount == floor(newAmount) ? "\(Int(newAmount))" : String(format: "%.2f", newAmount)
                    return "\(formatted) \(unit)\(rest)"
                }
            }
        }
        return note
    }

    @ViewBuilder
    private func recipeTimeAndServingsSummary(_ recipe: RecipeDetail) -> some View {
        let hasTime = recipe.totalTime != nil || recipe.prepTime != nil || recipe.cookTime != nil
        let hasServings = recipe.recipeServings != nil && recipe.recipeServings! > 0
        let hasRating = recipe.rating != nil && recipe.rating! > 0

        if hasTime || hasServings || hasRating {
            VStack(spacing: 12) {
                // ✅ Zeit-Anzeige: Icons oben, Werte unten
                if hasTime {
                    let timeElements = buildTimeElements(from: recipe)
                    
                    if !timeElements.isEmpty {
                        VStack(spacing: 4) {
                            // Erste Zeile: Alle Icons
                            HStack(spacing: 16) {
                                ForEach(Array(timeElements.enumerated()), id: \.offset) { _, element in
                                    Image(systemName: element.icon)
                                        .font(.title3)
                                        .foregroundColor(.accentColor)
                                        .frame(minWidth: 40)
                                }
                            }
                            
                            // Zweite Zeile: Alle Zeitwerte
                            HStack(spacing: 16) {
                                ForEach(Array(timeElements.enumerated()), id: \.offset) { _, element in
                                    Text(element.value)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .frame(minWidth: 40)
                                }
                            }
                        }
                    }
                }
                
                // ✅ Portionen & Bewertung
                if hasServings || hasRating {
                    HStack(spacing: 30) {
                        // Portionen
                        if hasServings {
                            if let scaled = scaledServings(for: recipe.recipeServings) {
                                servingsItem(value: scaled, horizontalSizeClass: horizontalSizeClass)
                            }
                        }
                        
                        // Bewertung
                        if hasRating, let rating = recipe.rating {
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    ForEach(0..<5) { index in
                                        Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                            .font(.title3)
                                            .foregroundColor(.orange)
                                    }
                                }
                                
                                Text(String(format: "%.0f/5", rating))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private func servingsItem(value: Int, horizontalSizeClass: UserInterfaceSizeClass?) -> some View {
        let isCompact = horizontalSizeClass == .compact

        return VStack(spacing: 4) {
            Image(systemName: "person.2")
                .font(isCompact ? .title3 : .title2)
                .foregroundColor(.accentColor)

            Text("\(value)")
                .font(isCompact ? .footnote : .body)

            Text(LocalizedStringProvider.localized("servings"))
                .font(isCompact ? .caption2 : .caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(minWidth: 60, maxWidth: .infinity)
    }

    private func scaledServings(for baseServings: Double?) -> Int? {
        guard let base = baseServings, base > 0 else { return nil }
        let scaled = base * quantityMultiplier
        return Int(scaled.rounded())
    }

    /// Formatiert Minuten in ein lesbares Format (z.B. "1h 45min" oder "45min")
    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)min"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)min"
    }



    
    private func customDisclosureGroup<Content: View>(
        title: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation { isExpanded.wrappedValue.toggle() }
            }) {
                HStack {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .foregroundColor(.accentColor)
                        .imageScale(.small)
                    Label(title, systemImage: systemImage)
                        .font(.title3)
                        .bold()
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(12)
            }

            if isExpanded.wrappedValue {
                content()
                    .transition(.opacity)
                    .padding(.top, 8)
            }
        }
    }

    private func deleteRecipe() async {
        do {
            try await APIService.shared.deleteRecipe(recipeId: recipeId)
            dismiss()
        } catch {
            logMessage("Fehler beim Löschen: \(error.localizedDescription)")
        }
    }
}

struct AuthenticatedAsyncImage: View {
    let url: URL
    let token: String

    @State private var phase: AsyncImagePhase = .empty

    var body: some View {
        switch phase {
        case .empty:
            ProgressView().task { await load() }
        case .success(let image):
            image.resizable().scaledToFill()
        case .failure:
            Image(systemName: "photo")
                .resizable().scaledToFit()
                .foregroundColor(.gray)
        @unknown default:
            EmptyView()
        }
    }

    @MainActor
    private func load() async {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let host = APIService.shared.getBaseURL()?.host,
           !host.hasPrefix("192.168."),
           !host.hasPrefix("10."),
           !host.hasPrefix("127."),
           !host.hasPrefix("172.") {
            for (key, value) in APIService.shared.getOptionalHeaders where !key.isEmpty && !value.isEmpty {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let uiImage = UIImage(data: data) else {
                phase = .failure(URLError(.badServerResponse))
                return
            }
            phase = .success(Image(uiImage: uiImage))
        } catch {
            phase = .failure(error)
        }
    }
}

struct WrapHStack: View {
    let tags: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(6)
            }
        }
    }
}

struct TimeParser {
    struct ParsedTime: Identifiable, Equatable {
        let id = UUID()
        let minutes: Int
    }

    static func parse(from text: String) -> [ParsedTime] {
        let patterns = [
            #"\b(\d{1,2})\s?(?:stunden?|hours?|heures?|horas?)\b"#,
            #"\b(\d{1,3})\s?(?:min\.?|minuten?|minutes?|minutos?)\b"#
        ]

        var totalMinutes: [Int] = []

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
                let matches = regex.matches(in: text, options: [], range: nsrange)

                for match in matches {
                    if let range = Range(match.range(at: 1), in: text),
                       let value = Int(text[range]) {
                        if pattern.contains("stunden") || pattern.contains("hours") || pattern.contains("heures") || pattern.contains("horas") {
                            totalMinutes.append(value * 60)
                        } else {
                            totalMinutes.append(value)
                        }
                    }
                }
            }
        }

        let uniqueMinutes = Array(Set(totalMinutes)).sorted()
        return uniqueMinutes.map { ParsedTime(minutes: $0) }
    }
}

// MARK: - IngredientRowView (Optimiert für Performance)
/// Separate View-Komponente für eine Zutat - verbessert Rendering-Performance
struct IngredientRowView: View {
    let ingredient: Ingredient
    let isCompleted: Bool
    let quantityMultiplier: Double
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Moderne Checkbox
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isCompleted ? .green : .secondary)
                    .symbolRenderingMode(.hierarchical)
                
                // Zutat-Informationen
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayText)
                        .font(.body)
                        .strikethrough(isCompleted)
                        .foregroundColor(isCompleted ? .secondary : .primary)
                    
                    // Note falls vorhanden
                    if ingredient.hasNote, let noteText = ingredient.note {
                        Label(noteText, systemImage: "note.text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 2)
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isCompleted ? Color.green.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isCompleted ? Color.green.opacity(0.3) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    /// Berechnet den Display-Text mit Skalierung
    private var displayText: String {
        var parts: [String] = []
        
        // 1. Menge hinzufügen (mit Skalierung)
        if let quantity = ingredient.quantity {
            let scaledQuantity = quantity * quantityMultiplier
            parts.append(QuantityParser.formatQuantity(scaledQuantity))
        }
        
        // 2. Einheit hinzufügen
        if let unit = ingredient.unit, !unit.isEmpty {
            parts.append(unit)
        }
        
        // 3. Zutat/Name hinzufügen
        if let food = ingredient.food, !food.isEmpty {
            parts.append(food)
        }
        
        let result = parts.joined(separator: " ")
        return result.isEmpty ? "-" : result
    }
}

// MARK: - InstructionListView (Optimiert mit LazyVStack)
struct InstructionListView: View {
    let instructions: [Instruction]
    let completed: Set<UUID>
    let toggle: (Instruction) -> Void
    let selectTimer: (Int) -> Void

    var body: some View {
        // 🚀 Performance: LazyVStack für große Instruktionslisten
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(instructions) { instruction in
                InstructionRowView(
                    instruction: instruction,
                    isCompleted: completed.contains(instruction.id),
                    onToggle: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            toggle(instruction)
                        }
                    },
                    onSelectTimer: selectTimer
                )
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - InstructionRowView (Separate Komponente für Performance)
struct InstructionRowView: View {
    let instruction: Instruction
    let isCompleted: Bool
    let onToggle: () -> Void
    let onSelectTimer: (Int) -> Void
    
    // Berechne Timer nur einmal
    private var parsedTimes: [TimeParser.ParsedTime] {
        TimeParser.parse(from: instruction.text)
    }
    
    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .center, spacing: 14) {
                // Moderne Checkbox für Instruktionen
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isCompleted ? .green : .secondary)
                    .symbolRenderingMode(.hierarchical)
                
                Text(instruction.text)
                    .font(.body)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !parsedTimes.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(parsedTimes) { parsed in
                            TimerChipButton(minutes: parsed.minutes, action: {
                                onSelectTimer(parsed.minutes)
                            })
                        }
                    }
                }
            }
            .padding(14)
            .frame(minHeight: parsedTimes.isEmpty ? nil : 60)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isCompleted ? Color.green.opacity(0.08) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isCompleted ? Color.green.opacity(0.3) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - TimerChipButton (Wiederverwendbare Komponente)
struct TimerChipButton: View {
    let minutes: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.caption)
                Text("\(minutes)'")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange, Color.orange.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: Color.orange.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}





