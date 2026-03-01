//
//  KeyboardDismissHelper.swift
//  MealieRecipes
//
//  SwiftUI-native Lösung für Keyboard-Probleme beim Speichern
//

import SwiftUI

// MARK: - View Extension für Keyboard Dismiss
extension View {
    /// Versteckt die Tastatur, bevor eine Action ausgeführt wird
    /// Verhindert RTIInputSystemClient Warnungen
    func dismissingKeyboard(before action: @escaping () async -> Void) -> some View {
        self.modifier(KeyboardDismissModifier(action: action))
    }
}

// MARK: - ViewModifier für Keyboard Dismiss
private struct KeyboardDismissModifier: ViewModifier {
    let action: () async -> Void
    @FocusState private var isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onChange(of: isFocused) { _, newValue in
                if !newValue {
                    // Keyboard wurde versteckt, führe Action aus
                    Task {
                        // Kurze Verzögerung, damit Keyboard-Animation abgeschlossen ist
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 Sekunden
                        await action()
                    }
                }
            }
    }
}

// MARK: - Environment Helper für Keyboard Dismiss
extension View {
    /// Versteckt die Tastatur sofort (für Button Actions)
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// MARK: - Button Extension für sicheres Speichern
extension View {
    /// Button-Wrapper der automatisch die Tastatur versteckt vor dem Speichern
    func dismissKeyboardOnTap(perform action: @escaping () async throws -> Void) -> some View {
        self.simultaneousGesture(TapGesture().onEnded { _ in
            hideKeyboard()
        })
        .onTapGesture {
            Task {
                // Warte kurz, bis Keyboard versteckt ist
                try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 Sekunden
                try? await action()
            }
        }
    }
}

// MARK: - @FocusState Helper für EditRecipeView
/// FocusState-Wrapper für RecipeEdit-Felder
enum RecipeEditField: Hashable {
    case name
    case description
    case prepTime
    case cookTime
    case totalTime
    case servings
    case ingredient(UUID)
    case instruction(UUID)
    case none
}

// MARK: - Usage Example (Kommentar)
/*
 
 Verwendung in EditRecipeView:
 
 struct EditRecipeView: View {
     @FocusState private var focusedField: RecipeEditField?
     @State private var isSaving = false
     
     var body: some View {
         Form {
             Section("Recipe Details") {
                 TextField("Name", text: $recipe.name)
                     .focused($focusedField, equals: .name)
                 
                 TextField("Description", text: $recipe.description)
                     .focused($focusedField, equals: .description)
             }
         }
         .toolbar {
             ToolbarItem(placement: .confirmationAction) {
                 Button("Save") {
                     saveRecipe()
                 }
                 .disabled(isSaving)
             }
         }
     }
     
     private func saveRecipe() {
         // ✅ Wichtig: Keyboard zuerst verstecken!
         focusedField = nil
         
         Task {
             // Warte kurz, bis Keyboard versteckt ist
             try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 Sekunden
             
             isSaving = true
             defer { isSaving = false }
             
             do {
                 let payload = RecipeUpdatePayload(from: recipe)
                 try await APIService.shared.updateFullRecipe(
                     originalSlug: originalSlug,
                     payload: payload
                 )
                 onSave(recipe)
             } catch {
                 print("❌ Fehler beim Speichern: \(error)")
             }
         }
     }
 }
 
 */
