//
//  RecipeSummary.swift
//  MealieRecipes
//

import Foundation

struct RecipeSummary: Identifiable, Codable {
    let id: String
    let name: String
    let description: String?
    let tags: [RecipeTag]
    let recipeCategory: [Category]
    
    // Datums-Felder für Sortierung
    var dateAdded: Date?
    var dateUpdated: Date?
    var createdAt: Date?
    var updatedAt: Date?
    var lastMade: Date?
    
    // ⭐ Rating (Bewertung)
    var rating: Double?
    
    // MARK: - Memberwise Initializer (für Cache-Konvertierung)
    init(
        id: String,
        name: String,
        description: String? = nil,
        tags: [RecipeTag] = [],
        recipeCategory: [Category] = [],
        dateAdded: Date? = nil,
        dateUpdated: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        lastMade: Date? = nil,
        rating: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.tags = tags
        self.recipeCategory = recipeCategory
        self.dateAdded = dateAdded
        self.dateUpdated = dateUpdated
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastMade = lastMade
        self.rating = rating
    }
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case id, name, description, tags, recipeCategory
        case dateAdded, dateUpdated
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastMade = "last_made"
        case rating
    }
    
    // MARK: - Custom Decoder für flexible Datums-Formate
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Basis-Felder
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        tags = try container.decodeIfPresent([RecipeTag].self, forKey: .tags) ?? []
        recipeCategory = try container.decodeIfPresent([Category].self, forKey: .recipeCategory) ?? []
        
        // Datums-Felder mit flexiblem Decoder
        let dateDecoder = FlexibleDateDecoder()
        dateAdded = dateDecoder.decodeIfPresent(container, key: .dateAdded)
        dateUpdated = dateDecoder.decodeIfPresent(container, key: .dateUpdated)
        createdAt = dateDecoder.decodeIfPresent(container, key: .createdAt)
        updatedAt = dateDecoder.decodeIfPresent(container, key: .updatedAt)
        lastMade = dateDecoder.decodeIfPresent(container, key: .lastMade)
        
        // ⭐ Rating
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
    }
    
    // MARK: - Flexible Date Decoder
    struct FlexibleDateDecoder {
        func decodeIfPresent(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Date? {
            // Versuche verschiedene Formate
            if let dateString = try? container.decodeIfPresent(String.self, forKey: key) {
                let formatters: [Any] = [
                    ISO8601DateFormatter(),
                    {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        return formatter
                    }(),
                    {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                        formatter.timeZone = TimeZone(secondsFromGMT: 0)
                        return formatter
                    }(),
                    {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                        formatter.timeZone = TimeZone(secondsFromGMT: 0)
                        return formatter
                    }(),
                    {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        formatter.timeZone = TimeZone(secondsFromGMT: 0)
                        return formatter
                    }()
                ]
                
                for formatter in formatters {
                    if let isoFormatter = formatter as? ISO8601DateFormatter,
                       let date = isoFormatter.date(from: dateString) {
                        return date
                    } else if let dateFormatter = formatter as? DateFormatter,
                              let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                }
            }
            return nil
        }
    }
}
