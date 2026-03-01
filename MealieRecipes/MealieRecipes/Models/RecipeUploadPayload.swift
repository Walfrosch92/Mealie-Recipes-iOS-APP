import Foundation

// MARK: - UploadPayload (aus OpenAI oder OCR)
struct RecipeUploadPayload: Codable {
    var name: String
    var description: String
    var recipeYield: String
    var prepTime: String
    var cookTime: String
    var ingredients: [String]
    var instructions: [String]
}

extension RecipeUploadPayload {
    init?(from dictionary: [String: Any]) {
        guard
            let name = dictionary["name"] as? String,
            let description = dictionary["description"] as? String,
            let recipeYield = dictionary["recipeYield"] as? String,
            let prepTimeRaw = dictionary["prepTime"] as? String,
            let cookTimeRaw = dictionary["cookTime"] as? String,
            let ingredients = dictionary["ingredients"] as? [String],
            let instructions = dictionary["instructions"] as? [String]
        else {
            return nil
        }

        self.name = name
        self.description = description
        self.recipeYield = recipeYield
        self.prepTime = RecipeUploadPayload.convertTimeString(prepTimeRaw)
        self.cookTime = RecipeUploadPayload.convertTimeString(cookTimeRaw)
        self.ingredients = ingredients
        self.instructions = instructions
    }

    private static func convertTimeString(_ input: String) -> String {
        let components = input.components(separatedBy: CharacterSet.decimalDigits.inverted)
        let minutes = components.compactMap { Int($0) }.first ?? 0
        return "PT\(minutes)M"
    }
}

// MARK: - Mealie-kompatibler Payload für /api/recipes/
struct RecipeCreatePayload: Codable {
    let name: String
    let description: String
    let recipeYield: String
    let prepTime: String
    let cookTime: String
    let ingredients: [Ingredient]
    let instructions: [Instruction]

    struct Ingredient: Codable {
        let note: String
        let title: String
    }

    struct Instruction: Codable {
        var text: String
    }
}

// MARK: - Konvertierung von UploadPayload → RecipeCreatePayload
extension RecipeCreatePayload {
    init(from uploadPayload: RecipeUploadPayload) {
        self.name = uploadPayload.name
        self.description = uploadPayload.description
        self.recipeYield = uploadPayload.recipeYield
        self.prepTime = uploadPayload.prepTime
        self.cookTime = uploadPayload.cookTime

        self.ingredients = uploadPayload.ingredients.map {
            Ingredient(note: $0, title: $0)
        }

        self.instructions = uploadPayload.instructions.map {
            Instruction(text: $0)
        }
    }
}
