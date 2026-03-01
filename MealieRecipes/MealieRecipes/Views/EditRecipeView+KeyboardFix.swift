//
//  EditRecipeView+KeyboardFix.swift
//  MealieRecipes
//
//  Implementierungshinweise für EditRecipeView Keyboard-Fix
//

import SwiftUI

/*
 
 # Problem: RTIInputSystemClient Error beim Speichern
 
 ## Symptom:
 ```
 -[RTIInputSystemClient remoteTextInputSessionWithID:performInputOperation:]
 perform input operation requires a valid sessionID.
 inputModality = Keyboard
 ```
 
 ## Ursache:
 - Ein TextField/TextEditor hat noch den Focus
 - Der PATCH Request wird ausgelöst während Keyboard aktiv ist
 - Die View wird dismissed während Keyboard-Session noch läuft
 - Response wird möglicherweise nicht verarbeitet
 
 ## Lösung: 3-Schritte Fix in EditRecipeView
 
 ### 1. FocusState hinzufügen
 ```swift
 struct EditRecipeView: View {
     @FocusState private var focusedField: RecipeEditField?
     @State private var isSaving = false
     
     // ... existing code ...
 }
 ```
 
 ### 2. Focus auf alle TextFields setzen
 ```swift
 TextField("Recipe Name", text: $recipe.name)
     .focused($focusedField, equals: .name)
 
 TextField("Description", text: $recipe.description)
     .focused($focusedField, equals: .description)
 
 // Für Zutaten:
 ForEach($recipe.ingredients) { $ingredient in
     TextField("Ingredient", text: $ingredient.food)
         .focused($focusedField, equals: .ingredient(ingredient.id))
 }
 ```
 
 ### 3. Keyboard vor Save verstecken
 ```swift
 private func saveRecipe() {
     // ✅ KRITISCH: Focus entfernen (versteckt Keyboard)
     focusedField = nil
     
     Task {
         // ⏱️ Warte bis Keyboard-Animation fertig ist
         try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 Sekunden
         
         isSaving = true
         defer { isSaving = false }
         
         do {
             let payload = RecipeUpdatePayload(from: recipe)
             try await APIService.shared.updateFullRecipe(
                 originalSlug: originalSlug,
                 payload: payload
             )
             
             // ✅ Erfolgreich gespeichert
             onSave(recipe)
         } catch {
             // ❌ Fehlerbehandlung
             errorMessage = error.localizedDescription
             showError = true
         }
     }
 }
 ```
 
 ### 4. Save Button
 ```swift
 .toolbar {
     ToolbarItem(placement: .confirmationAction) {
         Button("Save") {
             saveRecipe()
         }
         .disabled(isSaving || !hasChanges)
     }
     
     ToolbarItem(placement: .cancellationAction) {
         Button("Cancel") {
             focusedField = nil  // ✅ Keyboard verstecken vor Dismiss
             dismiss()
         }
     }
 }
 ```
 
 ## Alternative: Keyboard automatisch bei Toolbar-Button verstecken
 
 ```swift
 .toolbar {
     ToolbarItem(placement: .keyboard) {
         Button("Done") {
             focusedField = nil
         }
     }
 }
 ```
 
 ## Best Practice: Dirty State Tracking
 
 ```swift
 @State private var originalRecipe: RecipeDetail
 
 private var hasChanges: Bool {
     recipe.name != originalRecipe.name ||
     recipe.description != originalRecipe.description ||
     recipe.ingredients != originalRecipe.ingredients
     // ... weitere Felder
 }
 
 private var canSave: Bool {
     !isSaving && hasChanges && !recipe.name.isEmpty
 }
 ```
 
 ## Testing
 
 Nach dem Fix sollten diese Probleme behoben sein:
 - ✅ Keine RTIInputSystemClient Warnung mehr
 - ✅ PATCH Request wird vollständig ausgeführt
 - ✅ Response wird korrekt verarbeitet
 - ✅ Keine Race Conditions zwischen View Dismiss und Network Request
 - ✅ Smooth User Experience
 
 ## Hinweis
 
 RecipeEditField Enum ist bereits in `KeyboardDismissHelper.swift` definiert.
 Importiere diese Datei einfach und verwende das Enum direkt.
 
 */
