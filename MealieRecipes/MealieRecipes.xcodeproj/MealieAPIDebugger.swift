import Foundation

/// Debug-Utility für Mealie API Responses
struct MealieAPIDebugger {
    
    /// Loggt die Raw Response für Analyse
    static func logRawResponse(_ data: Data, endpoint: String) {
        print("📡 === RAW API RESPONSE: \(endpoint) ===")
        
        // Pretty-printed JSON
        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            print(prettyString)
        } else {
            // Fallback: Raw String
            print(String(data: data, encoding: .utf8) ?? "❌ Could not decode data")
        }
        
        print("📡 === END RAW RESPONSE ===\n")
    }
    
    /// Validiert Ingredient-Felder gegen erwartetes Schema
    static func validateIngredientSchema(_ json: [String: Any]) -> [String] {
        var issues: [String] = []
        
        let expectedFields = ["quantity", "unit", "food", "note", "title", "original_text"]
        
        for field in expectedFields {
            if json[field] == nil {
                issues.append("⚠️ Fehlendes Feld: \(field)")
            } else if let value = json[field], value is NSNull {
                issues.append("⚠️ Null-Wert in: \(field)")
            }
        }
        
        return issues
    }
    
    /// Testet Decoding mit verschiedenen Edge Cases
    static func testIngredientDecoding() {
        let testCases: [[String: Any?]] = [
            // Normal
            ["quantity": 2.5, "unit": "kg", "food": "Mehl", "note": "Bio"],
            
            // Null-Werte
            ["quantity": NSNull(), "unit": NSNull(), "food": "Salz", "note": NSNull()],
            
            // Fehlende Felder
            ["food": "Zucker"],
            
            // Leere Strings
            ["quantity": 1, "unit": "", "food": "Eier", "note": ""],
            
            // Nur original_text
            ["original_text": "2 kg Mehl (Bio)"]
        ]
        
        for (index, testCase) in testCases.enumerated() {
            print("🧪 Test Case \(index + 1):")
            
            do {
                let data = try JSONSerialization.data(withJSONObject: testCase)
                let ingredient = try JSONDecoder().decode(MealieIngredient.self, from: data)
                print("✅ Erfolgreich decodiert: \(ingredient)")
            } catch {
                print("❌ Decoding fehlgeschlagen: \(error)")
                if let decodingError = error as? DecodingError {
                    printDecodingError(decodingError)
                }
            }
            print("")
        }
    }
    
    static func printDecodingError(_ error: DecodingError) {
        switch error {
        case .keyNotFound(let key, let context):
            print("   Key '\(key.stringValue)' nicht gefunden in: \(context.codingPath)")
        case .typeMismatch(let type, let context):
            print("   Type Mismatch für \(type) in: \(context.codingPath)")
        case .valueNotFound(let type, let context):
            print("   Wert nicht gefunden für \(type) in: \(context.codingPath)")
        case .dataCorrupted(let context):
            print("   Daten korrupt: \(context)")
        @unknown default:
            print("   Unbekannter Decoding-Fehler")
        }
    }
}
