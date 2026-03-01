//
//  TimerLiveActivityExample.swift
//  Beispiel zur Verwendung der Timer Live Activity
//
//  NICHT in die App einbinden - nur zur Demonstration!
//

import SwiftUI
import ActivityKit

// MARK: - Beispiel 1: Timer in RecipeDetailView starten

/*
 In deiner RecipeDetailView (oder wo auch immer du Timer startest):
 
 @EnvironmentObject var timerViewModel: TimerViewModel
 
 Button("Timer starten") {
     timerViewModel.start(
         durationMinutes: 30,
         recipeId: recipe.id
     )
     
     // Live Activity wird automatisch gestartet!
     // Erscheint auf:
     // - iPhone Dynamic Island
     // - iPhone Lock Screen
     // - Apple Watch Smart Stack
 }
*/

// MARK: - Beispiel 2: Manuelle Prüfung ob Live Activities aktiviert sind

func checkLiveActivityStatus() {
    let info = ActivityAuthorizationInfo()
    
    switch info.areActivitiesEnabled {
    case true:
        print("✅ Live Activities sind aktiviert")
    case false:
        print("❌ Live Activities sind deaktiviert")
        print("💡 Nutzer kann sie aktivieren unter: Einstellungen → MealieRecipes → Live Activities")
    }
}

// MARK: - Beispiel 3: Alle aktiven Live Activities abrufen

func listActiveTimers() {
    let activities = Activity<TimerAttributes>.activities
    
    print("🔴 Aktive Timer: \(activities.count)")
    
    for activity in activities {
        print("Timer für Rezept: \(activity.content.state.recipeName)")
        print("Endet um: \(activity.content.state.endTime)")
        print("Verbleibend: \(activity.content.state.remainingSeconds)s")
    }
}

// MARK: - Beispiel 4: Live Activity manuell beenden (außerhalb TimerViewModel)

func endSpecificTimer(recipeId: String) async {
    let activities = Activity<TimerAttributes>.activities
    
    for activity in activities where activity.attributes.recipeId == recipeId {
        await activity.end(nil, dismissalPolicy: .immediate)
        print("✅ Timer für Rezept \(recipeId) beendet")
    }
}

// MARK: - Beispiel 5: Push Notifications für Live Activities (Optional - Erweitert)

/*
 Für noch längere Timer kannst du Push Notifications verwenden,
 um Live Activities aus der Ferne zu aktualisieren.
 
 Erfordert:
 1. APNs (Apple Push Notification service) Setup
 2. Server-seitige Integration
 3. Push-Token für Activity
 
 Beispiel:
 
 let activity = try Activity.request(
     attributes: attributes,
     content: .init(state: initialState, staleDate: nil),
     pushType: .token  // ← Push Token anfordern
 )
 
 // Token an Server senden
 for await data in activity.pushTokenUpdates {
     let token = data.map { String(format: "%02x", $0) }.joined()
     print("Push Token: \(token)")
     // Sende an deinen Server
 }
*/

// MARK: - Beispiel 6: Custom Timer-Alerts

/*
 Du kannst auch Custom Alerts anzeigen wenn Timer in Live Activity läuft:
 
 if timerViewModel.timerActive {
     // Zeige Banner in App
     Banner(
         title: "Timer läuft",
         subtitle: "Schau auf deine Apple Watch!",
         icon: "applewatch"
     )
 }
*/

// MARK: - Beispiel 7: Timer aus Live Activity in App öffnen

/*
 Wenn Nutzer auf die Live Activity tippt, kannst du direkt zum Rezept navigieren:
 
 In deiner App's @main:
 
 .onOpenURL { url in
     // Deep Link handling
     if url.scheme == "mealierecipes",
        url.host == "timer",
        let recipeId = UUID(uuidString: url.pathComponents[1]) {
         // Navigiere zu Rezept
         navigationPath.append(recipeId)
     }
 }
 
 Dann in TimerLiveActivity.swift Button hinzufügen:
 
 Link(destination: URL(string: "mealierecipes://timer/\(context.attributes.recipeId)")!) {
     Text("Rezept öffnen")
 }
*/

// MARK: - Debugging Tipps

/*
 Console Commands beim Testen:
 
 # Live Activities im Simulator debuggen
 xcrun simctl push <device> <bundle-id>.widget.extension live-activity.json
 
 # Live Activity Status prüfen
 print(Activity<TimerAttributes>.activities)
 
 # Activity Content ausgeben
 for activity in Activity<TimerAttributes>.activities {
     print(activity.content.state)
 }
*/
