//
//  TimerAttributes.swift
//  MealieRecipes
//
//  Timer Live Activity Definition
//

import ActivityKit
import Foundation

/// Attribute und ContentState für Timer Live Activities
/// Wird auf iPhone (Dynamic Island + Lock Screen) und Apple Watch angezeigt
struct TimerAttributes: ActivityAttributes {
    
    /// Dynamischer Zustand des Timers (ändert sich während der Laufzeit)
    public struct ContentState: Codable, Hashable {
        /// Zeitpunkt, wann der Timer endet
        var endTime: Date
        
        /// Name des Rezepts
        var recipeName: String
        
        /// Verbleibende Sekunden (für Backup, falls endTime nicht funktioniert)
        var remainingSeconds: Int
        
        /// Ob der Timer noch läuft oder bereits abgelaufen ist
        var isRunning: Bool
    }
    
    // Statische Attribute (ändern sich nicht während der Laufzeit)
    
    /// UUID des Rezepts
    var recipeId: String
    
    /// Ursprüngliche Dauer in Minuten
    var originalDurationMinutes: Int
}
