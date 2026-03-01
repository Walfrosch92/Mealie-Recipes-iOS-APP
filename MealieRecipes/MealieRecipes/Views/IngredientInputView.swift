import SwiftUI

struct IngredientInputView: View {
    @ObservedObject var model: IngredientInputModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField(LocalizedStringProvider.localized("leftover.enter_ingredient"), text: $model.newIngredient)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done) // Tastatur-Label auf "Fertig"
                    .onSubmit {
                        addIngredient()
                    }

                Button {
                    addIngredient()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(model.newIngredient.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !model.enteredIngredients.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(model.enteredIngredients) { item in
                            HStack {
                                Text(item.name)
                                Button {
                                    model.removeIngredient(item)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func addIngredient() {
        let trimmed = model.newIngredient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        model.addIngredient(trimmed)
        model.newIngredient = ""
    }
}
