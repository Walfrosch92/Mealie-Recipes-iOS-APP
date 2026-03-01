import Testing
import Foundation
@testable import YourMealieApp

// MARK: - Ingredient Decoding Tests

@Suite("Ingredient Decoding")
struct IngredientDecodingTests {
    
    // MARK: - Happy Path
    
    @Test("Vollständige Zutat mit allen Feldern")
    func decodeCompleteIngredient() async throws {
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "quantity": 2.5,
            "unit": "kg",
            "food": "Mehl",
            "note": "Type 405, Bio",
            "original_text": "2.5 kg Mehl (Type 405, Bio)",
            "reference_id": "ref-123"
        }
        """
        
        let data = json.data(using: .utf8)!
        let dto = try JSONDecoder().decode(MealieIngredientDTO.self, from: data)
        
        #expect(dto.quantity == 2.5)
        #expect(dto.unit == "kg")
        #expect(dto.food == "Mehl")
        #expect(dto.note == "Type 405, Bio") // 🔥 Kritischer Test!
        #expect(dto.originalText == "2.5 kg Mehl (Type 405, Bio)")
        
        // Domain Model Conversion
        let ingredient = Ingredient.from(dto: dto)
        #expect(ingredient.name == "Mehl")
        #expect(ingredient.hasNote == true)
        #expect(ingredient.note == "Type 405, Bio")
    }
    
    // MARK: - Edge Cases
    
    @Test("Zutat mit null-Werten")
    func decodeIngredientWithNulls() async throws {
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "quantity": null,
            "unit": null,
            "food": "Salz",
            "note": null
        }
        """
        
        let data = json.data(using: .utf8)!
        let dto = try JSONDecoder().decode(MealieIngredientDTO.self, from: data)
        
        #expect(dto.quantity == nil)
        #expect(dto.unit == nil)
        #expect(dto.food == "Salz")
        #expect(dto.note == nil)
        
