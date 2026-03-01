import SwiftUI
import Kingfisher

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

// MARK: - Sort Options
enum RecipeSortOption: String, CaseIterable, Identifiable {
    case nameAscending = "name_ascending"
    case nameDescending = "name_descending"
    case dateNewest = "date_newest"
    case dateOldest = "date_oldest"
    case prepTimeShort = "prep_time_short"
    case prepTimeLong = "prep_time_long"
    case ratingHighest = "rating_highest"
    case ratingLowest = "rating_lowest"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .nameAscending:
            return LocalizedStringProvider.localized("sort_name_a_z")
        case .nameDescending:
            return LocalizedStringProvider.localized("sort_name_z_a")
        case .dateNewest:
            return LocalizedStringProvider.localized("sort_date_newest")
        case .dateOldest:
            return LocalizedStringProvider.localized("sort_date_oldest")
        case .prepTimeShort:
            return LocalizedStringProvider.localized("sort_prep_time_short")
        case .prepTimeLong:
            return LocalizedStringProvider.localized("sort_prep_time_long")
        case .ratingHighest:
            return LocalizedStringProvider.localized("sort_rating_highest")
        case .ratingLowest:
            return LocalizedStringProvider.localized("sort_rating_lowest")
        }
    }
    
    var icon: String {
        switch self {
        case .nameAscending:
            return "arrow.up.circle"
        case .nameDescending:
            return "arrow.down.circle"
        case .dateNewest:
            return "calendar.badge.plus"
        case .dateOldest:
            return "calendar"
        case .prepTimeShort:
            return "clock"
        case .prepTimeLong:
            return "clock.fill"
        case .ratingHighest:
            return "star.fill"
        case .ratingLowest:
            return "star"
        }
    }
}

struct RecipeListView: View {
    @StateObject private var viewModel = RecipeListViewModel()
    let settings = AppSettings.shared
    @State private var searchText = ""
    @State private var selectedCategories: Set<Category> = []
    @State private var selectedTags: Set<RecipeTag> = []
    @State private var selectedSortOption: RecipeSortOption = .nameAscending
    @State private var showSortMenu = false

    // Alle Tags aus den Rezepten (RecipeDetail)
    var allTags: [RecipeTag] {
        let all = viewModel.allRecipes.flatMap { $0.tags }
        let unique = Dictionary(grouping: all, by: { $0.id }).compactMap { $0.value.first }
        return unique.sorted(by: { $0.name < $1.name })
    }

    // Nur Kategorien, die in mindestens einem Rezept vorkommen (als Array)
    var usedCategories: [Category] {
        let recipeCatIds = Set(viewModel.allRecipes.flatMap { $0.recipeCategory.map { $0.id } })
        return viewModel.categories.filter { recipeCatIds.contains($0.id) }
    }

    // Gefilterte Rezepte (RecipeDetail)
    var filteredRecipes: [RecipeDetail] {
        let filtered = viewModel.allRecipes.filter { recipe in
            let matchesSearch = searchText.isEmpty ||
                recipe.name.localizedCaseInsensitiveContains(searchText) ||
                recipe.tags.contains(where: { $0.name.localizedCaseInsensitiveContains(searchText) })

            // Mindestens eine Kategorie muss matchen (wenn gewählt)
            let matchesCategory = selectedCategories.isEmpty ||
                recipe.recipeCategory.contains(where: { selectedCategories.contains($0) })

            // Mindestens ein Tag muss matchen (wenn gewählt)
            let matchesTag = selectedTags.isEmpty ||
                recipe.tags.contains(where: { selectedTags.contains($0) })

            return matchesSearch && matchesCategory && matchesTag
        }
        
        // Sortierung anwenden
        return sortRecipes(filtered, by: selectedSortOption)
    }
    
