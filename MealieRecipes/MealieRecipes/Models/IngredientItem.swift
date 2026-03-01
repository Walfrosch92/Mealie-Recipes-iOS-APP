import Foundation

struct IngredientItem: Identifiable, Equatable {
    let id: UUID
    let name: String

    init(name: String) {
        self.id = UUID()
        self.name = name
    }

    static func == (lhs: IngredientItem, rhs: IngredientItem) -> Bool {
        lhs.id == rhs.id
    }
}

