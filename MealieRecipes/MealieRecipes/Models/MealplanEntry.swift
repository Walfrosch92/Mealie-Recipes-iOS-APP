import Foundation

struct MealplanEntry: Codable, Identifiable {
    let id: Int
    let date: String
    let entryType: String
    let recipe: RecipeSummary?
    let title: String? // wichtig für Freitexteinträge
    
    // Zusätzliche Felder, die die API zurückgeben könnte
    let text: String?
    let householdId: String?
    let groupId: Int?
    let userId: String?
    let recipeId: String?
    
    var slot: String { entryType }
    
    // MARK: - CodingKeys für flexible Dekodierung
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case entryType
        case recipe
        case title
        case text
        case householdId = "household_id"
        case groupId = "group_id"
        case userId = "user_id"
        case recipeId = "recipe_id"
    }
    
    // MARK: - Custom Decoder (optional fields)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Pflichtfelder
        id = try container.decode(Int.self, forKey: .id)
        date = try container.decode(String.self, forKey: .date)
        entryType = try container.decode(String.self, forKey: .entryType)
        
        // Optionale Felder
        recipe = try container.decodeIfPresent(RecipeSummary.self, forKey: .recipe)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        householdId = try container.decodeIfPresent(String.self, forKey: .householdId)
        groupId = try container.decodeIfPresent(Int.self, forKey: .groupId)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        recipeId = try container.decodeIfPresent(String.self, forKey: .recipeId)
    }
    
    // MARK: - Custom Encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(entryType, forKey: .entryType)
        try container.encodeIfPresent(recipe, forKey: .recipe)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(householdId, forKey: .householdId)
        try container.encodeIfPresent(groupId, forKey: .groupId)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encodeIfPresent(recipeId, forKey: .recipeId)
    }
}

struct MealplanRecipe: Codable {
    let id: String
    let name: String
    let image: String?
}

