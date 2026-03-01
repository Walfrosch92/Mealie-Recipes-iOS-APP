//
//  RemindersImporter.swift
//  MealieRecipes
//
//  Created by Michael Haiszan on 17.08.25.
//

import Foundation
import EventKit

// MARK: - Model

struct ImportedReminder: Hashable, Identifiable {
    let id: String              // calendarItemIdentifier
    let rawTitle: String
    let name: String            // bereinigt
    let categoryCandidate: String?
    let quantity: Double?
    let unit: String?
    enum SourceKind { case groceryApple, normal, heuristic, hashtag, atLabel }
    let source: SourceKind
}

// MARK: - Importer

final class RemindersImporter {
    private let eventStore = EKEventStore()

    // MARK: Permission

    /// Prüft, ob bereits ausreichender Zugriff vorliegt.
    func hasAccess() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        print("🔍 Reminders Authorization Status: \(status.rawValue)")
        if #available(iOS 17.0, *) {
            // iOS 17+: .fullAccess oder .writeOnly sind ausreichend
            let hasAccess = status == .fullAccess || status == .writeOnly
            print("🔍 iOS 17+ - Has Access: \(hasAccess) (fullAccess=3, writeOnly=2, current=\(status.rawValue))")
            return hasAccess
        } else {
            let hasAccess = status == .authorized
            print("🔍 iOS <17 - Has Access: \(hasAccess) (authorized=3, current=\(status.rawValue))")
            return hasAccess
        }
    }

    /// Fordert Zugriff auf Erinnerungen an (iOS-17-clean).
    func requestAccess() async throws {
        print("🔍 requestAccess() called - hasAccess: \(hasAccess())")
        
        if hasAccess() { 
            print("✅ Already has access, returning early")
            return 
        }

        // Prüfe, ob NSRemindersUsageDescription in Info.plist vorhanden ist
        let hasUsageDescription = Bundle.main.object(forInfoDictionaryKey: "NSRemindersUsageDescription") != nil
        print("🔍 NSRemindersUsageDescription in Info.plist: \(hasUsageDescription)")
        
        if !hasUsageDescription {
            print("❌ NSRemindersUsageDescription missing!")
            throw NSError(
                domain: "RemindersImporter",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "NSRemindersUsageDescription fehlt in Info.plist. Bitte fügen Sie diese Berechtigung in den Projekt-Einstellungen hinzu (Info Tab → Custom iOS Target Properties → Privacy - Reminders Usage Description)."]
            )
        }

        print("🔍 Requesting access to reminders...")
        
        if #available(iOS 17.0, *) {
            // Neue API: wirft bei Ablehnung/Fehler
            do {
                print("🔍 Using iOS 17+ API: requestFullAccessToReminders()")
                try await eventStore.requestFullAccessToReminders()
                print("✅ Access granted via iOS 17+ API")
            } catch {
                print("❌ iOS 17+ API error: \(error.localizedDescription)")
                // Gebe einen klareren Fehler zurück
                throw NSError(
                    domain: "RemindersImporter",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: LocalizedStringProvider.localized("reminders_access_denied") + "\n\nDetails: \(error.localizedDescription)"]
                )
            }
        } else {
            // Ältere API: completion-basiert (bridgen)
            print("🔍 Using pre-iOS 17 API: requestAccess(to:)")
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                eventStore.requestAccess(to: .reminder) { granted, error in
                    print("🔍 requestAccess callback - granted: \(granted), error: \(String(describing: error))")
                    if let error {
                        print("❌ Pre-iOS 17 API error: \(error.localizedDescription)")
                        cont.resume(throwing: error)
                    } else if !granted {
                        print("❌ Pre-iOS 17 API - access not granted")
                        cont.resume(throwing: NSError(
                            domain: "RemindersImporter",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: LocalizedStringProvider.localized("reminders_access_denied")]
                        ))
                    } else {
                        print("✅ Access granted via pre-iOS 17 API")
                        cont.resume()
                    }
                }
            }
        }
        
        print("🔍 After request - hasAccess: \(hasAccess())")
    }

    // MARK: Kalender

    func listReminderCalendars() -> [EKCalendar] {
        eventStore.calendars(for: .reminder)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func calendar(with id: String) -> EKCalendar? {
        eventStore.calendar(withIdentifier: id)
    }

    // MARK: Fetch

    func fetchReminders(in calendarId: String) async throws -> [EKReminder] {
        guard let cal = calendar(with: calendarId) else {
            throw NSError(
                domain: "RemindersImporter",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: LocalizedStringProvider.localized("reminders_calendar_not_found")]
            )
        }
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: [cal]
        )
        return await withCheckedContinuation { cont in
            eventStore.fetchReminders(matching: predicate) { reminders in
                cont.resume(returning: reminders ?? [])
            }
        }
    }

    // MARK: Transform

    func toImported(_ reminder: EKReminder, isGrocery: Bool) -> ImportedReminder? {
        let rawTitle = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawTitle.isEmpty else { return nil }

        let notes = reminder.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = IngredientParser.parse(rawTitle: rawTitle, notes: notes, isGrocery: isGrocery)

        guard !p.name.isEmpty else { return nil }
        return ImportedReminder(
            id: reminder.calendarItemIdentifier,
            rawTitle: rawTitle,
            name: p.name,
            categoryCandidate: p.categoryCandidate,
            quantity: p.quantity,
            unit: p.unit,
            source: p.source
        )
    }
}

// MARK: - Post-Processing (Complete/Delete)

extension RemindersImporter {

    private func loadReminder(by id: String) -> EKReminder? {
        eventStore.calendarItem(withIdentifier: id) as? EKReminder
    }

    /// Markiert die übergebenen Reminder-IDs als erledigt.
    func complete(reminderIds: [String]) throws {
        guard !reminderIds.isEmpty else { return }
        for rid in reminderIds {
            guard let r = loadReminder(by: rid) else { continue }
            if !r.isCompleted {
                r.isCompleted = true
                r.completionDate = Date()
                try eventStore.save(r, commit: true) // pro Item committen – robust
            }
        }
    }

    /// Löscht die übergebenen Reminder.
    func remove(reminderIds: [String]) throws {
        guard !reminderIds.isEmpty else { return }
        for rid in reminderIds {
            guard let r = loadReminder(by: rid) else { continue }
            try eventStore.remove(r, commit: true)
        }
    }
}
