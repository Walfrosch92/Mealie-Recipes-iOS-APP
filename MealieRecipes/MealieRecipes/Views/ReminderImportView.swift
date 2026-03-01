//
//  ProposedItem.swift
//  MealieRecipes
//
//  Created by Michael Haiszan on 17.08.25.
//


// RemindersImportFlowView.swift
import SwiftUI
import EventKit

fileprivate struct ProposedItem: Identifiable, Hashable {
    let id = UUID()
    let reminderId: String
    let name: String
    var quantity: Double?
    let unit: String?
    let categoryHint: String?
    // Mapping
    var mappedLabel: ShoppingItem.LabelWrapper?
    // Konflikt
    var hasConflict: Bool
    var keepLocal: Bool = false   // wenn Konflikt: Entscheidung
}

struct RemindersImportFlowView: View {
    @EnvironmentObject private var viewModel: ShoppingListViewModel
    @Binding var isPresented: Bool

    @State private var step: Step = .precheck
    @State private var calendars: [EKCalendar] = []
    @State private var selectedCalendarId: String? = RemindersImportConfigStore.selectedListId
    @State private var isGrocery: Bool = RemindersImportConfigStore.selectedListIsGrocery

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var proposals: [ProposedItem] = []
    @State private var selected: Set<UUID> = []
    @State private var hasRequestedAccess = false

    private let importer = RemindersImporter()

    enum Step { case precheck, pickCalendar, fetching, review }

