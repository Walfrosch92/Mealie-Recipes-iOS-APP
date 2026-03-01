//
//  TimerDebugView.swift
//  Debug-Ansicht für Live Activity Probleme
//
//  ⚠️ NUR ZUM DEBUGGEN - Kann später entfernt werden
//

import SwiftUI
import ActivityKit

struct TimerDebugView: View {
    @EnvironmentObject var timerViewModel: TimerViewModel
    @State private var testDuration: Double = 5
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("🔍 Live Activity Debug")
                    .font(.title)
                    .bold()
                
                // Status
                GroupBox("Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        StatusRow(title: "Timer aktiv", value: "\(timerViewModel.timerActive)")
                        StatusRow(title: "Live Activity Status", value: timerViewModel.liveActivityStatus)
                        StatusRow(title: "iOS Version", value: UIDevice.current.systemVersion)
                        StatusRow(title: "Device", value: UIDevice.current.name)
                        
                        Divider()
                        
                        let authInfo = ActivityAuthorizationInfo()
                        StatusRow(
                            title: "Live Activities erlaubt",
                            value: "\(authInfo.areActivitiesEnabled)",
                            color: authInfo.areActivitiesEnabled ? .green : .red
                        )
                        
                        if !authInfo.areActivitiesEnabled {
                            Text("💡 Aktiviere Live Activities:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Einstellungen → Mealie Recipes → Live Activities")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                
                // Aktive Activities
                GroupBox("Aktive Live Activities") {
                    let activities = Activity<TimerAttributes>.activities
                    
                    if activities.isEmpty {
                        Text("Keine aktiven Live Activities")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(activities, id: \.id) { activity in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ID: \(activity.id)")
                                    .font(.caption)
                                    .monospaced()
                                Text("Rezept: \(activity.content.state.recipeName)")
                                Text("Läuft: \(activity.content.state.isRunning ? "Ja" : "Nein")")
                                Text("Verbleibend: \(activity.content.state.remainingSeconds)s")
                            }
                            .padding(.vertical, 4)
                            
                            if activity != activities.last {
                                Divider()
                            }
                        }
                    }
                }
                
                // Test Timer
                GroupBox("Test Timer") {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Dauer: \(Int(testDuration)) Minuten")
                            Spacer()
                        }
                        
                        Slider(value: $testDuration, in: 1...10, step: 1)
                        
                        Button(action: startTestTimer) {
                            Label("Test Timer starten", systemImage: "timer")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(timerViewModel.timerActive)
                        
                        if timerViewModel.timerActive {
                            Button(action: {
                                timerViewModel.stop()
                            }) {
                                Label("Timer stoppen", systemImage: "stop.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                }
                
                // Info.plist Check
                GroupBox("Konfiguration") {
                    VStack(alignment: .leading, spacing: 8) {
                        let supportsLiveActivities = Bundle.main.object(forInfoDictionaryKey: "NSSupportsLiveActivities") as? Bool ?? false
                        let supportsFrequentUpdates = Bundle.main.object(forInfoDictionaryKey: "NSSupportsLiveActivitiesFrequentUpdates") as? Bool ?? false
                        
                        StatusRow(
                            title: "NSSupportsLiveActivities",
                            value: "\(supportsLiveActivities)",
                            color: supportsLiveActivities ? .green : .red
                        )
                        
                        StatusRow(
                            title: "NSSupportsLiveActivitiesFrequentUpdates",
                            value: "\(supportsFrequentUpdates)",
                            color: supportsFrequentUpdates ? .green : .red
                        )
                        
                        if !supportsLiveActivities {
                            Text("⚠️ Füge zu Info.plist hinzu:")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("<key>NSSupportsLiveActivities</key>\n<true/>")
                                .font(.caption)
                                .monospaced()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Logs
                GroupBox("Console Output") {
                    Text("Schau in die Xcode Console für detaillierte Logs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Filter: 'Live Activity' oder '🔍'")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            .padding()
        }
        .navigationTitle("Timer Debug")
    }
    
    private func startTestTimer() {
        let testRecipeId = UUID()
        timerViewModel.start(
            durationMinutes: testDuration,
            recipeId: testRecipeId
        )
    }
}

struct StatusRow: View {
    let title: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .bold()
                .foregroundStyle(color)
        }
    }
}

#Preview {
    NavigationStack {
        TimerDebugView()
            .environmentObject(TimerViewModel())
    }
}
