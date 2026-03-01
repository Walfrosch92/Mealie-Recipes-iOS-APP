import SwiftUI

struct SyncChangesView: View {
    let pendingCheckChanges: [PendingCheckChange]
    let pendingQuantityChanges: [PendingQuantityChange]
    let pendingCategoryChanges: [PendingCategoryChange]
    let pendingAddChanges: [PendingAddChange]
    let localItems: [ShoppingItem]
    let serverItems: [ShoppingItem]
    let availableLabels: [ShoppingItem.LabelWrapper]

    @Binding var selectedCheckChanges: [UUID: Bool]
    @Binding var selectedQuantityChanges: [UUID: Bool]
    @Binding var selectedCategoryChanges: [UUID: Bool]
    @Binding var isSyncing: Bool

    var body: some View {
        List {
            checkSection
            quantitySection
            categorySection
            addSection
        }
        .navigationTitle(LocalizedStringProvider.localized("sync_changes_title"))
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var checkSection: some View {
        if !pendingCheckChanges.isEmpty {
            Section(header: Text(LocalizedStringProvider.localized("sync_changes_checked")).font(.title3).bold()) {
                ForEach(pendingCheckChanges, id: \.itemId) { change in
                    if let item = localItems.first(where: { $0.id == change.itemId }),
                       let server = serverItems.first(where: { $0.id == change.itemId }) {
                        SyncConflictComparisonRow(
                            title: item.note ?? "-",
                            localValue: change.checked ? "✓" : "○",
                            serverValue: server.checked ? "✓" : "○",
                            useLocal: Binding(
                                get: { selectedCheckChanges[change.itemId] ?? true },
                                set: { selectedCheckChanges[change.itemId] = $0 }
                            )
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var quantitySection: some View {
        if !pendingQuantityChanges.isEmpty {
            Section(header: Text(LocalizedStringProvider.localized("sync_changes_quantity")).font(.title3).bold()) {
                ForEach(pendingQuantityChanges, id: \.itemId) { change in
                    if let item = localItems.first(where: { $0.id == change.itemId }),
                       let server = serverItems.first(where: { $0.id == change.itemId }) {
                        SyncConflictComparisonRow(
                            title: item.note ?? "-",
                            localValue: String(Int(change.quantity)),
                            serverValue: String(Int(server.quantity ?? 1)),
                            useLocal: Binding(
                                get: { selectedQuantityChanges[change.itemId] ?? true },
                                set: { selectedQuantityChanges[change.itemId] = $0 }
                            )
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var categorySection: some View {
        if !pendingCategoryChanges.isEmpty {
            Section(header: Text(LocalizedStringProvider.localized("sync_changes_category")).font(.title3).bold()) {
                ForEach(pendingCategoryChanges, id: \.itemId) { change in
                    if let item = localItems.first(where: { $0.id == change.itemId }),
                       let server = serverItems.first(where: { $0.id == change.itemId }) {
                        let localLabel = availableLabels.first(where: { $0.id == change.labelId })?.name ?? "-"
                        let serverLabel = availableLabels.first(where: { $0.id == server.label?.id })?.name ?? "-"
                        SyncConflictComparisonRow(
                            title: item.note ?? "-",
                            localValue: localLabel,
                            serverValue: serverLabel,
                            useLocal: Binding(
                                get: { selectedCategoryChanges[change.itemId] ?? true },
                                set: { selectedCategoryChanges[change.itemId] = $0 }
                            )
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var addSection: some View {
        if !pendingAddChanges.isEmpty {
            Section(header: Text(LocalizedStringProvider.localized("sync_changes_additions")).font(.title3).bold()) {
                ForEach(pendingAddChanges) { change in
                    let labelName = availableLabels.first(where: { $0.id == change.labelId })?.name
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading) {
                            Text(change.note)
                                .fontWeight(.semibold)
                            if let labelName = labelName {
                                Text(labelName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}


struct SyncConflictComparisonRow: View {
    let title: String
    let localValue: String
    let serverValue: String
    @Binding var useLocal: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    valueView(for: localValue, highlight: useLocal)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { !useLocal },      // Rechts = server → useLocal = false
                    set: { useLocal = !$0 }  // Links = local → useLocal = true
                ))
                .labelsHidden()
                .frame(width: 50)
                .padding(.horizontal)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Server")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    valueView(for: serverValue, highlight: !useLocal)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func valueView(for value: String, highlight: Bool) -> some View {
        if value == "largecircle.fill.circle" || value == "circle" {
            Image(systemName: value)
                .font(.system(size: 20))
                .foregroundColor(highlight ? .green : .primary)
        } else {
            Text(value)
                .foregroundColor(highlight ? .green : .primary)
        }
    }

    static func symbolForCheckmark(_ checked: Bool) -> String {
        return checked ? "largecircle.fill.circle" : "circle"
    }
}



