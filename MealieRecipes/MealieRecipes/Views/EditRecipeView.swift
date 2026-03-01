import SwiftUI
import PhotosUI

// MARK: - CHIP & WRAP

struct ChipView: View {
    let label: String
    var selected: Bool = false
    var body: some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selected ? Color.green.opacity(0.85) : Color.gray.opacity(0.17))
            .foregroundColor(selected ? .white : .primary)
            .cornerRadius(8)
            .animation(.easeInOut(duration: 0.13), value: selected)
    }
}

struct ChipRow<Item: Identifiable & Hashable>: View {
    let items: [Item]
    let display: (Item) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.id) { item in
                    ChipView(label: display(item), selected: true)
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        }
    }
}

struct ChipGrid<Item: Identifiable & Hashable>: View {
    let items: [Item]
    let selected: Set<Item>
    let onTap: (Item) -> Void
    let display: (Item) -> String

    var columns: [GridItem] = [
        GridItem(.adaptive(minimum: 110), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items, id: \.id) { item in
                Button {
                    onTap(item)
                } label: {
                    ChipView(label: display(item), selected: selected.contains(item))
                        .frame(minWidth: 80)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - EDIT VIEW

struct EditRecipeView: View {
    let originalSlug: String
    @State var recipe: RecipeDetail
    @State var allTags: [RecipeTag]
    @State var allCategories: [Category]
    var onSave: (RecipeDetail) -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.locale) var locale

    @State private var selectedTags: Set<RecipeTag> = []
    @State private var selectedCategories: Set<Category> = []
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    @FocusState private var focusedIngredientIndex: Int?
    @FocusState private var focusedInstructionIndex: Int?

    @State private var showIngredients = false  // ✅ 4️⃣ Standardmäßig eingeklappt
    @State private var showInstructions = false  // ✅ 4️⃣ Standardmäßig eingeklappt
    @State private var showMetadata = false
    @State private var showOrganization = false

    @State private var selectedUIImage: UIImage? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var imageUploading = false
    @State private var imageUploadError: String? = nil
    @State private var newImageUrl: URL? = nil

    @State private var showImageChangeWarning = false
    @State private var pendingPhotoItem: PhotosPickerItem? = nil
    
    @ObservedObject private var autocompleteCache = IngredientAutocompleteCache.shared
    
    // Keyboard Management
    @FocusState private var keyboardFocused: Bool
    
    // Haptic Feedback
    private let hapticImpact = UIImpactFeedbackGenerator(style: .light)
    private let hapticNotification = UINotificationFeedbackGenerator()
    
    // Unsaved Changes & Loading
    @State private var hasUnsavedChanges = false
    @State private var showDiscardAlert = false
    @State private var isSaving = false
    
    // Validation
    @State private var validationErrors: [String] = []
    
    // ✅ NEU: Speichere Original-Zeitwerte & Rating für Vergleich
    @State private var originalPrepTime: Int?
    @State private var originalCookTime: Int?
    @State private var originalTotalTime: Int?
    @State private var originalRating: Double?

    var body: some View {
        mainContent
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(localized("editRecipe"))
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(hasUnsavedChanges)
            .toolbar { 
                keyboardToolbar
                navigationToolbar
            }
            .onAppear { setupView() }
            .onChange(of: recipe.name) { _, _ in markAsChanged() }
            .onChange(of: recipe.description) { _, _ in markAsChanged() }
            .onChange(of: recipe.ingredients.count) { _, _ in markAsChanged() }
            .onChange(of: recipe.instructions.count) { _, _ in markAsChanged() }
            .onChange(of: selectedTags) { _, _ in markAsChanged() }
            .onChange(of: selectedCategories) { _, _ in markAsChanged() }
            .onChange(of: selectedPhotoItem) { _, newValue in handlePhotoSelection(newValue) }
            .alert(isPresented: $showAlert) { mainAlert }
            .confirmationDialog(
                localized("changeImageWarningTitle"),
                isPresented: $showImageChangeWarning,
                titleVisibility: .visible,
                actions: { imageWarningActions },
                message: { Text(localized("changeImageWarningMessage")) }
            )
            .alert(
                localized("unsavedChanges"),
                isPresented: $showDiscardAlert,
                actions: { discardAlertActions },
                message: { Text(localized("unsavedChangesMessage")) }
            )
    }
    
    // MARK: - Body Components
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Validation Error Banner (wenn vorhanden)
            if !validationErrors.isEmpty {
                validationErrorBanner
            }
            
            contentScrollView
        }
    }
    
    private var validationErrorBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(validationErrors, id: \.self) { error in
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.primary)
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private var contentScrollView: some View {
        ScrollView {
            VStack(spacing: 16) {
                basicInfoSection
                metadataDisclosure
                ingredientsDisclosure
                instructionsDisclosure
                organizationDisclosure
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }
    
    // MARK: - Basic Info Section
    
    private var basicInfoSection: some View {
        VStack(spacing: 12) {
            imagePickerCard
            titleField
            descriptionField
        }
    }
    
    private var imagePickerCard: some View {
        ZStack(alignment: .topTrailing) {
            recipeImageView
            
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.accentColor, in: Circle())
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .padding(12)
            }
        }
        .frame(height: 200)
    }
    
    @ViewBuilder
    private var recipeImageView: some View {
        if let selectedUIImage {
            Image(uiImage: selectedUIImage)
                .resizable()
                .scaledToFill()
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
                )
        } else if let url = buildImageURL(recipeID: recipe.id) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } placeholder: {
                imagePlaceholder
            }
        } else {
            imagePlaceholder
        }
    }
    
    private var imagePlaceholder: some View {
        ZStack {
            Color.secondary.opacity(0.15)
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text(localized("tapToAddPhoto"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var titleField: some View {
        VStack(alignment: .leading, spacing: 4) {
            if recipe.name.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(localized("titleRequired"))
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 4)
            }
            
            TextField(localized("title"), text: $recipe.name)
                .font(.title2.bold())
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(recipe.name.isEmpty ? Color.orange : Color.clear, lineWidth: 2)
                )
        }
    }
    
    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(localized("description"), systemImage: "text.alignleft")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            ZStack(alignment: .topLeading) {
                if (recipe.description ?? "").isEmpty {
                    Text(localized("descriptionPlaceholder"))
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
                
                if #available(iOS 16.0, *) {
                    TextEditor(text: $recipe.description.bound)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 80, maxHeight: 120)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                } else {
                    TextEditor(text: $recipe.description.bound)
                        .frame(minHeight: 80, maxHeight: 120)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Disclosure Sections
    
    private var metadataDisclosure: some View {
        customDisclosureGroup(
            title: localized("servings"),
            systemImage: "clock",
            isExpanded: $showMetadata,
            badge: metadataBadge
        ) { servingsTimeCard }
    }
    
    private var metadataBadge: String? {
        var parts: [String] = []
        if let servings = recipe.recipeServings, servings > 0 {
            parts.append("\(Int(servings))")
        }
        if let time = recipe.totalTime, time > 0 {
            parts.append(formatMinutesShort(time))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
    
    private var ingredientsDisclosure: some View {
        customDisclosureGroup(
            title: localized("ingredients"),
            systemImage: "leaf",
            isExpanded: $showIngredients,
            badge: recipe.ingredients.isEmpty ? nil : "\(recipe.ingredients.count)"
        ) { ingredientsCard }
    }
    
    private var instructionsDisclosure: some View {
        customDisclosureGroup(
            title: localized("instructions"),
            systemImage: "list.number",
            isExpanded: $showInstructions,
            badge: recipe.instructions.isEmpty ? nil : "\(recipe.instructions.count)"
        ) { instructionsCard }
    }
    
    private var organizationDisclosure: some View {
        customDisclosureGroup(
            title: localized("organization"),
            systemImage: "tag",
            isExpanded: $showOrganization,
            badge: organizationBadge
        ) { organizationCard }
    }
    
    private var organizationBadge: String? {
        let total = selectedTags.count + selectedCategories.count
        return total > 0 ? "\(total)" : nil
    }
    
    // MARK: - Metadata Card (Servings & Time)
    
    private var servingsTimeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Servings
            VStack(alignment: .leading, spacing: 8) {
                Label(localized("servings"), systemImage: "person.2")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                
                HStack {
                    TextField(localized("servingsHint"), value: $recipe.recipeServings.boundDouble, formatter: NumberFormatter())
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    
                    Text(localized("portionUnit"))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            
            Divider()
            
            // Prep Time (Vorbereitung - Messer)
            timeInputField(
                icon: "fork.knife",
                title: localized("prep_time"),
                binding: $recipe.prepTime.boundInt,
                value: recipe.prepTime
            )
            
            Divider()
            
            // Cook Time (Kochzeit - Kochtopf)
            timeInputField(
                icon: "flame.fill",
                title: localized("cook_time"),
                binding: $recipe.cookTime.boundInt,
                value: recipe.cookTime
            )
            
            Divider()
            
            // Total Time (Gesamtzeit - Uhr)
            timeInputField(
                icon: "clock.fill",
                title: localized("total_time_label"),
                binding: $recipe.totalTime.boundInt,
                value: recipe.totalTime
            )
            
            Divider()
            
            // Rating (Bewertung - Sterne)
            ratingInputField()
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(16)
    }
    
    private func timeInputField(icon: String, title: String, binding: Binding<Int>, value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                Spacer()
                if let time = value, time > 0 {
                    Text(formatMinutes(time))
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(8)
                }
            }
            
            HStack {
                TextField(title, value: binding, formatter: intFormatter())
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                
                Text("min")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
    }
    
    private func ratingInputField() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.orange)
                Text(localized("rating"))
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                Spacer()
                if let rating = recipe.rating, rating > 0 {
                    Text(String(format: "%.0f", rating))
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(8)
                }
            }
            
            HStack(spacing: 16) {
                // Sterne-Auswahl (nur ganze Sterne)
                HStack(spacing: 8) {
                    ForEach(0..<5) { index in
                        Button {
                            let currentRating = Int(recipe.rating ?? 0)
                            let starValue = index + 1
                            
                            // Toggle: Wenn bereits gesetzt, lösche; sonst setze
                            if currentRating == starValue {
                                recipe.rating = 0
                            } else {
                                recipe.rating = Double(starValue)
                            }
                            markAsChanged()
                            hapticImpact.impactOccurred()
                        } label: {
                            let currentRating = Int(recipe.rating ?? 0)
                            let starValue = index + 1
                            
                            Image(systemName: currentRating >= starValue ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                // Zurücksetzen-Button
                if recipe.rating != nil && recipe.rating! > 0 {
                    Button {
                        recipe.rating = nil
                        markAsChanged()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(localized("cancel")) {
                if hasUnsavedChanges {
                    showDiscardAlert = true
                } else {
                    dismiss()
                }
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                saveRecipe()
            } label: {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Text(localized("save"))
                        .bold()
                }
            }
            .disabled(isSaving || !isValid)
        }
    }
    
    @ToolbarContentBuilder
    private var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button(localized("done")) {
                hideKeyboard()
            }
            .fontWeight(.semibold)
        }
    }
    
    private var mainAlert: Alert {
        Alert(
            title: Text(alertTitle),
            message: Text(alertMessage),
            dismissButton: .default(Text(localized("ok"))) {
                if alertTitle == localized("saveSuccessTitle") {
                    dismiss()
                }
            }
        )
    }
    
    @ViewBuilder
    private var imageWarningActions: some View {
        Button(localized("confirm"), role: .destructive) {
            Task {
                if let item = pendingPhotoItem,
                    let data = try? await item.loadTransferable(type: Data.self),
                    let uiImage = UIImage(data: data) {
                    selectedUIImage = uiImage
                }
                pendingPhotoItem = nil
            }
        }
        Button(localized("cancel"), role: .cancel) {
            selectedPhotoItem = nil
            pendingPhotoItem = nil
        }
    }
    
    @ViewBuilder
    private var discardAlertActions: some View {
        Button(localized("discard"), role: .destructive) {
            dismiss()
        }
        Button(localized("keepEditing"), role: .cancel) {}
    }
    
    // MARK: - Setup & Handlers
    
    private func setupView() {
        selectedTags = Set(recipe.tags)
        selectedCategories = Set(recipe.recipeCategory)
        migrateIngredients()
        
        // ✅ NEU: Speichere Original-Zeitwerte & Rating für späteren Vergleich
        originalPrepTime = recipe.prepTime
        originalCookTime = recipe.cookTime
        originalTotalTime = recipe.totalTime
        originalRating = recipe.rating
        
        // ✅ Lade Units und Foods vom Server für Autocomplete
        Task {
            do {
                try await autocompleteCache.preloadAll()
                #if DEBUG
                print("✅ Units & Foods geladen für Autocomplete")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ Fehler beim Laden von Units/Foods: \(error)")
                #endif
                // Nicht kritisch - User kann trotzdem tippen
            }
        }
    }
    
    private func markAsChanged() {
        hasUnsavedChanges = true
        updateValidation()
    }
    
    private func updateValidation() {
        var errors: [String] = []
        
        if recipe.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(localized("errorEmptyTitle"))
        }
        
        if recipe.ingredients.isEmpty {
            errors.append(localized("errorNoIngredients"))
        }
        
        if recipe.instructions.isEmpty {
            errors.append(localized("errorNoInstructions"))
        }
        
        let emptyInstructions = recipe.instructions.filter { 
            $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
        }
        if !emptyInstructions.isEmpty {
            errors.append(localized("errorEmptyInstructions"))
        }
        
        withAnimation {
            validationErrors = errors
        }
    }
    
    private var isValid: Bool {
        return validationErrors.isEmpty
    }
    
    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        pendingPhotoItem = item
        showImageChangeWarning = true
    }
    
    // MARK: - Formatting Helpers
    
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
    
    /// Kurzes Format für Badges (z.B. "1h" oder "45m")
    private func formatMinutesShort(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h\(mins)m"
    }

    // MARK: - Ingredients Card
    private var ingredientsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Empty State
            if recipe.ingredients.isEmpty {
                emptyStateView(
                    icon: "leaf.circle",
                    title: localized("noIngredientsYet"),
                    subtitle: localized("tapBelowToAdd")
                )
            } else {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    UniversalIngredientRow(
                        index: index,
                        recipe: $recipe,
                        shouldShowStructured: shouldShowStructured(for: ingredient),
                        autocompleteCache: autocompleteCache,
                        onDelete: {
                            hapticNotification.notificationOccurred(.warning)
                            withAnimation {
                                if index < recipe.ingredients.count {
                                    recipe.ingredients.remove(at: index)
                                    markAsChanged()
                                }
                            }
                        }
                    )
                    .onChange(of: ingredient.food) { _, _ in markAsChanged() }
                    .onChange(of: ingredient.quantity) { _, _ in markAsChanged() }
                    .onChange(of: ingredient.unit) { _, _ in markAsChanged() }
                }
            }
            
            addButton(
                title: localized("addIngredient"),
                icon: "plus.circle.fill",
                action: {
                    hapticImpact.impactOccurred()
                    withAnimation {
                        let newIngredient = shouldAddStructuredIngredient()
                            ? Ingredient.newStructured()
                            : Ingredient.newSimple()
                        recipe.ingredients.append(newIngredient)
                        markAsChanged()
                        
                        // Smart Focus
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            focusedIngredientIndex = recipe.ingredients.count - 1
                        }
                    }
                }
            )
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Berechnete Properties (nur einmal definiert)
    // MARK: - Berechnete Properties
    private var hasStructuredIngredients: Bool {
        let structuredCount = recipe.ingredients.filter {
            $0.quantity != nil || $0.unit != nil
        }.count
        let totalCount = recipe.ingredients.count
        guard totalCount > 0 else { return false }
        return Double(structuredCount) / Double(totalCount) > 0.5
    }

    private var hasMixedIngredients: Bool {
        let structuredCount = recipe.ingredients.filter {
            $0.quantity != nil || $0.unit != nil
        }.count
        let simpleCount = recipe.ingredients.filter {
            $0.quantity == nil && $0.unit == nil
        }.count
        return structuredCount > 0 && simpleCount > 0
    }

    private func shouldShowStructured(for ingredient: Ingredient) -> Bool {
        return (ingredient.quantity != nil || ingredient.unit != nil) || hasStructuredIngredients
    }

    private func shouldAddStructuredIngredient() -> Bool {
        return hasStructuredIngredients
    }

    // MARK: - Instructions Card
    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Empty State
            if recipe.instructions.isEmpty {
                emptyStateView(
                    icon: "list.number.circle",
                    title: localized("noInstructionsYet"),
                    subtitle: localized("tapBelowToAdd")
                )
            } else {
                ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { i, instruction in
                    instructionRow(at: i)
                        .onChange(of: instruction.text) { _, _ in markAsChanged() }
                }
            }
            
            addButton(
                title: localized("addStep"),
                icon: "plus.circle.fill",
                action: {
                    hapticImpact.impactOccurred()
                    withAnimation {
                        recipe.instructions.append(Instruction(text: ""))
                        markAsChanged()
                        focusedInstructionIndex = (recipe.instructions.count - 1)
                    }
                }
            )
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(16)
    }
    
    private func instructionRow(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("\(localized("step")) \(index + 1)", systemImage: "circle.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(.accentColor)
                
                Spacer()
                
                Button(role: .destructive) {
                    hapticNotification.notificationOccurred(.warning)
                    withAnimation {
                        if index < recipe.instructions.count {
                            recipe.instructions.remove(at: index)
                            markAsChanged()
                        }
                    }
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
            
            ZStack(alignment: .topLeading) {
                // Placeholder
                if index < recipe.instructions.count && recipe.instructions[index].text.isEmpty {
                    Text(localized("stepPlaceholder"))
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
                
                if index < recipe.instructions.count {
                    if #available(iOS 16.0, *) {
                        TextEditor(text: Binding(
                            get: { index < recipe.instructions.count ? recipe.instructions[index].text : "" },
                            set: { if index < recipe.instructions.count { recipe.instructions[index].text = $0 } }
                        ))
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .focused($focusedInstructionIndex, equals: index)
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(10)
                    } else {
                        TextEditor(text: Binding(
                            get: { index < recipe.instructions.count ? recipe.instructions[index].text : "" },
                            set: { if index < recipe.instructions.count { recipe.instructions[index].text = $0 } }
                        ))
                            .background(Color.clear)
                            .focused($focusedInstructionIndex, equals: index)
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(10)
                    }
                }
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Organization Card
    private var organizationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !selectedTags.isEmpty {
                ChipRow(items: Array(selectedTags), display: { $0.name })
            }
            MultipleSelectionPicker(
                title: localized("tags"),
                items: allTags,
                selection: $selectedTags,
                display: { $0.name },
                createNew: { await createTag(name: $0) },
                useChips: false
            )

            if !selectedCategories.isEmpty {
                ChipRow(items: Array(selectedCategories), display: { $0.name })
            }
            MultipleSelectionPicker(
                title: localized("categories"),
                items: allCategories,
                selection: $selectedCategories,
                display: { $0.name },
                createNew: { await createCategory(name: $0) },
                useChips: false
            )
        }
        .padding(.vertical, 6)
        .padding(.horizontal)
        .background(cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Reusable UI Components
    
    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
    
    private func addButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.bold())
            .foregroundColor(.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.secondarySystemBackground))
            .shadow(color: Color.primary.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func customDisclosureGroup<Content: View>(
        title: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        badge: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) { 
                    isExpanded.wrappedValue.toggle() 
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.subheadline.bold())
                        .frame(width: 16)
                    
                    Label(title, systemImage: systemImage)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if let badge = badge {
                        Text(badge)
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            if isExpanded.wrappedValue {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Save & Helpers
    
    /// ✅ NEU: Bestimmt ob ein Zeitwert geändert wurde und als ISO-8601 gesendet werden soll
    /// - Returns: nil wenn unverändert, ISO-8601 String wenn geändert
    private func getTimeValueForAPI(current: Int?, original: Int?) -> String? {
        // Beide nil oder beide gleich → keine Änderung
        if current == original {
            return nil
        }
        
        // Wert wurde geändert → als ISO-8601 konvertieren
        guard let current = current, current > 0 else {
            return nil
        }
        
        return minutesToISO8601Duration(current)
    }
    
    /// Konvertiert Minuten in ISO 8601 Duration Format (z.B. 105 → "PT1H45M")
    private func minutesToISO8601Duration(_ minutes: Int) -> String {
        if minutes == 0 {
            return "PT0M"
        }
        
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        var result = "PT"
        if hours > 0 {
            result += "\(hours)H"
        }
        if remainingMinutes > 0 || hours == 0 {
            result += "\(remainingMinutes)M"
        }
        
        return result
    }
    
    private func hideKeyboard() {
        // ✅ WICHTIG: Alle FocusStates zurücksetzen
        focusedIngredientIndex = nil
        focusedInstructionIndex = nil
        keyboardFocused = false
        
        // ✅ WICHTIG: iOS Keyboard explizit schließen
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), 
            to: nil, 
            from: nil, 
            for: nil
        )
        
        #if DEBUG
        print("⌨️ Keyboard versteckt - Focus States zurückgesetzt")
        #endif
    }
    
    private func saveRecipe() {
        // Validierung ist bereits in Echtzeit aktiv
        guard isValid else {
            hapticNotification.notificationOccurred(.error)
            return
        }
        
        // ✅ KRITISCH: Keyboard vor Network Request verstecken
        // Dies verhindert die RTIInputSystemClient Warnung
        hideKeyboard()
        
        // Setze Loading State
        isSaving = true
        
        Task {
            // ⏱️ Warte kurz bis Keyboard-Animation abgeschlossen ist
            // Dies gibt iOS Zeit, die Input-Session korrekt zu beenden
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 Sekunden
            
            imageUploadError = nil
            imageUploading = true
            
            // Bild-Upload (falls vorhanden)
            if let selectedUIImage {
                do {
                    try await APIService.shared.uploadRecipeImageForExistingRecipe(slug: originalSlug, image: selectedUIImage)
                } catch {
                    imageUploadError = error.localizedDescription
                    imageUploading = false
                    isSaving = false
                    hapticNotification.notificationOccurred(.error)
                    
                    // Bessere Fehlerbehandlung
                    if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                        alertMessage = localized("noInternetConnection")
                    } else if (error as NSError).code == NSURLErrorTimedOut {
                        alertMessage = localized("uploadTimeout")
                    } else {
                        alertMessage = "\(localized("imageUploadFailed")): \(error.localizedDescription)"
                    }
                    alertTitle = localized("saveErrorTitle")
                    showAlert = true
                    return
                }
            }
            imageUploading = false

            // Prepare Payload with Unit/Food Lookup
            recipe.tags = Array(selectedTags)
            recipe.recipeCategory = Array(selectedCategories)
            recipe.dateUpdated = Date()
            
            // ✅ NEU: Prüfe ob Zeitwerte geändert wurden
            let shouldUpdatePrepTime = recipe.prepTime != originalPrepTime
            let shouldUpdateCookTime = recipe.cookTime != originalCookTime
            let shouldUpdateTotalTime = recipe.totalTime != originalTotalTime
            
            #if DEBUG
            if shouldUpdatePrepTime {
                print("⏱️ prepTime wurde geändert: \(originalPrepTime ?? 0) → \(recipe.prepTime ?? 0)")
            }
            if shouldUpdateCookTime {
                print("⏱️ cookTime wurde geändert: \(originalCookTime ?? 0) → \(recipe.cookTime ?? 0)")
            }
            if shouldUpdateTotalTime {
                print("⏱️ totalTime wurde geändert: \(originalTotalTime ?? 0) → \(recipe.totalTime ?? 0)")
            }
            #endif
            
            // ✅ Erstelle Payload - Mealie erstellt Foods/Units automatisch
            let payload: RecipeUpdatePayload
            do {
                payload = try await RecipeUpdatePayload.create(
                    from: recipe,
                    apiService: APIService.shared,
                    updatePrepTime: shouldUpdatePrepTime,
                    updateCookTime: shouldUpdateCookTime,  // ✅ FIXED: cookTime Flag übergeben
                    updateTotalTime: shouldUpdateTotalTime,
                    originalPrepTime: originalPrepTime,
                    originalCookTime: originalCookTime,    // ✅ FIXED: originalCookTime übergeben
                    originalTotalTime: originalTotalTime
                )
            } catch {
                #if DEBUG
                print("⚠️ Payload Erstellung fehlgeschlagen: \(error)")
                #endif
                // Fallback: Verwende synchronen Initializer
                payload = RecipeUpdatePayload(
                    from: recipe,
                    updatePrepTime: shouldUpdatePrepTime,
                    updateCookTime: shouldUpdateCookTime,  // ✅ FIXED: cookTime Flag übergeben
                    updateTotalTime: shouldUpdateTotalTime
                )
            }
            
            #if DEBUG
            // ✅ Debug: Log wichtige Payload-Infos
            print("📤 ═══════════════════════════════════════════")
            print("📤 PATCH Request wird vorbereitet")
            print("📤 ═══════════════════════════════════════════")
            print("   Recipe: \(recipe.name)")
            print("   Slug: \(payload.slug)")
            print("   Ingredients: \(payload.recipeIngredient?.count ?? 0)")
            
            // ✅ WICHTIG: Log jede einzelne Zutat
            if let ingredients = payload.recipeIngredient {
                print("   ")
                print("   🔍 Zutaten-Details:")
                for (index, ing) in ingredients.enumerated() {
                    var parts: [String] = []
                    parts.append("[\(index+1)]")
                    
                    if let qty = ing.quantity {
                        parts.append("quantity=\(qty)")
                    } else {
                        parts.append("quantity=nil")
                    }
                    
                    if let unit = ing.unit {
                        parts.append("unit={id:\(unit.id), name:\"\(unit.name)\"}")
                    } else {
                        parts.append("unit=nil")
                    }
                    
                    if let food = ing.food {
                        parts.append("food={id:\(food.id), name:\"\(food.name)\"}")
                    } else {
                        parts.append("food=nil")
                    }
                    
                    if let note = ing.note {
                        parts.append("note=\"\(note)\"")
                    } else {
                        parts.append("note=nil")
                    }
                    
                    print("      " + parts.joined(separator: " "))
                }
            }
            
            print("   Instructions: \(payload.recipeInstructions.count)")
            print("   Tags: \(payload.tags?.count ?? 0)")
            print("   Categories: \(payload.recipeCategory?.count ?? 0)")
            print("📤 ═══════════════════════════════════════════")
            #endif
            
            do {
                // ✅ PATCH Request mit vollständigem Logging
                try await APIService.shared.updateFullRecipe(originalSlug: originalSlug, payload: payload)
                
                #if DEBUG
                print("✅ ═══════════════════════════════════════════")
                print("✅ PATCH erfolgreich - Lade Rezept neu vom Server")
                print("✅ ═══════════════════════════════════════════")
                #endif
                
                // ⭐ NEU: Rating separat setzen (falls geändert)
                if recipe.rating != originalRating {
                    #if DEBUG
                    print("⭐ Rating wurde geändert: \(originalRating ?? 0) → \(recipe.rating ?? 0)")
                    #endif
                    
                    do {
                        if let rating = recipe.rating, rating > 0 {
                            // Rating setzen (1-5 Sterne)
                            // ✅ Nutze recipe.slug für die URL
                            try await APIService.shared.setRecipeRating(
                                recipeId: recipe.id,
                                slug: recipe.slug,
                                rating: rating
                            )
                            #if DEBUG
                            print("✅ Rating erfolgreich gesetzt: \(rating) Sterne")
                            #endif
                        } else {
                            // Rating löschen (0 oder nil)
                            // ✅ Nutze recipe.slug für die URL
                            try await APIService.shared.deleteRecipeRating(
                                slug: recipe.slug
                            )
                            #if DEBUG
                            print("✅ Rating erfolgreich gelöscht")
                            #endif
                        }
                    } catch {
                        #if DEBUG
                        print("⚠️ Rating konnte nicht aktualisiert werden: \(error)")
                        #endif
                        // Rating-Fehler nicht kritisch - Rezept wurde trotzdem gespeichert
                    }
                }
                
                // ✅ NEU: Automatischer Reload vom Server
                // Cache wird automatisch aktualisiert
                await RecipeCacheManager.shared.reloadRecipe(with: recipe.id)
                
                #if DEBUG
                print("✅ Rezept neu geladen und im Cache aktualisiert")
                #endif
                
                // Success State
                await MainActor.run {
                    isSaving = false
                    hasUnsavedChanges = false
                    hapticNotification.notificationOccurred(.success)
                    
                    // ✅ Erfolg - Keine Cache-Meldung nötig (passiert automatisch)
                    alertTitle = localized("saveSuccessTitle")
                    alertMessage = localized("recipeUpdatedSuccessfully")
                    showAlert = true
                }
            } catch {
                // Error State
                await MainActor.run {
                    isSaving = false
                    hapticNotification.notificationOccurred(.error)
                    
                    // ✅ Detaillierte Fehlerausgabe
                    let nsError = error as NSError
                    let errorDetails = nsError.userInfo["responseBody"] as? String ?? error.localizedDescription
                    let statusCode = nsError.userInfo["statusCode"] as? Int
                    
                    var errorMessage = "\(localized("saveErrorMessage"))\n\n"
                    
                    if let code = statusCode {
                        errorMessage += "HTTP \(code): "
                    }
                    
                    errorMessage += errorDetails
                    
                    alertTitle = localized("saveErrorTitle")
                    alertMessage = errorMessage
                    showAlert = true
                    
                    #if DEBUG
                    print("❌ ═══════════════════════════════════════════")
                    print("❌ Save Failed")
                    print("❌ ═══════════════════════════════════════════")
                    print("   Error: \(error)")
                    print("   Domain: \(nsError.domain)")
                    print("   Code: \(nsError.code)")
                    
                    if let code = statusCode {
                        print("   HTTP Status: \(code)")
                    }
                    
                    if let body = nsError.userInfo["responseBody"] as? String {
                        print("   Response Body:")
                        print(body)
                    }
                    
                    print("   UserInfo: \(nsError.userInfo)")
                    print("❌ ═══════════════════════════════════════════")
                    #endif
                }
            }
        }
    }

    private func createCategory(name: String) async -> Category {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = allCategories.first(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        do {
            let newCategory = try await APIService.shared.createCategory(name: trimmed)
            await MainActor.run {
                allCategories.append(newCategory)
            }
            return newCategory
        } catch {
            return Category(id: UUID().uuidString, name: trimmed, slug: nil)
        }
    }

    private func createTag(name: String) async -> RecipeTag {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = allTags.first(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        do {
            let newTag = try await APIService.shared.createTag(name: trimmed)
            await MainActor.run {
                allTags.append(newTag)
            }
            return newTag
        } catch {
            return RecipeTag(id: UUID().uuidString, name: trimmed, slug: nil)
        }
    }

    func buildImageURL(recipeID: String) -> URL? {
        guard let base = APIService.shared.getBaseURL() else { return nil }
        return base
            .appendingPathComponent("api/media/recipes")
            .appendingPathComponent(recipeID)
            .appendingPathComponent("images/original.webp")
    }
    
    func localized(_ key: String) -> String {
        // ✅ Verwendete Localization Keys (müssen in Localizable.strings vorhanden sein):
        // - "editRecipe", "cancel", "save", "done", "saving"
        // - "title", "titleRequired", "description", "descriptionPlaceholder"
        // - "tapToAddPhoto", "servings", "servingsHint", "portionUnit"
        // - "prep_time", "total_time", "ingredients", "instructions", "organization"
        // - "step", "stepPlaceholder", "addStep", "addIngredient"
        // - "noIngredientsYet", "noInstructionsYet", "tapBelowToAdd"
        // - "errorEmptyTitle", "errorNoIngredients", "errorNoInstructions", "errorEmptyInstructions"
        // - "changeImageWarningTitle", "changeImageWarningMessage", "confirm"
        // - "unsavedChanges", "unsavedChangesMessage", "discard", "keepEditing"
        // - "saveSuccessTitle", "recipeUpdatedSuccessfully", "saveErrorTitle", "saveErrorMessage"
        // - "validationError", "ok", "back", "tags", "categories"
        // - "addNewPlaceholder", "quantity", "unit", "ingredient", "note"
        // - "parsed", "mixed", "addIngredientAccessibility", "tapToAddNewIngredient"
        // - "addStepAccessibility", "tapToAddNewStep", "save_changes"
        // - "imageUploadFailed", "noInternetConnection", "uploadTimeout"
        
        return NSLocalizedString(key, comment: "")
    }
    
    // MARK: - Migration Helper
    /// Migriert alte Zutaten, bei denen food den kompletten Text enthält
    private func migrateIngredients() {
        // ✅ Arbeite mit einer Kopie der Indices um Race Conditions zu vermeiden
        let indicesToMigrate = Array(recipe.ingredients.indices)
        
        for index in indicesToMigrate {
            // ✅ Zusätzlicher Bounds-Check
            guard index < recipe.ingredients.count else { 
                #if DEBUG
                print("⚠️ Migration: Index \(index) außerhalb des Bereichs")
                #endif
                continue 
            }
            
            var ingredient = recipe.ingredients[index]
            
            // Prüfe ob Migration nötig ist:
            // - food enthält Menge/Einheit UND
            // - quantity/unit sind bereits gesetzt
            guard let food = ingredient.food, !food.isEmpty else { continue }
            
            // Wenn quantity/unit bereits gesetzt sind, aber food auch Zahlen enthält
            // -> Parse neu
            let hasNumberInFood = food.range(of: #"^\d+"#, options: .regularExpression) != nil
            
            if hasNumberInFood || (ingredient.quantity != nil && food.contains(String(describing: ingredient.quantity!))) {
                // Parse die food neu
                let parseResult = QuantityParser.parse(from: food)
                
                // Aktualisiere nur, wenn wir etwas extrahieren konnten
                if parseResult.qty != nil || parseResult.unit != nil || parseResult.cleaned != food {
                    ingredient.quantity = parseResult.qty
                    ingredient.unit = parseResult.unit
                    ingredient.food = parseResult.cleaned.isEmpty ? nil : parseResult.cleaned
                    
                    // ✅ Nochmal prüfen vor dem Schreiben
                    if index < recipe.ingredients.count {
                        recipe.ingredients[index] = ingredient
                        
                        #if DEBUG
                        print("✅ Migration: '\(food)' → qty: \(parseResult.qty?.description ?? "nil"), unit: \(parseResult.unit ?? "nil"), food: '\(parseResult.cleaned)'")
                        #endif
                    }
                }
            }
        }
    }
}

// MARK: - Nested Views (außerhalb von EditRecipeView definiert)

struct UniversalIngredientRow: View {
    let index: Int
    @Binding var recipe: RecipeDetail
    let shouldShowStructured: Bool
    @ObservedObject var autocompleteCache: IngredientAutocompleteCache
    let onDelete: () -> Void
    
    private var ingredient: Binding<Ingredient>? {
        guard index < recipe.ingredients.count else { return nil }
        return Binding<Ingredient>(
            get: { 
                guard index < recipe.ingredients.count else { 
                    return Ingredient.newSimple()
                }
                return recipe.ingredients[index] 
            },
            set: { 
                guard index < recipe.ingredients.count else { return }
                recipe.ingredients[index] = $0 
            }
        )
    }
    
    var body: some View {
        Group {
            if let ingredient = ingredient {
                if shouldShowStructured && ingredient.wrappedValue.canShowStructured {
                    StructuredIngredientRow(
                        ingredient: ingredient,
                        autocompleteCache: autocompleteCache,
                        onDelete: onDelete
                    )
                } else {
                    SimpleIngredientRow(
                        ingredient: ingredient,
                        autocompleteCache: autocompleteCache,
                        onDelete: onDelete
                    )
                }
            } else {
                // Fallback für ungültigen Index
                EmptyView()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - StructuredIngredientRow (mit Autocomplete) - KORRIGIERT
struct StructuredIngredientRow: View {
    @Binding var ingredient: Ingredient
    @ObservedObject var autocompleteCache: IngredientAutocompleteCache
    let onDelete: () -> Void
    
    @State private var showNoteField: Bool = false
    
    // ✅ KORRIGIERT: Quantity Binding
    private var quantity: Binding<String> {
        Binding<String>(
            get: {
                if let q = ingredient.quantity {
                    return q.truncatingRemainder(dividingBy: 1) == 0 ?
                           String(Int(q)) :
                           String(format: "%.2f", q).replacingOccurrences(of: ".00", with: "")
                }
                return ""
            },
            set: {
                if $0.isEmpty {
                    ingredient.quantity = nil
                } else if let value = Double($0.replacingOccurrences(of: ",", with: ".")) {
                    ingredient.quantity = value
                }
            }
        )
    }
    
    // ✅ KORRIGIERT: Unit Binding
    private var unit: Binding<String> {
        Binding<String>(
            get: { ingredient.unit ?? "" },
            set: { 
                ingredient.unit = $0.isEmpty ? nil : $0
            }
        )
    }
    
    // ✅ NEU: Food (Hauptzutat) Binding
    private var food: Binding<String> {
        Binding<String>(
            get: { ingredient.food ?? "" },
            set: { 
                ingredient.food = $0.isEmpty ? nil : $0
            }
        )
    }
    
    // ✅ NEU: Note (Zusätzliche Anmerkung) Binding
    private var note: Binding<String> {
        Binding<String>(
            get: { ingredient.note ?? "" },
            set: { 
                ingredient.note = $0.isEmpty ? nil : $0
            }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                // Menge
                TextField("quantity".localized, text: quantity)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                
                // ✅ Einheit (mit Autocomplete aus Cache)
                InlineAutocompleteTextField(
                    placeholder: "unit".localized,
                    text: unit,
                    suggestions: autocompleteCache.searchUnits(query: unit.wrappedValue).map { $0.displayName },
                    width: 80
                )
                
                // ✅ KORRIGIERT: Food (Hauptzutat) mit Autocomplete aus Cache
                InlineAutocompleteTextField(
                    placeholder: "ingredient".localized,
                    text: food,
                    suggestions: autocompleteCache.searchFoods(query: food.wrappedValue).map { $0.name }
                )
                
                // ✅ NEU: Note Toggle Button
                Button(action: {
                    withAnimation {
                        showNoteField.toggle()
                    }
                }) {
                    Image(systemName: ingredient.hasNote ? "note.text" : "note.text.badge.plus")
                        .foregroundColor(ingredient.hasNote ? .accentColor : .secondary)
                        .font(.system(size: 18))
                }
                
                // Delete Button
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
            }
            
            // ✅ NEU: Note Field (ausklappbar)
            if showNoteField {
                HStack {
                    Image(systemName: "note.text")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    TextField("note".localized, text: note)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }
                .padding(.leading, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            // Zeige Note-Feld wenn bereits eine Note vorhanden ist
            showNoteField = ingredient.hasNote
        }
    }
}

// MARK: - Inline Autocomplete TextField (Kompakt, ohne Overlay)
struct InlineAutocompleteTextField: View {
    let placeholder: String
    @Binding var text: String
    let suggestions: [String]
    var width: CGFloat? = nil
    
    @State private var showSuggestions = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
                .focused($isFocused)
                .onChange(of: isFocused) { _, focused in
                    showSuggestions = focused && !text.isEmpty && !suggestions.isEmpty
                }
                .onChange(of: text) { _, _ in
                    showSuggestions = isFocused && !text.isEmpty && !suggestions.isEmpty
                }
            
            if showSuggestions {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions.prefix(3), id: \.self) { suggestion in
                        Button {
                            text = suggestion
                            showSuggestions = false
                            isFocused = false
                        } label: {
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.tertiarySystemBackground))
                        }
                        .buttonStyle(.plain)
                        
                        if suggestion != suggestions.prefix(3).last {
                            Divider()
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(6)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                .frame(width: width)
                .transition(.opacity)
            }
        }
    }
}
// MARK: - SimpleIngredientRow (mit Autocomplete)
struct SimpleIngredientRow: View {
    @Binding var ingredient: Ingredient
    @ObservedObject var autocompleteCache: IngredientAutocompleteCache
    let onDelete: () -> Void
    
    @FocusState private var isFocused: Bool
    @State private var combinedSuggestions: [String] = []
    
    // Computed binding für das TextField
    private var fullText: Binding<String> {
        Binding<String>(
            get: {
                buildDisplayText(from: ingredient)
            },
            set: { newValue in
                let parseResult = QuantityParser.parse(from: newValue)
                
                ingredient.quantity = parseResult.qty
                ingredient.unit = parseResult.unit
                ingredient.food = parseResult.cleaned.isEmpty ? nil : parseResult.cleaned
            }
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("ingredient".localized, text: fullText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onChange(of: fullText.wrappedValue) { _, newValue in
                        updateSuggestions(for: newValue)
                    }
                    .onChange(of: isFocused) { _, focused in
                        if focused {
                            updateSuggestions(for: fullText.wrappedValue)
                        } else {
                            withAnimation {
                                combinedSuggestions = []
                            }
                        }
                    }
                    .submitLabel(.done)
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
            }
            
            // Suggestions Dropdown
            if !combinedSuggestions.isEmpty && isFocused {
                suggestionsList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private var suggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(combinedSuggestions.prefix(6), id: \.self) { suggestion in
                        Button(action: {
                            withAnimation {
                                applySuggestion(suggestion)
                            }
                        }) {
                            HStack {
                                // Icon für Typ
                                Image(systemName: isUnitSuggestion(suggestion) ? "ruler" : "leaf")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text(suggestion)
                                    .font(.callout)
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 8)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .background(Color(.systemBackground))
                        }
                        .buttonStyle(.plain)
                        
                        if suggestion != combinedSuggestions.prefix(6).last {
                            Divider()
                                .padding(.leading, 10)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1.5)
        )
        .padding(.top, 4)
        .zIndex(999)
    }
    
    private func applySuggestion(_ suggestion: String) {
        let currentText = fullText.wrappedValue
        
        // Smart-Completion: Wenn der Nutzer nur den Anfang einer Einheit eingibt
        if let lastWord = currentText.split(separator: " ").last,
           suggestion.lowercased().hasPrefix(String(lastWord).lowercased()) {
            // Ersetze nur das letzte Wort
            var parts = currentText.split(separator: " ").map(String.init)
            if !parts.isEmpty {
                parts[parts.count - 1] = suggestion
                fullText.wrappedValue = parts.joined(separator: " ")
            }
        } else {
            fullText.wrappedValue = suggestion
        }
        
        isFocused = false
    }
    
    private func updateSuggestions(for text: String) {
        guard !text.isEmpty else {
            combinedSuggestions = []
            return
        }
        
        // Extrahiere das letzte Wort für intelligente Vorschläge
        let lastWord = text.split(separator: " ").last.map(String.init) ?? text
        
        // Kombiniere Einheiten- und Food-Vorschläge
        var suggestions = Set<String>()
        
        // ✅ Einheiten-Vorschläge (für das letzte Wort)
        let unitResults = autocompleteCache.searchUnits(query: lastWord)
        suggestions.formUnion(unitResults.map { $0.displayName })
        
        // ✅ Food-Vorschläge (für den ganzen Text)
        let foodResults = autocompleteCache.searchFoods(query: text)
        suggestions.formUnion(foodResults.map { $0.name })
        
        combinedSuggestions = Array(suggestions)
            .sorted()
            .prefix(8)
            .map { $0 }
    }
    
    private func isUnitSuggestion(_ suggestion: String) -> Bool {
        // ✅ Prüfe ob es eine Unit ist
        return autocompleteCache.units.contains(where: { 
            $0.name.lowercased() == suggestion.lowercased() ||
            $0.displayName.lowercased() == suggestion.lowercased()
        })
    }
    
    private func buildDisplayText(from ingredient: Ingredient) -> String {
        var parts: [String] = []
        
        if let quantity = ingredient.quantity {
            let displayQuantity: String
            if quantity.truncatingRemainder(dividingBy: 1) == 0 {
                displayQuantity = String(Int(quantity))
            } else {
                let formatter = NumberFormatter()
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 2
                displayQuantity = formatter.string(from: NSNumber(value: quantity)) ?? String(quantity)
            }
            parts.append(displayQuantity)
        }
        
        if let unit = ingredient.unit, !unit.isEmpty {
            parts.append(unit)
        }
        
        if let food = ingredient.food, !food.isEmpty {
            parts.append(food)
        }
        
        return parts.joined(separator: " ")
    }
}


// MARK: - MultipleSelectionPicker, PickerSheet

struct MultipleSelectionPicker<Item: Identifiable & Hashable & Equatable>: View {
    let title: String
    let items: [Item]
    @Binding var selection: Set<Item>
    let display: (Item) -> String
    let createNew: ((String) async -> Item)?
    var useChips: Bool = false

    @State private var showList = false

    var body: some View {
        Button {
            showList = true
        } label: {
            HStack {
                Text(title)
                    .font(.body)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .frame(height: 30)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.fancyInputBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.accentColor.opacity(0.19), lineWidth: 1)
            )
            .shadow(color: Color.primary.opacity(0.05), radius: 1, x: 0, y: 1)
        }
        .sheet(isPresented: $showList) {
            MultipleSelectionSheet(
                title: title,
                items: items,
                selection: $selection,
                display: display,
                createNew: createNew,
                useChips: useChips
            )
        }
    }
}

struct MultipleSelectionSheet<Item: Identifiable & Hashable & Equatable>: View {
    let title: String
    let items: [Item]
    @Binding var selection: Set<Item>
    let display: (Item) -> String
    let createNew: ((String) async -> Item)?
    var useChips: Bool = false

    @Environment(\.dismiss) var dismiss

    @State private var newText: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            VStack {
                if let createNew = createNew {
                    HStack {
                        TextField("addNewPlaceholder".localized, text: $newText)
                            .padding(.vertical, 4)
                            .background(Color.clear)
                            .fancyInputStyle()
                            .textFieldStyle(.roundedBorder)
                        Button(action: {
                            let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            if let existing = items.first(where: { display($0).localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
                                selection.insert(existing)
                                newText = ""
                            } else {
                                Task {
                                    isSaving = true
                                    let newItem = await createNew(trimmed)
                                    selection.insert(newItem)
                                    isSaving = false
                                    newText = ""
                                }
                            }
                        }) {
                            if isSaving {
                                ProgressView()
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                        }
                        .disabled(isSaving || newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding([.horizontal, .top])
                }
                ScrollView {
                    ChipGrid(
                        items: items,
                        selected: selection,
                        onTap: { item in
                            if selection.contains(item) { selection.remove(item) }
                            else { selection.insert(item) }
                        },
                        display: display
                    )
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("back".localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("done".localized) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Extensions & Formatter

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}

extension Binding where Value == String? {
    var bound: Binding<String> {
        Binding<String>(
            get: { self.wrappedValue ?? "" },
            set: { self.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}

extension Binding where Value == Int? {
    var boundInt: Binding<Int> {
        Binding<Int>(
            get: { self.wrappedValue ?? 0 },
            set: { self.wrappedValue = $0 }
        )
    }
}

extension Binding where Value == Double? {
    var boundDouble: Binding<Double> {
        Binding<Double>(
            get: { self.wrappedValue ?? 0 },
            set: { self.wrappedValue = $0 }
        )
    }
}

func intFormatter() -> NumberFormatter {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "en_US_POSIX")
    f.generatesDecimalNumbers = false
    f.maximumFractionDigits = 0
    f.allowsFloats = false
    f.minimum = 0
    return f
}

extension View {
    func fancyInputStyle(cornerRadius: CGFloat = 14) -> some View {
        self
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.fancyInputBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.accentColor.opacity(0.19), lineWidth: 1)
            )
            .shadow(color: Color.primary.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

extension Color {
    static var fancyInputBackground: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
            ? UIColor(red: 40/255, green: 40/255, blue: 45/255, alpha: 1)
            : UIColor(red: 252/255, green: 252/255, blue: 255/255, alpha: 1)
        })
    }
}