    // ⬇️ NEU: Post-Import-Aktion
    enum PostAction: Int, CaseIterable, Identifiable { case leave = 0, complete, completeAndDelete
        var id: Int { rawValue }
    }
    @State private var postAction: PostAction = .leave

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(LocalizedStringProvider.localized("import_from_reminders"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(LocalizedStringProvider.localized("cancel")) { isPresented = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if step == .review {
                            Button(LocalizedStringProvider.localized("import_now")) { Task { await applyImport() } }
                                .disabled(selected.isEmpty)
                        }
                    }
                }
                .task {
                    if step == .precheck {
                        await prepare()
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .precheck:
            VStack(spacing: 16) {
                ProgressView()
                Text(LocalizedStringProvider.localized("checking_permissions"))
                    .foregroundColor(.secondary)
            }
            .padding()
        case .pickCalendar:
            Form {
                if let error = errorMessage {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(LocalizedStringProvider.localized("error"), systemImage: "exclamationmark.triangle")
                                .foregroundColor(.red)
                                .font(.headline)
                            Text(error)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section(LocalizedStringProvider.localized("reminders_choose_list")) {
                    if calendars.isEmpty && errorMessage == nil {
                        HStack {
                            ProgressView()
                            Text(LocalizedStringProvider.localized("loading"))
                        }
                    } else if !calendars.isEmpty {
                        Picker(LocalizedStringProvider.localized("reminders_list"), selection: $selectedCalendarId) {
                            ForEach(calendars, id: \.calendarIdentifier) { c in
                                Text(c.title).tag(Optional(c.calendarIdentifier))
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Toggle(LocalizedStringProvider.localized("this_is_grocery_list"), isOn: $isGrocery)
                            .help(LocalizedStringProvider.localized("this_is_grocery_list_help"))
                    }
                }
                
                if errorMessage == nil {
                    Section {
                        Button {
                            Task { await fetchAndBuildProposals() }
                        } label: {
                            HStack {
                                Spacer()
                                if isLoading { ProgressView() } else { Text(LocalizedStringProvider.localized("continue")) }
                                Spacer()
                            }
                        }
                        .disabled(selectedCalendarId == nil || isLoading || calendars.isEmpty)
                    }
                }
            }
            .onAppear { 
                if calendars.isEmpty {
                    Task { await loadCalendars() } 
                }
            }

        case .fetching:
            VStack(spacing: 16) {
                ProgressView(LocalizedStringProvider.localized("importing_from_reminders"))
                Text(LocalizedStringProvider.localized("please_wait"))
                    .foregroundColor(.secondary)
            }
            .padding()

        case .review:
            List {
                if let err = errorMessage {
                    Text(err).foregroundColor(.red)
                }
                ForEach(proposals) { p in
                    ReviewRow(
                        proposal: p,
                        isSelected: selected.contains(p.id),
                        toggle: { if selected.contains(p.id) { selected.remove(p.id) } else { selected.insert(p.id) } },
                        availableLabels: viewModel.availableLabels,
                        onLabelChange: { newLabel in
                            if let idx = proposals.firstIndex(where: { $0.id == p.id }) {
                                proposals[idx].mappedLabel = newLabel
                            }
                        },
                        onKeepLocalChange: { keepLocal in
                            if let idx = proposals.firstIndex(where: { $0.id == p.id }) {
                                proposals[idx].keepLocal = keepLocal
                            }
                        }
                    )
                }

                // ⬇️ NEU: Nach-Import-Aktion
                Section(footer: Text(LocalizedStringProvider.localized("postimport_hint"))) {
                    Picker(LocalizedStringProvider.localized("postimport_action"),
                           selection: $postAction) {
                        Text(LocalizedStringProvider.localized("postimport_leave")).tag(PostAction.leave)
                        Text(LocalizedStringProvider.localized("postimport_complete")).tag(PostAction.complete)
                        Text(LocalizedStringProvider.localized("postimport_complete_delete")).tag(PostAction.completeAndDelete)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .onAppear {
                // per default alle selektieren, die keinen Konflikt haben
                selected = Set(proposals.filter { !$0.hasConflict }.map { $0.id })
            }
        }
    }

    // MARK: Steps

    private func prepare() async {
        guard !hasRequestedAccess else {
            step = .pickCalendar
            return
        }
        
        do {
            try await importer.requestAccess()
            hasRequestedAccess = true
            step = .pickCalendar
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                step = .pickCalendar // Trotzdem weitergehen, um Fehler anzuzeigen
            }
        }
    }

    private func loadCalendars() async {
        // Wenn wir noch keinen Zugriff angefordert haben, mache das jetzt
        if !hasRequestedAccess {
            await prepare()
        }
        
        // Prüfe erneut, ob wir Zugriff haben
        guard importer.hasAccess() else {
            await MainActor.run {
                errorMessage = LocalizedStringProvider.localized("reminders_access_denied")
            }
            return
        }
        
        let cals = importer.listReminderCalendars()
        await MainActor.run {
            calendars = cals
            if selectedCalendarId == nil, let first = cals.first {
                selectedCalendarId = first.calendarIdentifier
            }
        }
    }

    private func fetchAndBuildProposals() async {
        guard let calId = selectedCalendarId else { return }
        isLoading = true
        errorMessage = nil
        step = .fetching
        do {
            let reminders = try await importer.fetchReminders(in: calId)
            // Persist Auswahl
            RemindersImportConfigStore.selectedListId = calId
            RemindersImportConfigStore.selectedListIsGrocery = isGrocery

            let imported = reminders.compactMap { importer.toImported($0, isGrocery: isGrocery) }

            // Dedupe gegen Cache
            let cache = RemindersImportConfigStore.importedIdCache()
            let fresh = imported.filter { !cache.contains($0.id) }

            // Map Kategorien → Label
            let mapped: [ProposedItem] = fresh.map { r in
                let label = GroceryCategoryMapper.map(categoryHint: r.categoryCandidate, availableLabels: viewModel.availableLabels)
                // Konflikt: existiert bereits lokales Item mit gleichem Name+Label? (normalisiert)
                let hasConflict = viewModel.shoppingList.contains { item in
                    let sameNote = (item.note ?? "").trimmedCondensedLowercased == r.name.trimmedCondensedLowercased
                    let sameLabel = (item.label?.id == label?.id) || 
                                    ((item.label?.name ?? "").trimmedCondensedLowercased == (label?.name ?? "").trimmedCondensedLowercased)
                    return sameNote && sameLabel
                }
                return ProposedItem(
                    reminderId: r.id,
                    name: r.name,
                    quantity: r.quantity,
                    unit: r.unit,
                    categoryHint: r.categoryCandidate,
                    mappedLabel: label,
                    hasConflict: hasConflict,
                    keepLocal: false
                )
            }

            proposals = mapped
            step = .review
        } catch {
            errorMessage = error.localizedDescription
            step = .review
        }
        isLoading = false
    }

    private func applyImport() async {
        var importedReminderIds: [String] = []
        
        // Sammle alle Items die wir hinzufügen wollen mit ihren Mengen
        var itemsToAdd: [(name: String, label: ShoppingItem.LabelWrapper?, quantity: Double?, reminderId: String)] = []
        
        for p in proposals where selected.contains(p.id) {
            if p.hasConflict && p.keepLocal { continue }
            itemsToAdd.append((name: p.name, label: p.mappedLabel, quantity: p.quantity, reminderId: p.reminderId))
        }

        // 1) LOKAL übernehmen auf dem MainActor
        await MainActor.run {
            for item in itemsToAdd {
                // Merke IDs VOR dem Hinzufügen
                let preIds = Set(viewModel.shoppingList.map { $0.id })
                
                // Item hinzufügen
                viewModel.addManualIngredient(note: item.name, label: item.label)
                viewModel.addLabelIfNeeded(item.label)
                
                // Versuche das neue Item zu finden
                if let newItem = viewModel.shoppingList.first(where: { shoppingItem in
                    !preIds.contains(shoppingItem.id)
                }) {
                    // Menge setzen, falls vorhanden
                    if let quantity = item.quantity, quantity > 0 {
                        viewModel.updateQuantity(for: newItem, to: quantity)
                    }
                }
                
                importedReminderIds.append(item.reminderId)
                
                // Import-Dedupe-Cache aktualisieren
                var cache = RemindersImportConfigStore.importedIdCache()
                cache.insert(item.reminderId)
                RemindersImportConfigStore.saveImportedIdCache(cache)
            }
        }

        // 2) Reminders-Nachverarbeitung (abhaken/löschen)
        do {
            switch postAction {
            case .leave: break
            case .complete:
                try importer.complete(reminderIds: importedReminderIds)
            case .completeAndDelete:
                try importer.complete(reminderIds: importedReminderIds)
                try importer.remove(reminderIds: importedReminderIds)
            }
        } catch {
            await MainActor.run {
                errorMessage = LocalizedStringProvider.localized("postimport_failed_generic")
            }
        }

        // 3) Pending-Änderungen hochsynchronisieren (ohne Review-Sheet)
        // Falls deine sync-Methode Additions implizit mitnimmt, reicht dieser Call:
        await viewModel.syncPendingChangesToServer(
            selectedCheckChanges: [:],
            selectedQuantityChanges: [:],
            selectedCategoryChanges: [:]
        )

        // Kurzer Nudge, damit der Server konsistent antwortet (optional, aber praktisch)
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s

        // 4) Frisch laden & Sheet schließen (MainActor für UI)
        await viewModel.loadLabels()
        await viewModel.loadShoppingListFromServer()
        await MainActor.run {
            // kleiner Re-render-Kick, falls SwiftUI diff nicht triggert
            viewModel.shoppingList = viewModel.shoppingList.map { $0 }
            isPresented = false
        }
    }


}

fileprivate struct ReviewRow: View {
    let proposal: ProposedItem
    let isSelected: Bool
    let toggle: () -> Void

    let availableLabels: [ShoppingItem.LabelWrapper]
    let onLabelChange: (ShoppingItem.LabelWrapper?) -> Void
    let onKeepLocalChange: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Button(action: toggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .green : .gray)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(proposal.name).font(.headline)

                    HStack(spacing: 12) {
                        if let q = proposal.quantity {
                            Text(String(format: "× %.2f", q)).font(.subheadline).foregroundColor(.secondary)
                        }
                        if let unit = proposal.unit {
                            Text(unit).font(.subheadline).foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Menu {
                            Button(LocalizedStringProvider.localized("unlabeled_category")) {
                                onLabelChange(nil)
                            }
                            ForEach(availableLabels, id: \.id) { label in
                                Button(label.name) { onLabelChange(label) }
                            }
                        } label: {
                            let labelName = proposal.mappedLabel?.name ?? LocalizedStringProvider.localized("unlabeled_category")
                            Label(labelName, systemImage: "tag")
                        }

                        Spacer()

                        if proposal.hasConflict {
                            Picker("", selection: Binding(
                                get: { proposal.keepLocal ? 0 : 1 },
                                set: { onKeepLocalChange($0 == 0) }
                            )) {
                                Text(LocalizedStringProvider.localized("keep_local")).tag(0)
                                Text(LocalizedStringProvider.localized("use_new")).tag(1)
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 220)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}
