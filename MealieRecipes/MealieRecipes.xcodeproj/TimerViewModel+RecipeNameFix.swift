//
//  TimerViewModel+RecipeNameFix.swift
//  Alternative Lösung falls RecipeCache Probleme macht
//
//  VERWENDUNG:
//  Falls du Build-Fehler mit RecipeCacheManager bekommst,
//  ersetze die getRecipeName Methode in TimerViewModel.swift
//  mit einer dieser Alternativen:
//

import Foundation

// MARK: - Option 1: Einfachste Lösung - Fixer Name

/*
 In TimerViewModel.swift, ersetze getRecipeName mit:
 
 private func getRecipeName(for recipeId: UUID) -> String {
     return "Rezept-Timer"
 }
*/

// MARK: - Option 2: Rezeptname beim Timer-Start übergeben (Empfohlen!)

/*
 1. Ändere die start() Methode in TimerViewModel.swift:
 
 func start(durationMinutes: Double, recipeId: UUID, recipeName: String) {
     self.recipeId = recipeId
     self.lastRecipeId = recipeId
     self.recipeName = recipeName  // ← Neu
     let totalSeconds = durationMinutes * 60
     ...
     startLiveActivity(durationMinutes: durationMinutes, recipeId: recipeId, recipeName: recipeName)
 }
 
 2. Füge Property hinzu:
 
 @Published var recipeName: String?
 
 3. Ändere startLiveActivity:
 
 private func startLiveActivity(durationMinutes: Double, recipeId: UUID, recipeName: String) {
     ...
     let initialState = TimerAttributes.ContentState(
         endTime: endTime,
         recipeName: recipeName,  // ← Direkt verwenden
         remainingSeconds: Int(durationMinutes * 60),
         isRunning: true
     )
     ...
 }
 
 4. getRecipeName wird nicht mehr benötigt und kann gelöscht werden
 
 5. In RecipeDetailView (oder wo du Timer startest):
 
 timerViewModel.start(
     durationMinutes: 30,
     recipeId: recipe.id,
     recipeName: recipe.name  // ← Name übergeben
 )
*/

// MARK: - Option 3: UserDefaults als Cache (für Widget Extension)

/*
 Falls du den echten Rezeptnamen in der Live Activity möchtest
 ohne RecipeCache zum Widget hinzuzufügen:
 
 1. Erstelle einen einfachen UserDefaults Cache:
 
 extension UserDefaults {
     private static let recipeNameKey = "currentTimerRecipeName"
     
     var currentTimerRecipeName: String? {
         get { string(forKey: Self.recipeNameKey) }
         set { set(newValue, forKey: Self.recipeNameKey) }
     }
 }
 
 2. In TimerViewModel.start():
 
 func start(durationMinutes: Double, recipeId: UUID, recipeName: String) {
     // Rezeptname speichern
     UserDefaults.standard.currentTimerRecipeName = recipeName
     
     // Rest wie bisher
     ...
 }
 
 3. In getRecipeName():
 
 private func getRecipeName(for recipeId: UUID) -> String {
     return UserDefaults.standard.currentTimerRecipeName ?? "Rezept-Timer"
 }
*/

// MARK: - Empfohlene Lösung: Option 2

/*
 ✅ Vorteile:
 - Kein RecipeCache im Widget nötig
 - Echter Rezeptname wird angezeigt
 - Saubere Architektur (direkte Übergabe)
 - Keine zusätzlichen Dependencies
 
 ❌ Nachteil:
 - Muss TimerView/RecipeDetailView anpassen
 
 Implementierung in 3 Schritten:
 
 1. TimerViewModel:
    - Property hinzufügen: var recipeName: String?
    - start() Signatur ändern: + recipeName Parameter
    - startLiveActivity() Signatur ändern: + recipeName Parameter
    - getRecipeName() LÖSCHEN (nicht mehr nötig)
 
 2. TimerView:
    - init hinzufügen: let recipeName: String
    - start() Aufruf ändern: + recipeName übergeben
 
 3. RecipeDetailView (oder wo Timer gestartet wird):
    - TimerView Initialisierung: + recipeName: recipe.name
*/
