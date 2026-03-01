//
//  LiveActivityQuickCheck.swift
//  Schneller Live Activity Check - kann überall eingefügt werden
//

import SwiftUI
import ActivityKit

struct LiveActivityQuickCheck: View {
    @EnvironmentObject var timerViewModel: TimerViewModel
    @State private var showAlert = false
    @State private var statusText = ""
    
    var body: some View {
        VStack(spacing: 16) {
            Text("🔍 Live Activity Status")
                .font(.headline)
            
            Button("Status prüfen") {
                checkStatus()
                showAlert = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .alert("Live Activity Status", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(statusText)
        }
    }
    
    private func checkStatus() {
        var status: [String] = []
        
        // 1. Live Activities erlaubt?
        let authInfo = ActivityAuthorizationInfo()
        status.append("✓ Live Activities: \(authInfo.areActivitiesEnabled ? "✅ AKTIV" : "❌ DEAKTIVIERT")")
        
        // 2. Info.plist konfiguriert?
        let supportsLiveActivities = Bundle.main.object(forInfoDictionaryKey: "NSSupportsLiveActivities") as? Bool ?? false
        status.append("✓ Info.plist Config: \(supportsLiveActivities ? "✅ OK" : "❌ FEHLT")")
        
        // 3. iOS Version
        let version = UIDevice.current.systemVersion
        status.append("✓ iOS Version: \(version)")
        
        // 4. Gerät
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        status.append("✓ Gerät: \(device)")
        
        // 5. Aktive Live Activities
        let activeCount = Activity<TimerAttributes>.activities.count
        status.append("✓ Aktive Timer: \(activeCount)")
        
        // 6. Timer läuft?
        status.append("✓ Timer aktiv: \(timerViewModel.timerActive ? "Ja" : "Nein")")
        
        // Zusammenfassung
        status.append("\n" + String(repeating: "-", count: 30))
        
        if !authInfo.areActivitiesEnabled {
            status.append("\n⚠️ PROBLEM:")
            if !supportsLiveActivities {
                status.append("Info.plist fehlt!")
                status.append("Füge hinzu:")
                status.append("NSSupportsLiveActivities = true")
            } else {
                status.append("iOS-Einstellungen:")
                status.append("Einstellungen → Mealie Recipes")
                status.append("→ Live Activities EIN")
            }
        } else {
            status.append("\n✅ Alles konfiguriert!")
            status.append("Timer starten & Gerät sperren")
        }
        
        statusText = status.joined(separator: "\n")
        print("\n" + statusText)
    }
}

// MARK: - Einfache Integration

/*
 Füge diese View TEMPORÄR irgendwo in deiner App hinzu:
 
 1. In WelcomeView (ganz unten vor dem letzten }):
 
    // Temporär zum Debuggen
    LiveActivityQuickCheck()
        .environmentObject(timerModel)
 
 2. Oder in Settings als Button:
 
    Button("🔍 Live Activity Status") {
        // Code hier
    }
 
 3. Oder als eigener Menüpunkt in WelcomeView mit den anderen Cards
*/

#Preview {
    LiveActivityQuickCheck()
        .environmentObject(TimerViewModel())
}
