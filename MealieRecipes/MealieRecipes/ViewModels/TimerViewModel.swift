import UIKit
import UIKit
import Foundation
import AVFoundation
import UserNotifications
import AudioToolbox
import ActivityKit

// 🔧 Lokale Logging-Hilfe (falls globale nicht gefunden wird)
private func logMessage(_ message: String) {
    Swift.print(message)
    
    if AppSettings.shared.enableLogging {
        LogManager.shared.logPrint(message)
    }
}

private func logMessage(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let output = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(output, terminator: terminator)
    
    if AppSettings.shared.enableLogging {
        LogManager.shared.logPrint(output)
    }
}

@MainActor
class TimerViewModel: ObservableObject {
    @Published var timeRemaining: TimeInterval = 0
    @Published var timerActive = false
    @Published var recipeId: UUID?
    @Published var showBannerAfterFinish = false
    @Published var lastRecipeId: UUID?

    var onAutoNavigateToRecipe: ((UUID) -> Void)?

    private var endTime: Date?
    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?
    private var hasAutoNavigated = false
    
    // 🎵 Background Audio für Timer-Alarm
    private var backgroundAudioPlayer: AVAudioPlayer?
    private var silentAudioPlayer: AVAudioPlayer? // Spielt stille Audio im Hintergrund
    
    // MARK: - Live Activity
    private var currentActivity: Activity<TimerAttributes>?
    
    // MARK: - Debug
    @Published var liveActivityStatus: String = "Nicht gestartet"
    
    deinit {
        timer?.invalidate()
        // ✅ Audio-Cleanup: Capture values instead of self to avoid Swift 6 error
        let silentPlayer = silentAudioPlayer
        let backgroundPlayer = backgroundAudioPlayer
        let regularPlayer = audioPlayer
        
        Task { @MainActor in
            silentPlayer?.stop()
            backgroundPlayer?.stop()
            regularPlayer?.stop()
        }
    }

    // MARK: - Public API