    // MARK: - Sorting Logic
    private func sortRecipes(_ recipes: [RecipeDetail], by option: RecipeSortOption) -> [RecipeDetail] {
        switch option {
        case .nameAscending:
            return recipes.sorted { (recipe1: RecipeDetail, recipe2: RecipeDetail) -> Bool in
                recipe1.name.localizedCaseInsensitiveCompare(recipe2.name) == .orderedAscending
            }
        case .nameDescending:
            return recipes.sorted { (recipe1: RecipeDetail, recipe2: RecipeDetail) -> Bool in
                recipe1.name.localizedCaseInsensitiveCompare(recipe2.name) == .orderedDescending
            }
        case .dateNewest:
            return recipes.sorted { (recipe1: RecipeDetail, recipe2: RecipeDetail) -> Bool in
                // Nutze createdAt als primäres Datum (wann wurde das Rezept erstellt)
                // Fallback-Kette: createdAt → dateAdded → dateUpdated
                let date1 = recipe1.createdAt ?? recipe1.dateAdded ?? recipe1.dateUpdated ?? Date.distantPast
                let date2 = recipe2.createdAt ?? recipe2.dateAdded ?? recipe2.dateUpdated ?? Date.distantPast
                
                #if DEBUG
                if date1 == Date.distantPast && date2 == Date.distantPast {
                    logMessage("⚠️ Beide Rezepte haben kein Datum: \(recipe1.name) vs \(recipe2.name)")
                } else if date1 != Date.distantPast && date2 != Date.distantPast {
                    logMessage("✅ Sortiere mit Datum: \(recipe1.name) (\(date1)) vs \(recipe2.name) (\(date2))")
                }
                #endif
                
                return date1 > date2
            }
        case .dateOldest:
            return recipes.sorted { (recipe1: RecipeDetail, recipe2: RecipeDetail) -> Bool in
                // Nutze createdAt als primäres Datum (wann wurde das Rezept erstellt)
                // Fallback-Kette: createdAt → dateAdded → dateUpdated
                let date1 = recipe1.createdAt ?? recipe1.dateAdded ?? recipe1.dateUpdated ?? Date.distantPast
                let date2 = recipe2.createdAt ?? recipe2.dateAdded ?? recipe2.dateUpdated ?? Date.distantPast
                
                return date1 < date2
            }
        case .prepTimeShort:
            return recipes.sorted { (recipe1: RecipeDetail, recipe2: RecipeDetail) -> Bool in
                let time1 = recipe1.prepTime ?? Int.max
                let time2 = recipe2.prepTime ?? Int.max
                return time1 < time2
            }
        case .prepTimeLong:
            return recipes.sorted { (recipe1: RecipeDetail, recipe2: RecipeDetail) -> Bool in
                let time1 = recipe1.prepTime ?? 0
                let time2 = recipe2.prepTime ?? 0
                return time1 > time2
            }
        case .ratingHighest:
            return recipes.sorted { (recipe1: RecipeDetail, recipe2: RecipeDetail) -> Bool in
                // Höchste Bewertung zuerst (5 Sterne vor 1 Stern)
                let rating1 = recipe1.rating ?? 0.0
                let rating2 = recipe2.rating ?? 0.0
                
                // Wenn Bewertungen gleich sind, alphabetisch nach Name sortieren
                if rating1 == rating2 {
                    return recipe1.name.localizedCaseInsensitiveCompare(recipe2.name) == .orderedAscending
                }
                
                return rating1 > rating2
            }
        case .ratingLowest:
            return recipes.sorted { (recipe1: RecipeDetail, recipe2: RecipeDetail) -> Bool in
                // Niedrigste Bewertung zuerst (1 Stern vor 5 Sterne)
                let rating1 = recipe1.rating ?? 0.0
                let rating2 = recipe2.rating ?? 0.0
                
                // Wenn Bewertungen gleich sind, alphabetisch nach Name sortieren
                if rating1 == rating2 {
                    return recipe1.name.localizedCaseInsensitiveCompare(recipe2.name) == .orderedAscending
                }
                
                return rating1 < rating2
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Kategorien-Leiste (horizontal) mit verbessertem Design
                if !usedCategories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            FilterChip(
                                title: LocalizedStringProvider.localized("all_categories"),
                                icon: "square.grid.2x2",
                                isSelected: selectedCategories.isEmpty
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedCategories.removeAll()
                                }
                            }
                            
                            ForEach(usedCategories, id: \.id) { cat in
                                FilterChip(
                                    title: cat.name,
                                    icon: "tag.fill",
                                    isSelected: selectedCategories.contains(cat)
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if selectedCategories.contains(cat) {
                                            selectedCategories.remove(cat)
                                        } else {
                                            selectedCategories.insert(cat)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                // Tags-Leiste (horizontal) mit verbessertem Design
                if !allTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            FilterChip(
                                title: LocalizedStringProvider.localized("all"),
                                icon: "tag",
                                isSelected: selectedTags.isEmpty
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTags.removeAll()
                                }
                            }
                            
                            ForEach(allTags, id: \.id) { tag in
                                FilterChip(
                                    title: tag.name,
                                    icon: "tag.fill",
                                    isSelected: selectedTags.contains(tag)
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if selectedTags.contains(tag) {
                                            selectedTags.remove(tag)
                                        } else {
                                            selectedTags.insert(tag)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                // 🚀 Performance: LazyVStack für Rezepte-Liste mit On-Demand-Loading
                if viewModel.isLoading {
                    ProgressView(LocalizedStringProvider.localized("loading_recipes"))
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let errorMessage = viewModel.errorMessage {
                    Text(String(format: LocalizedStringProvider.localized("error_loading_recipes"), errorMessage))
                        .foregroundColor(.red)
                } else {
                    if filteredRecipes.isEmpty && (!selectedCategories.isEmpty || !selectedTags.isEmpty) {
                        VStack(spacing: 16) {
                            Image(systemName: "tray")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                                .symbolRenderingMode(.hierarchical)
                            
                            Text(LocalizedStringProvider.localized("no_recipes_for_category"))
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Button {
                                withAnimation {
                                    selectedCategories.removeAll()
                                    selectedTags.removeAll()
                                }
                            } label: {
                                Label("Filter zurücksetzen", systemImage: "arrow.counterclockwise")
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                        .listRowSeparator(.hidden)
                    } else {
                        // 🚀 LazyVStack ermöglicht On-Demand-Rendering
                        ForEach(filteredRecipes) { recipe in
                            NavigationLink(destination: RecipeDetailView(recipeId: UUID(uuidString: recipe.id)!)) {
                                RecipeRowView(recipe: recipe, showImage: settings.showRecipeImages)
                            }
                            .id(recipe.id) // Explizite ID für bessere Performance
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: Text(LocalizedStringProvider.localized("search_recipe")))
            .navigationTitle(LocalizedStringProvider.localized("recipes"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Sortier-Menü mit verbessertem Icon-Feedback
                        Menu {
                            ForEach(RecipeSortOption.allCases) { option in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedSortOption = option
                                    }
                                } label: {
                                    Label {
                                        Text(option.displayName)
                                    } icon: {
                                        Image(systemName: option.icon)
                                            .symbolRenderingMode(.hierarchical)
                                    }
                                    if selectedSortOption == option {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .symbolRenderingMode(.multicolor)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .symbolEffect(.bounce, value: selectedSortOption)
                                .imageScale(.large)
                        }
                        .accessibilityLabel(LocalizedStringProvider.localized("sort_recipes"))
                        
                        // Refresh Button
                        Button {
                            viewModel.clearCacheAndReload()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel(LocalizedStringProvider.localized("refresh_recipes"))
                    }
                }
            }
            .onAppear {
                configureAPIIfNeeded()
                viewModel.loadCachedOrFetchRecipes()
                viewModel.fetchCategories()
            }
        }
    }

    private func configureAPIIfNeeded() {
        guard let url = URL(string: settings.serverURL), !settings.token.isEmpty else {
            logMessage("[RecipeListView] Fehler: Ungültige Einstellungen")
            return
        }
        APIService.shared.configure(baseURL: url, token: settings.token)
    }
}

// MARK: - Bild-URL Hilfsfunktion
extension RecipeListView {
    /// Baut die Bild-URL für ein Rezept (wie in RecipeDetailView)
    func buildImageURL(recipeID: String) -> URL? {
        guard let base = APIService.shared.getBaseURL() else {
            logMessage("⚠️ Keine Base-URL für Bild: \(recipeID)")
            return nil
        }
        
        // Standard-Mealie-Bild-URL (wie in RecipeDetailView)
        let url = base
            .appendingPathComponent("api/media/recipes")
            .appendingPathComponent(recipeID)
            .appendingPathComponent("images/original.webp")
        
        logMessage("🔄 Konstruierte Bild-URL: \(url.absoluteString)")
        return url
    }
    
    /// Alternative: Sucht nach Bild-Feldern in RecipeDetail
    func extractImageUrl(from recipe: RecipeDetail) -> URL? {
        // 1. Versuche die Standard-Mealie-URL
        if let standardUrl = buildImageURL(recipeID: recipe.id) {
            return standardUrl
        }
        
        // 2. Prüfe, ob es ein direktes Bild-Feld gibt
        let mirror = Mirror(reflecting: recipe)
        
        for child in mirror.children {
            if let label = child.label?.lowercased(),
               (label.contains("image") || label.contains("picture") || label.contains("photo")) {
                
                logMessage("🔍 Bild-Feld gefunden: '\(label)' in \(recipe.name)")
                
                // Wenn es ein String-Feld ist
                if let stringValue = child.value as? String, !stringValue.isEmpty {
                    if stringValue.starts(with: "http") {
                        return URL(string: stringValue)
                    }
                }
            }
        }
        
        return nil
    }
}

// MARK: - Separate View für die Rezept-Zeile mit verbessertem Design & Performance
struct RecipeRowView: View {
    let recipe: RecipeDetail
    let showImage: Bool
    
    // 🚀 Cache berechnete Werte für bessere Performance
    private var imageUrl: URL? {
        buildImageUrl(for: recipe)
    }
    
    private var displayPrepTime: Int? {
        recipe.prepTime
    }
    
    private var displayCookTime: Int? {
        recipe.cookTime
    }
    
    private var displayTotalTime: Int? {
        recipe.totalTime
    }
    
    private var displayServings: Int? {
        guard let servings = recipe.recipeServings, servings > 0 else { return nil }
        return Int(servings)
    }
    
    private var displayRating: Double? {
        guard let rating = recipe.rating, rating > 0 else { return nil }
        return rating
    }
    
    private var visibleTags: ArraySlice<RecipeTag> {
        recipe.tags.prefix(3)
    }
    
    private var remainingTagsCount: Int {
        max(0, recipe.tags.count - 3)
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // 🌄 Bild anzeigen, wenn Einstellung aktiviert
            if showImage {
                if let imageUrl = imageUrl {
                    CachedImageView(imageUrl: imageUrl, recipeName: recipe.name)
                } else {
                    PlaceholderImageView(recipeName: recipe.name)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(recipe.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                // Metadaten (Zeit & Portionen) kompakt
                if displayPrepTime != nil || displayCookTime != nil || displayTotalTime != nil || displayServings != nil {
                    HStack(spacing: 12) {
                        // Vorbereitungszeit (Messer)
                        if let prepTime = displayPrepTime {
                            Label(formatMinutes(prepTime), systemImage: "fork.knife")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Kochzeit (Kochtopf)
                        if let cookTime = displayCookTime {
                            Label(formatMinutes(cookTime), systemImage: "flame.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Gesamtzeit (Uhr)
                        if let totalTime = displayTotalTime {
                            Label(formatMinutes(totalTime), systemImage: "clock.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Portionen
                        if let servings = displayServings {
                            Label("\(servings)", systemImage: "person.2.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Bewertung in separater Zeile
                if let rating = displayRating {
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        Text(String(format: "%.0f", rating))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Tags kompakter darstellen
                if !recipe.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 6) {
                            ForEach(visibleTags, id: \.id) { tag in
                                TagChipView(tagName: tag.name)
                            }
                            
                            if remainingTagsCount > 0 {
                                Text("+\(remainingTagsCount)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }
    
    /// Baut die Bild-URL für dieses spezifische Rezept
    private func buildImageUrl(for recipe: RecipeDetail) -> URL? {
        guard let base = APIService.shared.getBaseURL() else {
            return nil
        }
        
        // Genau die gleiche Logik wie in RecipeDetailView
        let url = base
            .appendingPathComponent("api/media/recipes")
            .appendingPathComponent(recipe.id)
            .appendingPathComponent("images/original.webp")
        
        return url
    }
    
    /// Formatiert Minuten in lesbares Format (z.B. "1h 45min" oder "45min")
    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)min"
    }
}

// MARK: - Optimierte Tag-Chip View
struct TagChipView: View {
    let tagName: String
    
    var body: some View {
        Text(tagName)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.12))
            )
            .foregroundColor(.accentColor)
    }
}

// MARK: - Cached Image View (Optimiert)
struct CachedImageView: View {
    let imageUrl: URL
    let recipeName: String
    
    var body: some View {
        KFImage(imageUrl)
            .placeholder {
                ProgressView()
                    .frame(width: 50, height: 50)
            }
            .onFailure { error in
                #if DEBUG
                logMessage("❌ Bild-Ladefehler für \(recipeName): \(error.localizedDescription)")
                #endif
            }
            .onSuccess { _ in
                #if DEBUG
                logMessage("✅ Bild erfolgreich geladen für: \(recipeName)")
                #endif
            }
            .resizable()
            .scaledToFill()
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Placeholder Image View (Optimiert)
struct PlaceholderImageView: View {
    let recipeName: String
    
    var body: some View {
        Image(systemName: "photo")
            .resizable()
            .scaledToFit()
            .frame(width: 50, height: 50)
            .foregroundColor(.gray.opacity(0.3))
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Filter Chip Component
/// Moderne, wiederverwendbare Filter-Chip Komponente mit Icons und Animationen
struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2)
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color(.systemGray5))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(
                color: isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
                radius: isSelected ? 4 : 0,
                x: 0,
                y: isSelected ? 2 : 0
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.0 : 0.98)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
