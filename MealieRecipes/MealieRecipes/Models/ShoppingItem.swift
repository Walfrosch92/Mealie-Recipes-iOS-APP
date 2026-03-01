import SwiftUI
import Foundation

struct ShoppingItem: Identifiable, Codable {
    var id: UUID
    var note: String?
    var checked: Bool
    var shoppingListId: String
    var label: LabelWrapper?
    var quantity: Double? // NEU

    var category: String? {
        label?.name
    }

    enum CodingKeys: String, CodingKey {
        case id
        case note
        case checked
        case shoppingListId
        case label
        case quantity // NEU
    }

    struct LabelWrapper: Codable, Hashable, Identifiable {
        let id: String
        let name: String
        let slug: String?
        let color: String?

        var colorAsColor: Color {
            Color(hex: color ?? "#cccccc")
        }
    }
}