    /// Call **beim App-Start** im AppDelegate/SceneDelegate, z.B.:
    /// `TimerViewModel.requestNotificationPermission()`
    static func requestNotificationPermission() {
        // 🔔 WICHTIG: Alle relevanten Optionen anfordern
        // Note: .timeSensitive requires the Time Sensitive Notifications entitlement
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                logMessage("❌ Notification-Berechtigung Fehler: \(error)")
            } else if granted {
                logMessage("✅ Notification-Berechtigung erteilt")
                
                // Notification-Kategorien registrieren (für interaktive Benachrichtigungen)
                let timerCategory = UNNotificationCategory(
                    identifier: "TIMER_CATEGORY",
                    actions: [],
                    intentIdentifiers: [],
                    options: [.customDismissAction]
                )
                UNUserNotificationCenter.current().setNotificationCategories([timerCategory])
            } else {
                logMessage("⚠️ Notification-Berechtigung verweigert")
            }
        }
    }

    func start(durationMinutes: Double, recipeId: UUID) {
        self.recipeId = recipeId
        self.lastRecipeId = recipeId
        let totalSeconds = durationMinutes * 60
        endTime = Date().addingTimeInterval(totalSeconds)
        timeRemaining = totalSeconds
        timerActive = true
        showBannerAfterFinish = false
        hasAutoNavigated = false

        // Remove any old timer notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timer_end"])

        // 🎵 Audio Session für Background-Audio konfigurieren
        configureAudioSessionForTimer()
        
        // 🔇 Stille Audio im Hintergrund spielen (hält die App "aktiv" für Audio)
        startSilentBackgroundAudio()

        // Für UI im Vordergrund
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateRemainingTime()
            }
        }

        // Im Hintergrund Notification einplanen (als Backup)
        triggerNotification(after: totalSeconds)
        
        // 🆕 Live Activity starten
        startLiveActivity(durationMinutes: durationMinutes, recipeId: recipeId)
        
        logMessage("✅ Timer gestartet: \(durationMinutes) Minuten (mit Background-Audio)")
    }

    func stop() {
        timer?.invalidate()
        endTime = nil
        timerActive = false
        timeRemaining = 0
        // Timer-Notification entfernen!
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timer_end"])
        
        // 🎵 Background-Audio stoppen
        stopSilentBackgroundAudio()
        stopAlarmSound()
        
        // 🆕 Live Activity beenden
        endLiveActivity()
        
        logMessage("⏹️ Timer gestoppt")
    }

    func clearAfterFinish() {
        recipeId = nil
        lastRecipeId = nil
        showBannerAfterFinish = false
    }

    // MARK: - Private Helpers

    private func updateRemainingTime() {
        guard let endTime else { return }
        let remaining = endTime.timeIntervalSinceNow
        timeRemaining = max(0, remaining)

        if timeRemaining <= 1, !hasAutoNavigated, let recipeId = self.recipeId ?? self.lastRecipeId {
            hasAutoNavigated = true
            // Create a local copy to avoid potential deallocation issues
            if let callback = onAutoNavigateToRecipe {
                callback(recipeId)
            }
        }

        if timeRemaining > 0 {
            // 🆕 Live Activity aktualisieren
            updateLiveActivity(remainingSeconds: Int(timeRemaining))
            return
        }
        // Timer ist abgelaufen:
        timer?.invalidate()
        self.endTime = nil
        self.timerActive = false
        self.timeRemaining = 0
        self.showBannerAfterFinish = true

        // 🎵 Stille Audio stoppen und Alarm-Sound spielen
        stopSilentBackgroundAudio()
        playAlarmSound()
        
        // 🆕 Live Activity als "fertig" markieren und dann beenden
        endLiveActivity()
        
        logMessage("⏰ Timer abgelaufen!")
    }

    // MARK: - Background Audio Management
    
    /// Konfiguriert die Audio Session für Background-Audio
    /// Wichtig: Die App muss "audio" Background Mode in Info.plist haben!
    private func configureAudioSessionForTimer() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // 🎵 Playback-Kategorie mit mixWithOthers Option
            // - .playback: Erlaubt Audio im Hintergrund
            // - .mixWithOthers: Audio wird mit anderen Apps gemischt (z.B. Musik)
            // - .duckOthers: Andere Audio wird leiser wenn unser Alarm spielt
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            
            logMessage("✅ Audio Session konfiguriert (Background-fähig)")
        } catch {
            logMessage("❌ Audio Session Fehler: \(error)")
        }
    }
    
    /// Spielt eine stille Audio-Datei im Loop, um die App im Background "aktiv" zu halten
    /// Dies ermöglicht es dem Timer, auch im Hintergrund weiterzulaufen
    private func startSilentBackgroundAudio() {
        // Erstelle eine sehr kurze stille Audio-Datei programmatisch
        // Alternativ: Fügen Sie eine "silent.wav" Datei (1 Sekunde Stille) zum Bundle hinzu
        
        // Versuche erst eine stille Audio-Datei aus dem Bundle zu laden
        if let silentURL = Bundle.main.url(forResource: "silent", withExtension: "wav") {
            do {
                silentAudioPlayer = try AVAudioPlayer(contentsOf: silentURL)
                silentAudioPlayer?.numberOfLoops = -1 // Endlos wiederholen
                silentAudioPlayer?.volume = 0.0 // Stumm
                silentAudioPlayer?.prepareToPlay()
                silentAudioPlayer?.play()
                logMessage("🔇 Stille Background-Audio gestartet (aus Bundle)")
                return
            } catch {
                logMessage("⚠️ Fehler beim Laden von silent.wav: \(error)")
            }
        }
        
        // Fallback: Erstelle programmatisch eine stille Audio-Datei
        createAndPlaySilentAudio()
    }
    
    /// Erstellt programmatisch eine stille Audio-Datei und spielt sie ab
    private func createAndPlaySilentAudio() {
        // Audio-Format: PCM, 1 Kanal, 44100 Hz
        let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 1,
            interleaved: false
        )
        
        guard let format = audioFormat else {
            logMessage("❌ Konnte Audio-Format nicht erstellen")
            return
        }
        
        // 1 Sekunde stille Audio
        let frameCount = AVAudioFrameCount(44100)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            logMessage("❌ Konnte Audio-Buffer nicht erstellen")
            return
        }
        
        buffer.frameLength = frameCount
        
        // Schreibe Buffer in temporäre Datei
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("silent_timer.caf")
        
        do {
            let audioFile = try AVAudioFile(
                forWriting: tempURL,
                settings: format.settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
            try audioFile.write(from: buffer)
            
            // Spiele die stille Audio ab
            silentAudioPlayer = try AVAudioPlayer(contentsOf: tempURL)
            silentAudioPlayer?.numberOfLoops = -1 // Endlos wiederholen
            silentAudioPlayer?.volume = 0.0 // Stumm
            silentAudioPlayer?.prepareToPlay()
            silentAudioPlayer?.play()
            
            logMessage("🔇 Stille Background-Audio gestartet (programmatisch erstellt)")
        } catch {
            logMessage("❌ Fehler beim Erstellen stiller Audio: \(error)")
        }
    }
    
    /// Stoppt die stille Background-Audio
    private func stopSilentBackgroundAudio() {
        silentAudioPlayer?.stop()
        silentAudioPlayer = nil
        logMessage("🔇 Stille Background-Audio gestoppt")
    }
    
    /// Spielt den Alarm-Sound ab (funktioniert auch im Hintergrund!)
    private func playAlarmSound() {
        // Stoppe zuerst die stille Audio
        stopSilentBackgroundAudio()
        
        // Konfiguriere Audio Session für Alarm (mit duckOthers, um andere Apps leiser zu machen)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            logMessage("❌ Audio Session Fehler beim Alarm: \(error)")
        }
        
        // Spiele Alarm-Sound
        if let soundURL = Bundle.main.url(forResource: "alarm", withExtension: "wav") {
            do {
                backgroundAudioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                backgroundAudioPlayer?.numberOfLoops = 3 // 3x wiederholen
                backgroundAudioPlayer?.volume = 1.0 // Volle Lautstärke
                backgroundAudioPlayer?.prepareToPlay()
                backgroundAudioPlayer?.play()
                
                logMessage("🔊 Alarm-Sound gestartet (Background-fähig)")
                
                // Nach 30 Sekunden automatisch stoppen (falls der User nicht reagiert)
                DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                    self?.stopAlarmSound()
                }
            } catch {
                logMessage("❌ Alarm-Sound Fehler: \(error)")
                // Fallback: System-Sound
                AudioServicesPlaySystemSound(1005)
            }
        } else {
            logMessage("⚠️ alarm.wav nicht gefunden - spiele System-Sound")
            // Wiederhole System-Sound mehrfach
            for i in 0..<5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 1.5) {
                    AudioServicesPlaySystemSound(1005)
                }
            }
        }
    }
    
    /// Stoppt den Alarm-Sound
    private func stopAlarmSound() {
        backgroundAudioPlayer?.stop()
        backgroundAudioPlayer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        logMessage("🔇 Alarm-Sound gestoppt")
    }
    
    // MARK: - Legacy Sound Method (für Kompatibilität)
    
    private func playSound() {
        if let soundURL = Bundle.main.url(forResource: "alarm", withExtension: "wav") {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.play()
                logMessage("🔊 Sound gespielt")
            } catch {
                logMessage("❌ Soundfehler: \(error)")
                AudioServicesPlaySystemSound(1005)
            }
        } else {
            logMessage("⚠️ alarm.wav nicht gefunden")
            AudioServicesPlaySystemSound(1005)
        }
    }

    /// Schickt eine lokale Notification (kommt auch im Hintergrund)
    private func triggerNotification(after seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Timer abgelaufen!"
        content.body = "Dein Timer ist fertig."
        
        // ⚠️ WICHTIG: Sound-Datei muss im Bundle sein und max. 30 Sekunden lang
        // Fallback auf System-Sound falls Custom-Sound nicht funktioniert
        if Bundle.main.url(forResource: "alarm", withExtension: "wav") != nil {
            content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm.wav"))
            logMessage("🔔 Notification mit Custom-Sound 'alarm.wav' geplant")
        } else {
            // Kritischer Alert-Sound (funktioniert immer, auch im Silent-Mode!)
            content.sound = .defaultCritical
            logMessage("⚠️ alarm.wav nicht gefunden - verwende kritischen System-Sound")
        }
        
        content.badge = 0
        // Kategorie für interaktive Benachrichtigungen (optional)
        content.categoryIdentifier = "TIMER_CATEGORY"
        
        // ⚠️ WICHTIG: interruptionLevel auf .timeSensitive oder .critical setzen
        // damit die Notification auch bei aktiviertem "Nicht stören" angezeigt wird
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: "timer_end", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                logMessage("❌ Notification konnte nicht hinzugefügt werden: \(error)")
            } else {
                logMessage("✅ Timer-Notification erfolgreich geplant für \(seconds) Sekunden")
            }
        }
    }
    
    // MARK: - Live Activity Management
    
    /// Startet eine Live Activity für den Timer
    /// Wird automatisch auf iPhone (Dynamic Island + Lock Screen) und Apple Watch angezeigt
    private func startLiveActivity(durationMinutes: Double, recipeId: UUID) {
        // Beende vorherige Activity falls vorhanden
        if currentActivity != nil {
            endLiveActivity()
        }
        
        // 🔍 DEBUG: Live Activities verfügbar?
        let authInfo = ActivityAuthorizationInfo()
        logMessage("🔍 DEBUG: Live Activities erlaubt: \(authInfo.areActivitiesEnabled)")
        liveActivityStatus = "Status: \(authInfo.areActivitiesEnabled ? "Erlaubt" : "Blockiert")"
        
        guard authInfo.areActivitiesEnabled else {
            logMessage("⚠️ Live Activities sind deaktiviert")
            logMessage("💡 Aktiviere sie unter: Einstellungen → Mealie Recipes → Live Activities")
            liveActivityStatus = "❌ Deaktiviert in Einstellungen"
            return
        }
        
        guard let endTime = endTime else { 
            logMessage("❌ Keine endTime gesetzt")
            liveActivityStatus = "❌ Keine endTime"
            return
        }
        
        // Rezeptname laden (oder Fallback verwenden)
        let recipeName = getRecipeName(for: recipeId)
        logMessage("🔍 DEBUG: Rezeptname: \(recipeName)")
        
        let initialState = TimerAttributes.ContentState(
            endTime: endTime,
            recipeName: recipeName,
            remainingSeconds: Int(durationMinutes * 60),
            isRunning: true
        )
        
        let attributes = TimerAttributes(
            recipeId: recipeId.uuidString,
            originalDurationMinutes: Int(durationMinutes)
        )
        
        logMessage("🔍 DEBUG: Versuche Live Activity zu starten...")
        logMessage("🔍 DEBUG: EndTime: \(endTime)")
        logMessage("🔍 DEBUG: Duration: \(durationMinutes) Minuten")
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            logMessage("✅ Live Activity gestartet: \(activity.id)")
            liveActivityStatus = "✅ Aktiv: \(activity.id)"
        } catch {
            logMessage("❌ Live Activity konnte nicht gestartet werden: \(error)")
            logMessage("❌ Error Type: \(type(of: error))")
            logMessage("❌ Error Description: \(error.localizedDescription)")
            liveActivityStatus = "❌ Fehler: \(error.localizedDescription)"
        }
    }
    
    /// Aktualisiert die laufende Live Activity
    private func updateLiveActivity(remainingSeconds: Int) {
        guard let activity = currentActivity else { return }
        guard let endTime = endTime else { return }
        
        Task {
            let updatedState = TimerAttributes.ContentState(
                endTime: endTime,
                recipeName: activity.content.state.recipeName,
                remainingSeconds: remainingSeconds,
                isRunning: true
            )
            
            await activity.update(.init(state: updatedState, staleDate: nil))
        }
    }
    
    /// Beendet die Live Activity
    private func endLiveActivity() {
        guard let activity = currentActivity else { return }
        
        Task {
            // Finale Update: Timer abgelaufen
            let finalState = TimerAttributes.ContentState(
                endTime: Date(),
                recipeName: activity.content.state.recipeName,
                remainingSeconds: 0,
                isRunning: false
            )
            
            await activity.update(.init(state: finalState, staleDate: nil))
            
            // Activity nach 4 Sekunden entfernen (Zeit um "Fertig" anzuzeigen)
            try? await Task.sleep(for: .seconds(4))
            await activity.end(nil, dismissalPolicy: .immediate)
            
            logMessage("✅ Live Activity beendet")
        }
        
        currentActivity = nil
    }
    
    /// Holt den Rezeptnamen aus dem Cache oder verwendet Fallback
    private func getRecipeName(for recipeId: UUID) -> String {
        // Versuche Rezept aus Cache zu laden
        if let recipe = RecipeCacheManager.shared.getRecipe(byId: recipeId) {
            return recipe.name
        }
        
        // Fallback
        return "Rezept Timer"
    }
}
