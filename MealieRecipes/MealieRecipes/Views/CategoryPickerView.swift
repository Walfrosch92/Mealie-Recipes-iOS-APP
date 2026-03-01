import SwiftUI

struct CategoryPickerView: View {
    let item: ShoppingItem
    let onLabelSelected: (ShoppingItem.LabelWrapper?) -> Void

    @EnvironmentObject private var viewModel: ShoppingListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var editedNote: String
    @State private var showSaveConfirmation = false

    init(item: ShoppingItem, onLabelSelected: @escaping (ShoppingItem.LabelWrapper?) -> Void) {
        self.item = item
        self.onLabelSelected = onLabelSelected
        _editedNote = State(initialValue: item.note ?? "")
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text(LocalizedStringProvider.localized("edit_note"))) {
                    HStack {
                        TextField(LocalizedStringProvider.localized("note_placeholder"), text: $editedNote)
                            .textFieldStyle(.roundedBorder)
                            .disableAutocorrection(true)
                            .autocapitalization(.sentences)

                        Button(action: {
                            saveNoteIfChanged()
                            withAnimation {
                                showSaveConfirmation = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    showSaveConfirmation = false
                                }
                            }
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                    }

                    if showSaveConfirmation {
                        Text(LocalizedStringProvider.localized("note_saved"))
                            .font(.caption)
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }
                }

                Section(header: Text(LocalizedStringProvider.localized("select_category"))) {
                    Button(LocalizedStringProvider.localized("unlabeled_category")) {
                        onLabelSelected(nil)
                        saveNoteIfChanged()
                        dismiss()
                    }

                    let allLabels = Array(Set(viewModel.availableLabels + viewModel.shoppingList.compactMap { $0.label }))
                        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                    ForEach(allLabels, id: \.id) { label in
                        Button(label.name) {
                            onLabelSelected(label)
                            saveNoteIfChanged()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringProvider.localized("change_category"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringProvider.localized("cancel")) {
                        dismiss()
                    }
                }
            }
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text(LocalizedStringProvider.localized("delete_item_title")),
                    message: Text(LocalizedStringProvider.localized("delete_item_confirm")),
                    primaryButton: .destructive(Text(LocalizedStringProvider.localized("delete"))) {
                        viewModel.deleteItem(item)
                        dismiss()
                    },
                    secondaryButton: .cancel(Text(LocalizedStringProvider.localized("cancel")))
                )
            }
        }
    }

    private func saveNoteIfChanged() {
        let trimmed = editedNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != (item.note ?? "") else { return }

        var updated = item
        updated.note = trimmed
        Task {
            await viewModel.updateShoppingItem(updated)
        }
    }
}
