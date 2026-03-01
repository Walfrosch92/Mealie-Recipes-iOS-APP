import Foundation

struct ShoppingList: Codable, Identifiable, Equatable {
    let id: String
    let name: String
}

import Foundation

/// Die komplette Antwortstruktur von /api/households/shopping/lists
struct ShoppingListResponse: Decodable {
    let items: [ShoppingList]
}


