import SwiftUI
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

struct ShoppingListView: View {
    @EnvironmentObject private var viewModel: ShoppingListViewModel
    @ObservedObject private var settings = AppSettings.shared

    @State private var newItemNote: String = ""
    @State private var selectedLabel: ShoppingItem.LabelWrapper?
    @State private var showSuccessToast = false
    @State private var showArchiveAlert = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var showSyncChangesSheet = false
    @FocusState private var isInputFocused: Bool
    @State private var selectedCheckChanges: [UUID: Bool] = [:]
    @State private var selectedQuantityChanges: [UUID: Bool] = [:]
    @State private var selectedCategoryChanges: [UUID: Bool] = [:]
    @State private var isSyncing = false

    // --- Reorder Mode State ---
    @State private var isReorderMode = false
    @State private var categoryOrder: [String] = []

    // --- Import-Flow ---
    @State private var showImportSheet = false

    private var unlabeledName: String {
        LocalizedStringProvider.localized("unlabeled_category")
    }

    private var allAvailableCategoryNames: [String] {
        let names = viewModel.availableLabels.map { $0.name }
        return [unlabeledName] + names.filter { $0 != unlabeledName }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                let horizontalPadding = isLandscape ? geometry.size.width * 0.2 : 0.0

                VStack(spacing: 0) {
                    if viewModel.shoppingList.isEmpty {
                        EmptyListView(isLandscape: isLandscape)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        if isReorderMode {
                            reorderCategoriesView
                                .padding(.horizontal, horizontalPadding)
                                .transition(.opacity)
                        } else {
                            shoppingListItemsView
                                .padding(.horizontal, horizontalPadding)
                                .transition(.opacity)
                        }
                    }

                    inputSection(padding: horizontalPadding)
                        .padding(.bottom, isInputFocused ? keyboardHeight : 0)
                        .animation(.easeInOut(duration: 0.25), value: keyboardHeight)
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .overlay(
                    Group {
                        if showSuccessToast {
                            Text(LocalizedStringProvider.localized("add_success"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.green.opacity(0.9))
                                .foregroundColor(Color.white)
                                .cornerRadius(12)
                                .shadow(radius: 5)
                                .transition(.opacity)
                                .padding(.bottom, 100)
                        }
                    },
                    alignment: .bottom
                )
                .alert(isPresented: $showArchiveAlert) {
                    Alert(
                        title: Text(LocalizedStringProvider.localized("list_done_title")),
                        message: Text(LocalizedStringProvider.localized("list_done_message")),
                        primaryButton: .destructive(Text(LocalizedStringProvider.localized("complete_shopping_confirm"))) {
                            Task {
                                await viewModel.archiveList()
                                try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                                await reloadData()
                            }
                        },
                        secondaryButton: .cancel(Text(LocalizedStringProvider.localized("cancel")))
                    )
                }
                .onAppear {
                    configureAPIIfNeeded()
                    // Kategorie-Reihenfolge initial mergen
                    let merged = mergedCategoryOrder()
                    if merged != categoryOrder {
                        categoryOrder = merged
                        CategoryOrderStore.save(merged)
                    }
                    Task { await reloadData() }
                }
                .onReceive(Publishers.keyboardHeight) { newHeight in
                    withAnimation { self.keyboardHeight = newHeight }
                }
                .onReceive(NotificationCenter.default.publisher(for: .pendingShoppingSync)) { _ in
                    let hasChanges =
                        !viewModel.pendingCheckChanges.isEmpty ||
                        !viewModel.pendingQuantityChanges.isEmpty ||
                        !viewModel.pendingCategoryChanges.isEmpty ||
                        !viewModel.pendingAddChanges.isEmpty

                    if hasChanges {
                        showSyncChangesSheet = true
                    }
                }
                .sheet(isPresented: $showSyncChangesSheet) {
                    NavigationStack {
                        SyncChangesView(
                            pendingCheckChanges: viewModel.pendingCheckChanges,
                            pendingQuantityChanges: viewModel.pendingQuantityChanges,
                            pendingCategoryChanges: viewModel.pendingCategoryChanges,
                            pendingAddChanges: viewModel.pendingAddChanges,
                            localItems: viewModel.shoppingList,
                            serverItems: viewModel.serverSnapshot,
                            availableLabels: viewModel.availableLabels,
                            selectedCheckChanges: $selectedCheckChanges,
                            selectedQuantityChanges: $selectedQuantityChanges,
                            selectedCategoryChanges: $selectedCategoryChanges,
                            isSyncing: $isSyncing
                        )
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(LocalizedStringProvider.localized("cancel")) {
                                    showSyncChangesSheet = false
                                }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                if isSyncing {
                                    ProgressView()
                                } else {
                                    Button(LocalizedStringProvider.localized("sync_now")) {
                                        isSyncing = true
                                        Task {
                                            await viewModel.syncPendingChangesToServer(
                                                selectedCheckChanges: selectedCheckChanges,
                                                selectedQuantityChanges: selectedQuantityChanges,
                                                selectedCategoryChanges: selectedCategoryChanges
                                            )
                                            isSyncing = false
                                            showSyncChangesSheet = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .onChange(of: isInputFocused) { oldValue, newValue in
                    if oldValue == true && newValue == false {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            if !isInputFocused {
                                Task { await reloadData() }
                            }
                        }
                    }
                }
                .navigationTitle(LocalizedStringProvider.localized("shopping_list"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Rechts → Links: zuerst Stift/Done, dann Import (Import erscheint links vom Stift)
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if isReorderMode {
                            Button(LocalizedStringProvider.localized("done")) {
                                finishReorderMode()
                            }
                            .accessibilityLabel(LocalizedStringProvider.localized("done"))
                        } else {
                            Button {
                                startReorderMode()
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .accessibilityLabel(LocalizedStringProvider.localized("reorder_categories"))
                        }

                        Button {
                            showImportSheet = true
                        } label: {
                            Image(systemName: "tray.and.arrow.down.fill")
                        }
                        .accessibilityLabel(LocalizedStringProvider.localized("import_from_reminders"))
                    }
                }
            }
            // Kategorie-Picker für Item
            .sheet(item: $viewModel.selectedItemForEditing) { selectedItem in
                CategoryPickerView(item: selectedItem) { newLabel in
                    viewModel.updateItemCategory(selectedItem, to: newLabel)
                    viewModel.selectedItemForEditing = nil
                }
                .environmentObject(viewModel)
            }
            // Import-Flow
            .sheet(isPresented: $showImportSheet) {
                RemindersImportFlowView(
                    isPresented: $showImportSheet
                )
                .environmentObject(viewModel)
            }
        }
    }

    // MARK: - Reorder Mode View (gleiche Optik wie Normalmodus, ohne Titel)

    private var reorderCategoriesView: some View {
        let uncheckedItems = viewModel.shoppingList.filter { !$0.checked }
        let groupedUnchecked = Dictionary(grouping: uncheckedItems) { $0.label?.name ?? unlabeledName }

        return List {
            ForEach(categoryOrder, id: \.self) { category in
                // gleicher Look wie Normalmodus, ohne Chevron – das System-Handle erscheint ganz rechts
                categoryHeaderChip(
                    category: category,
                    count: groupedUnchecked[category]?.count,
                    rightSFSymbol: nil
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                .listRowBackground(Color.clear)
            }
            .onMove(perform: moveCategories) // System-Handle aktiv
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active)) // Reorder-Modus
    }

    private func startReorderMode() {
        // einmalig mergen, dann State setzen
        let merged = mergedCategoryOrder()
        if merged != categoryOrder {
            categoryOrder = merged
            CategoryOrderStore.save(merged)
        }
        withAnimation { isReorderMode = true }
    }

    private func finishReorderMode() {
        CategoryOrderStore.save(categoryOrder)
        withAnimation { isReorderMode = false }
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        categoryOrder.move(fromOffsets: source, toOffset: destination)
    }

    // Reine Merge-Funktion (keine State-Änderung!)
    private func mergedCategoryOrder() -> [String] {
        let stored = categoryOrder.isEmpty ? CategoryOrderStore.load() : categoryOrder
        return CategoryOrderStore.mergedOrder(
            stored: stored,
            available: allAvailableCategoryNames
        )
    }

    // MARK: - Normal Mode (Items)

    private var shoppingListItemsView: some View {
        let uncheckedItems = viewModel.shoppingList.filter { !$0.checked }
        let checkedItems = viewModel.shoppingList.filter { $0.checked }

        // Gruppierung inkl. "Ohne Kategorie"
        let groupedUnchecked = Dictionary(grouping: uncheckedItems) { item in
            item.label?.name ?? unlabeledName
        }

        // Nur nicht-leere Kategorien im Normalmodus
        var nonEmptyCategories = groupedUnchecked
            .filter { !$0.value.isEmpty }
            .map { $0.key }

        // Reihenfolge gem. gespeicherter Sortierung
        let order = mergedCategoryOrder()
        nonEmptyCategories.sort { (lhs, rhs) -> Bool in
            let li = order.firstIndex(of: lhs) ?? Int.max
            let ri = order.firstIndex(of: rhs) ?? Int.max
            return li < ri
        }

        return List {
            ForEach(nonEmptyCategories, id: \.self) { category in
                let isCollapsed = settings.collapsedShoppingCategories.contains(category)

                Section(
                    header:
                        Button {
                            withAnimation {
                                if isCollapsed {
                                    settings.collapsedShoppingCategories.remove(category)
                                } else {
                                    settings.collapsedShoppingCategories.insert(category)
                                }
                            }
                        } label: {
                            // gleicher Header wie im Reorder-Modus, aber mit Chevron
                            categoryHeaderChip(
                                category: category,
                                count: groupedUnchecked[category]?.count,
                                rightSFSymbol: isCollapsed ? "chevron.down" : "chevron.up"
                            )
                        }
                ) {
                    if !isCollapsed {
                        let sortedItems = (groupedUnchecked[category] ?? [])
                            .sorted { ($0.note ?? "") < ($1.note ?? "") }

                        ForEach(sortedItems) { item in
                            ShoppingListItemView(item: item) {
                                viewModel.toggleIngredientCompletion(item)
                            } onQuantityChange: { newQty in
                                viewModel.updateQuantity(for: item, to: newQty)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    viewModel.selectedItemForEditing = item
                                } label: {
                                    Label(LocalizedStringProvider.localized("edit"), systemImage: "pencil")
                                }
                                .tint(.blue)

                                Button(role: .destructive) {
                                    viewModel.deleteItem(item)
                                } label: {
                                    Label(LocalizedStringProvider.localized("delete"), systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }

            if !checkedItems.isEmpty {
                let label = LocalizedStringProvider.localized("completed_category_title")
                let isCollapsed = settings.collapsedShoppingCategories.contains(label)

                Section(
                    header:
                        Button {
                            withAnimation {
                                if isCollapsed {
                                    settings.collapsedShoppingCategories.remove(label)
                                } else {
                                    settings.collapsedShoppingCategories.insert(label)
                                }
                            }
                        } label: {
                            HStack {
                                Text(label).font(.headline)
                                Spacer()
                                Image(systemName: isCollapsed ? "chevron.down" : "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(8)
                        }
                ) {
                    if !isCollapsed {
                        let sortedItems = checkedItems.sorted { ($0.note ?? "") < ($1.note ?? "") }

                        ForEach(sortedItems) { item in
                            ShoppingListItemView(item: item) {
                                viewModel.toggleIngredientCompletion(item)
                            } onQuantityChange: { newQty in
                                viewModel.updateQuantity(for: item, to: newQty)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteItem(item)
                                } label: {
                                    Label(LocalizedStringProvider.localized("delete"), systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.loadLabels()
            await viewModel.loadShoppingListFromServer()
            DispatchQueue.main.async {
                viewModel.shoppingList = viewModel.shoppingList.map { $0 }
                let merged = mergedCategoryOrder()
                if merged != categoryOrder {
                    categoryOrder = merged
                    CategoryOrderStore.save(merged)
                }
            }
        }
    }

    // Gemeinsamer farbiger Header (Normalmodus & Reorder-Modus)
    private func categoryHeaderChip(category: String, count: Int?, rightSFSymbol: String?) -> some View {
        let labelColor = viewModel.availableLabels.first(where: { $0.name == category })?.colorAsColor
        let backgroundColor = labelColor ?? category.deterministicColor()
        let textColor = backgroundColor.brightness() < 0.5 ? Color.white : Color.black

        return HStack {
            Text(category)
                .foregroundColor(textColor)
                .font(.headline)

            Spacer()

            if let count, count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(6)
                    .background(Circle().fill(textColor.opacity(0.15)))
                    .foregroundColor(textColor)
            }

            if let rightSFSymbol {
                Image(systemName: rightSFSymbol)
                    .foregroundColor(textColor.opacity(0.8))
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(height: 48) // gleiche Höhe im Reorder
        .background(backgroundColor)
        .cornerRadius(8)
    }

    private func reloadData() async {
        await viewModel.loadLabels()
        await viewModel.loadShoppingListFromServer()
        DispatchQueue.main.async {
            viewModel.shoppingList = viewModel.shoppingList.map { $0 }
            let merged = mergedCategoryOrder()
            if merged != categoryOrder {
                categoryOrder = merged
                CategoryOrderStore.save(merged)
            }
        }
    }

    private func inputSection(padding: CGFloat) -> some View {
        VStack(spacing: 12) {
            HStack {
                TextField(LocalizedStringProvider.localized("add_item_placeholder"), text: $newItemNote)
                    .padding(14)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
                    .focused($isInputFocused)
                    .onSubmit { addItem() }

                Button(action: addItem) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.accentColor)
                }
                .disabled(newItemNote.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryChip(label: nil, name: unlabeledName)
                    ForEach(viewModel.availableLabels, id: \.id) { label in
                        categoryChip(label: label, name: label.name)
                    }
                }
                .padding(.horizontal, 4)
            }

            if !isInputFocused {
                Button {
                    showArchiveAlert = true
                } label: {
                    HStack {
                        Image(systemName: "archivebox.fill")
                        Text(LocalizedStringProvider.localized("complete_shopping"))
                    }
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, padding > 0 ? padding : 16)
        .padding(.bottom, 12)
        .animation(.easeOut(duration: 0.3), value: keyboardHeight)
        .animation(.easeInOut, value: isInputFocused)
    }

    private func categoryChip(label: ShoppingItem.LabelWrapper?, name: String) -> some View {
        let isSelected = selectedLabel?.id == label?.id
        let color = label?.colorAsColor ?? name.deterministicColor()
        let backgroundColor = isSelected ? color.opacity(0.25) : color.opacity(0.15)
        let textColor = color.brightness() < 0.5 ? Color.white : .primary

        return Text(name)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .foregroundColor(isSelected ? .accentColor : textColor)
            .cornerRadius(20)
            .onTapGesture { selectedLabel = label }
    }

    struct PendingShoppingListQuantityChange: Codable, Equatable {
        let itemId: UUID
        let quantity: Double
    }

    private func addItem() {
        let trimmed = newItemNote.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        viewModel.addManualIngredient(note: trimmed, label: selectedLabel)
        viewModel.addLabelIfNeeded(selectedLabel)

        newItemNote = ""
        selectedLabel = nil

        withAnimation { showSuccessToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showSuccessToast = false }
        }
    }

    private func configureAPIIfNeeded() {}
}

// MARK: - Item Row

struct ShoppingListItemView: View {
    @State private var quantity: Double
    @State private var showCategoryPicker = false

    let item: ShoppingItem
    let onTap: () -> Void
    let onQuantityChange: (Double) -> Void

    @EnvironmentObject private var viewModel: ShoppingListViewModel

    init(item: ShoppingItem, onTap: @escaping () -> Void, onQuantityChange: @escaping (Double) -> Void) {
        self.item = item
        self.onTap = onTap
        self.onQuantityChange = onQuantityChange
        self._quantity = State(initialValue: item.quantity ?? 1)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                if quantity > 0 {
                    quantity -= 1
                    onQuantityChange(quantity)
                }
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(true)

            Text("\(Int(quantity))")
                .frame(width: 24)
                .font(.subheadline)
                .foregroundColor(.primary)

            Button(action: {
                quantity += 1
                onQuantityChange(quantity)
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(true)

            Text(item.note ?? "-")
                .font(.system(size: 16))
                .fontWeight(.semibold)
                .strikethrough(item.checked, color: .gray)
                .foregroundColor(item.checked ? .gray : .primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
                .onLongPressGesture(minimumDuration: 0.5) {
                    showCategoryPicker = true
                }

            Spacer()

            Button(action: onTap) {
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(item.checked ? .green : .gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
        .listRowBackground(Color.clear)
        .contentShape(Rectangle())
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerView(item: item) { newLabel in
                viewModel.updateItemCategory(item, to: newLabel)
            }
            .environmentObject(viewModel)
        }
    }
}

// MARK: - Category Order Persistence

private struct CategoryOrderStore {
    private static let key = "shoppingCategoryOrder"

    static func load() -> [String] {
        (UserDefaults.standard.array(forKey: key) as? [String]) ?? []
    }

    static func save(_ order: [String]) {
        UserDefaults.standard.set(order, forKey: key)
    }

    /// Nimmt die gespeicherte Reihenfolge, filtert unbekannte raus und hängt neue Kategorien unten an.
    static func mergedOrder(stored: [String], available: [String]) -> [String] {
        let filtered = stored.filter { available.contains($0) }
        let missing = available.filter { !filtered.contains($0) }
        return filtered + missing
    }
}

// MARK: - Misc

struct LabelCache {
    private static let cacheKey = "cachedLabels"

    static func save(_ labels: [ShoppingItem.LabelWrapper]) {
        if let data = try? JSONEncoder().encode(labels) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    static func load() -> [ShoppingItem.LabelWrapper] {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let labels = try? JSONDecoder().decode([ShoppingItem.LabelWrapper].self, from: data) {
            return labels
        }
        return []
    }
}

struct EmptyListView: View {
    let isLandscape: Bool

    var body: some View {
        Spacer()
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .resizable()
                .scaledToFit()
                .frame(width: isLandscape ? 120 : 80, height: isLandscape ? 120 : 80)
                .foregroundColor(Color.green)
                .shadow(radius: 4)

            Text(LocalizedStringProvider.localized("shopping_done_title"))
                .font(isLandscape ? .title : .title2)
                .fontWeight(.semibold)

            Text(LocalizedStringProvider.localized("shopping_done_subtitle"))
                .font(.subheadline)
                .foregroundColor(Color.secondary)
        }
        .frame(maxWidth: .infinity)
        Spacer()
    }
}

extension Publishers {
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .map { notification in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                    return 0
                }
                return frame.height
            }
            .eraseToAnyPublisher()
    }
}

extension String {
    func deterministicColor(saturation: Double = 0.5, brightness: Double = 0.85) -> Color {
        let hash = abs(self.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}

extension Color {
    func brightness() -> CGFloat {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (204, 204, 204)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
