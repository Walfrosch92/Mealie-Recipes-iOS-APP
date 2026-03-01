import Foundation
import Combine

class IngredientInputModel: ObservableObject {
    @Published var newIngredient: String = ""
    @Published var enteredIngredients: [IngredientItem] = []

    func addIngredient(_ item: String) {
        let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let alreadyExists = enteredIngredients.contains {
            $0.name.lowercased() == trimmed.lowercased()
        }

        guard !alreadyExists else { return }

        enteredIngredients.append(IngredientItem(name: trimmed))
    }

    func removeIngredient(_ item: IngredientItem) {
        enteredIngredients.removeAll { $0.id == item.id }
    }

    func clear() {
        enteredIngredients.removeAll()
    }
}
