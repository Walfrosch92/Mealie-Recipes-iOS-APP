import Foundation
import UIKit

class LogManager {
    static let shared = LogManager()
    private init() {}
    
    private let logFileName = "mealie_log.txt"
    private var logEntries: [String] = []
    private let maxLogEntries = 500 // Nur die letzten 500 Zeilen speichern
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    /// Startet das Logging (wird beim App-Start aufgerufen)
    func startLogging() {
        // Alte Logs laden falls vorhanden
        loadLogsFromFile()
        
        // Ersten Log-Eintrag erstellen
        info("📱 Mealie Recipes Logging gestartet")
        info("📱 Gerät: \(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)")
    }
    
    /// Fügt einen Log-Eintrag hinzu (nur wenn Logging aktiviert ist)
    private func log(_ message: String, level: String = "INFO") {
        guard AppSettings.shared.enableLogging else { return }
        
        let timestamp = dateFormatter.string(from: Date())
        let logEntry = "[\(timestamp)] [\(level)] \(message)"
        
        // Zu Array hinzufügen
        logEntries.append(logEntry)
        
        // Nur die letzten 500 Einträge behalten
        if logEntries.count > maxLogEntries {
            logEntries.removeFirst(logEntries.count - maxLogEntries)
        }
        
        // Sofort in Datei speichern
        saveLogsToFile()
        
        // Auch auf Console ausgeben
        Swift.print(logEntry)
    }
    
    /// Speichert alle Logs in einer Datei (nur die letzten 500)
    private func saveLogsToFile() {
        guard AppSettings.shared.enableLogging else { return }
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logFileURL = documentsURL.appendingPathComponent(logFileName)
        
        // Nur die letzten 500 Einträge
        let logsToSave = Array(logEntries.suffix(maxLogEntries))
        let logContent = logsToSave.joined(separator: "\n")
        
        do {
            try logContent.write(to: logFileURL, atomically: true, encoding: .utf8)
        } catch {
            Swift.print("❌ Fehler beim Speichern der Logs: \(error)")
        }
    }
    
    /// Lädt Logs aus Datei
    private func loadLogsFromFile() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logFileURL = documentsURL.appendingPathComponent(logFileName)
        
        guard FileManager.default.fileExists(atPath: logFileURL.path) else {
            return
        }
        
        do {
            let logContent = try String(contentsOf: logFileURL, encoding: .utf8)
            let lines = logContent.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            // Nur die letzten 500 Zeilen behalten
            logEntries = Array(lines.suffix(maxLogEntries))
        } catch {
            // Kein Logging hier, um Endlosschleife zu vermeiden
        }
    }
    
    /// Öffentliche Logging-Funktionen
    func info(_ message: String) {
        log(message, level: "INFO")
    }
    
    func warning(_ message: String) {
        log(message, level: "WARNING")
    }
    
    func error(_ message: String) {
        log(message, level: "ERROR")
    }
    
    func debug(_ message: String) {
        log(message, level: "DEBUG")
    }
    
    /// Spezielle Funktion für print()-Aufrufe
    func logPrint(_ message: String) {
        guard AppSettings.shared.enableLogging else { return }
        
        let timestamp = dateFormatter.string(from: Date())
        let logEntry = "[\(timestamp)] [PRINT] \(message)"
        
        // Zu Array hinzufügen
        logEntries.append(logEntry)
        
        // Nur die letzten 500 Einträge behalten
        if logEntries.count > maxLogEntries {
            logEntries.removeFirst(logEntries.count - maxLogEntries)
        }
        
        // Sofort in Datei speichern
        saveLogsToFile()
    }
    
    /// Gibt alle gespeicherten Logs als String zurück (max. 500)
    func getLogs() -> String {
        return logEntries.joined(separator: "\n")
    }
    
    /// Gibt Log-Statistik zurück
    func getLogStats() -> (count: Int, sizeKB: Double) {
        let logString = getLogs()
        let sizeInBytes = logString.utf8.count
        let sizeInKB = Double(sizeInBytes) / 1024.0
        
        return (count: logEntries.count, sizeKB: sizeInKB)
    }
    
    /// Löscht alle Logs
    func clearLogs() {
        logEntries.removeAll()
        
        // Datei löschen
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logFileURL = documentsURL.appendingPathComponent(logFileName)
        
        do {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                try FileManager.default.removeItem(at: logFileURL)
            }
        } catch {
            // Kein Logging hier
        }
    }
    
    /// Exportiert Logs als Text für Sharing
    func exportLogs() -> String {
        var export = "=== Mealie Recipes Log ===\n"
        export += "Export-Zeit: \(Date())\n"
        export += "Einträge: \(logEntries.count) (letzte 500)\n"
        
        let stats = getLogStats()
        export += String(format: "Größe: %.1f KB\n", stats.sizeKB)
        export += "=======================\n\n"
        export += getLogs()
        return export
    }
}
