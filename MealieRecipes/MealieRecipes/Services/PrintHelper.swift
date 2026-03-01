//
//  PrintHelper.swift
//  MealieRecipes
//
//  Created by Michael Haiszan on 05.12.25.
//

import Foundation

// MARK: - Globale Logging-Funktionen

/// Loggt eine Nachricht sowohl in die Console als auch in die Log-Datei
public func logMessage(_ message: String) {
    Swift.print(message)
    
    if AppSettings.shared.enableLogging {
        LogManager.shared.logPrint(message)
    }
}

/// Loggt mehrere Items (wie print() Funktion)
public func logMessage(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let output = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(output, terminator: terminator)
    
    if AppSettings.shared.enableLogging {
        LogManager.shared.logPrint(output)
    }
}
