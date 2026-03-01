import SwiftUI

struct ArchivedShoppingListsView: View {
    @EnvironmentObject var viewModel: ShoppingListViewModel
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                let horizontalPadding = isLandscape ? geometry.size.width * 0.2 : 0.0

                List {
                    let indexedLists = Array(viewModel.archivedLists.enumerated())

                    ForEach(indexedLists, id: \.offset) { (index, list) in
                        Section(header: Text(String(format: LocalizedStringProvider.localized("list_title"), index + 1))) {
                            ForEach(list) { item in
                                Text(item.note ?? "-")
                                    .strikethrough(item.checked, color: .gray)
                                    .foregroundColor(item.checked ? .gray : .primary)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                    .onDelete(perform: deleteArchivedList)
                }
                .listStyle(.insetGrouped)
                .padding(.horizontal, horizontalPadding)
                .navigationTitle(LocalizedStringProvider.localized("archived_lists"))
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if !viewModel.archivedLists.isEmpty {
                            Button(LocalizedStringProvider.localized("delete_all")) {
                                showDeleteConfirmation = true
                            }
                        }
                    }
                }
                .alert(LocalizedStringProvider.localized("delete_confirm_title"), isPresented: $showDeleteConfirmation) {
                    Button(LocalizedStringProvider.localized("delete"), role: .destructive) {
                        viewModel.deleteAllArchivedLists()
                    }
                    Button(LocalizedStringProvider.localized("cancel"), role: .cancel) { }
                } message: {
                    Text(LocalizedStringProvider.localized("delete_confirm_message"))
                }
            }
        }
    }

    private func deleteArchivedList(at offsets: IndexSet) {
        viewModel.deleteArchivedList(at: offsets)
    }
}