        // Domain Model sollte trotzdem funktionieren
        let ingredient = Ingredient.from(dto: dto)
        #expect(ingredient.name == "Salz")
        #expect(ingredient.note == "") // Nie nil in UI!
        #expect(ingredient.hasNote == false)
    }
    
    @Test("Zutat mit fehlenden optionalen Feldern")
    func decodeIngredientWithMissingFields() async throws {
        let json = """
        {
            "food": "Zucker"
        }
        """
        
        let data = json.data(using: .utf8)!
        let dto = try JSONDecoder().decode(MealieIngredientDTO.self, from: data)
        
        // Sollte UUID generieren wenn fehlend
        #expect(dto.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        #expect(dto.food == "Zucker")
        
        // Alle anderen Felder sollten nil sein
        #expect(dto.quantity == nil)
        #expect(dto.unit == nil)
        #expect(dto.note == nil)
    }
    
    @Test("Zutat mit leeren Strings")
    func decodeIngredientWithEmptyStrings() async throws {
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "quantity": 1,
            "unit": "",
            "food": "Eier",
            "note": ""
        }
        """
        
        let data = json.data(using: .utf8)!
        let dto = try JSONDecoder().decode(MealieIngredientDTO.self, from: data)
        
        // Leere Strings sollten als nil behandelt werden
        #expect(dto.unit == nil)
        #expect(dto.note == nil)
        #expect(dto.food == "Eier")
    }
    
    @Test("Zutat nur mit original_text (ungeparst)")
    func decodeUnparsedIngredient() async throws {
        let json = """
        {
            "original_text": "Eine Prise Salz"
        }
        """
        
        let data = json.data(using: .utf8)!
        let dto = try JSONDecoder().decode(MealieIngredientDTO.self, from: data)
        
        #expect(dto.originalText == "Eine Prise Salz")
        
        // Domain Model sollte original_text als Fallback nutzen
        let ingredient = Ingredient.from(dto: dto)
        #expect(ingredient.name == "Eine Prise Salz")
        #expect(ingredient.originalText == "Eine Prise Salz")
    }
    
    @Test("Zutat mit 'title' statt 'food'")
    func decodeIngredientWithTitle() async throws {
        let json = """
        {
            "title": "Butter",
            "quantity": 100,
            "unit": "g"
        }
        """
        
        let data = json.data(using: .utf8)!
        let dto = try JSONDecoder().decode(MealieIngredientDTO.self, from: data)
        
        #expect(dto.title == "Butter")
        #expect(dto.food == nil)
        
        // Domain Model sollte title als Fallback nutzen
        let ingredient = Ingredient.from(dto: dto)
        #expect(ingredient.name == "Butter")
    }
    
    @Test("Zutat mit disable_amount Flag")
    func decodeIngredientWithDisabledAmount() async throws {
        let json = """
        {
            "food": "Salz",
            "quantity": 1,
            "unit": "TL",
            "disable_amount": true
        }
        """
        
        let data = json.data(using: .utf8)!
        let dto = try JSONDecoder().decode(MealieIngredientDTO.self, from: data)
        
        #expect(dto.disableAmount == true)
        
        let ingredient = Ingredient.from(dto: dto)
        #expect(ingredient.shouldDisplayAmount == false)
        
        // Display-Text sollte keine Menge zeigen
        #expect(!ingredient.displayText.contains("1"))
    }
    
    // MARK: - Display Text Tests
    
    @Test("Display Text Formatierung")
    func displayTextFormatting() async throws {
        let ingredient = Ingredient(
            id: UUID(),
            quantityText: "2",
            unit: "kg",
            name: "Mehl",
            note: "Bio",
            originalText: "",
            quantityValue: 2,
            referenceId: nil,
            shouldDisplayAmount: true
        )
        
        #expect(ingredient.displayText == "2 kg Mehl (Bio)")
    }
    
    @Test("Display Text ohne Menge")
    func displayTextWithoutQuantity() async throws {
        let ingredient = Ingredient(
            id: UUID(),
            quantityText: "",
            unit: "",
            name: "Prise Salz",
            note: "",
            originalText: "",
            quantityValue: nil,
            referenceId: nil,
            shouldDisplayAmount: false
        )
        
        #expect(ingredient.displayText == "Prise Salz")
    }
    
    @Test("Display Text mit Note aber ohne Menge")
    func displayTextWithNoteOnly() async throws {
        let ingredient = Ingredient(
            id: UUID(),
            quantityText: "",
            unit: "",
            name: "Butter",
            note: "zimmerwarm",
            originalText: "",
            quantityValue: nil,
            referenceId: nil,
            shouldDisplayAmount: true
        )
        
        #expect(ingredient.displayText == "Butter (zimmerwarm)")
    }
    
    @Test("Quantity Text Formatierung - Ganze Zahlen")
    func quantityFormattingWholeNumbers() async throws {
        let dto = MealieIngredientDTO(
            id: UUID(),
            quantity: 3.0,
            unit: "Stk",
            food: "Eier",
            note: nil,
            title: nil,
            originalText: nil,
            display: nil,
            referenceId: nil,
            disableAmount: nil
        )
        
        let ingredient = Ingredient.from(dto: dto)
        
        // Sollte "3" sein, nicht "3.0"
        #expect(ingredient.quantityText == "3")
    }
    
    @Test("Quantity Text Formatierung - Dezimalzahlen")
    func quantityFormattingDecimals() async throws {
        let dto = MealieIngredientDTO(
            id: UUID(),
            quantity: 2.5,
            unit: "kg",
            food: "Mehl",
            note: nil,
            title: nil,
            originalText: nil,
            display: nil,
            referenceId: nil,
            disableAmount: nil
        )
        
        let ingredient = Ingredient.from(dto: dto)
        #expect(ingredient.quantityText == "2.5")
    }
}

// MARK: - Recipe Decoding Tests

@Suite("Recipe Decoding")
struct RecipeDecodingTests {
    
    @Test("Rezept mit recipe_ingredient Feld")
    func decodeRecipeWithRecipeIngredient() async throws {
        let json = """
        {
            "id": "recipe-123",
            "name": "Brot",
            "description": "Leckeres Brot",
            "recipe_ingredient": [
                {
                    "food": "Mehl",
                    "quantity": 500,
                    "unit": "g"
                }
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let dto = try JSONDecoder().decode(MealieRecipeDTO.self, from: data)
        
        #expect(dto.recipeIngredient?.count == 1)
        #expect(dto.allIngredients.count == 1)
        #expect(dto.allIngredients.first?.food == "Mehl")
    }
    
    @Test("Rezept mit ingredients Feld (alternative API-Version)")
    func decodeRecipeWithIngredientsField() async throws {
        let json = """
        {
            "id": "recipe-123",
            "name": "Brot",
            "ingredients": [
                {
                    "food": "Mehl",
                    "quantity": 500,
                    "unit": "g"
                }
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let dto = try JSONDecoder().decode(MealieRecipeDTO.self, from: data)
        
        #expect(dto.ingredients?.count == 1)
        #expect(dto.allIngredients.count == 1)
    }
    
    @Test("Rezept ohne Zutaten")
    func decodeRecipeWithoutIngredients() async throws {
        let json = """
        {
            "id": "recipe-123",
            "name": "Brot"
        }
        """
        
        let data = json.data(using: .utf8)!
        let dto = try JSONDecoder().decode(MealieRecipeDTO.self, from: data)
        
        #expect(dto.allIngredients.isEmpty)
        
        let recipe = Recipe.from(dto: dto)
        #expect(recipe.ingredients.isEmpty)
    }
    
    @Test("Rezept mit leerer Zutatenliste")
    func decodeRecipeWithEmptyIngredients() async throws {
        let json = """
        {
            "id": "recipe-123",
            "name": "Brot",
            "recipe_ingredient": []
        }
        """
        
        let data = json.data(using: .utf8)!
        let dto = try JSONDecoder().decode(MealieRecipeDTO.self, from: data)
        
        #expect(dto.allIngredients.isEmpty)
    }
}

// MARK: - Array Extension Tests

@Suite("Array Extensions")
struct ArrayExtensionTests {
    
    @Test("toIngredients mappt ALLE DTOs")
    func mapAllIngredients() async throws {
        let dtos = [
            MealieIngredientDTO(
                id: UUID(),
                quantity: nil,
                unit: nil,
                food: "Zutat 1",
                note: nil,
                title: nil,
                originalText: nil,
                display: nil,
                referenceId: nil,
                disableAmount: nil
            ),
            MealieIngredientDTO(
                id: UUID(),
                quantity: 2,
                unit: "kg",
                food: "Zutat 2",
                note: "Test",
                title: nil,
                originalText: nil,
                display: nil,
                referenceId: nil,
                disableAmount: nil
            )
        ]
        
        let ingredients = dtos.toIngredients()
        
        // 🔥 WICHTIG: Keine Zutat darf verloren gehen!
        #expect(ingredients.count == 2)
        #expect(ingredients[0].name == "Zutat 1")
        #expect(ingredients[1].name == "Zutat 2")
        #expect(ingredients[1].hasNote == true)
    }
}

// MARK: - Manual DTO Init (für Tests)

extension MealieIngredientDTO {
    init(
        id: UUID,
        quantity: Double?,
        unit: String?,
        food: String?,
        note: String?,
        title: String?,
        originalText: String?,
        display: String?,
        referenceId: String?,
        disableAmount: Bool?
    ) {
        self.id = id
        self.quantity = quantity
        self.unit = unit
        self.food = food
        self.note = note
        self.title = title
        self.originalText = originalText
        self.display = display
        self.referenceId = referenceId
        self.disableAmount = disableAmount
    }
}
