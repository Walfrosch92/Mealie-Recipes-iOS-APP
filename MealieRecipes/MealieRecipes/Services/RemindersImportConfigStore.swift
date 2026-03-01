//
//  RemindersImportConfigStore.swift
//  MealieRecipes
//
//  Created by Michael Haiszan on 17.08.25.
//


// RemindersImportConfigStore.swift
import Foundation

enum RemindersImportConfigStore {
    private static let kListId = "reminders.selectedListId"
    private static let kIsGrocery = "reminders.selectedListIsGrocery"
    private static let kImportedIdCache = "reminders.importedIdCache" // Set<String>

    static var selectedListId: String? {
        get { UserDefaults.standard.string(forKey: kListId) }
        set { UserDefaults.standard.setValue(newValue, forKey: kListId) }
    }

    static var selectedListIsGrocery: Bool {
        get { UserDefaults.standard.bool(forKey: kIsGrocery) }
        set { UserDefaults.standard.setValue(newValue, forKey: kIsGrocery) }
    }

    static func importedIdCache() -> Set<String> {
        if let data = UserDefaults.standard.data(forKey: kImportedIdCache),
           let set = try? JSONDecoder().decode(Set<String>.self, from: data) {
            return set
        }
        return []
    }

    static func saveImportedIdCache(_ set: Set<String>) {
        if let data = try? JSONEncoder().encode(set) {
            UserDefaults.standard.setValue(data, forKey: kImportedIdCache)
        }
    }
}
