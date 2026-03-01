//
//  AutocompleteCacheDebugView.swift
//  MealieRecipes
//
//  Debug view to inspect and manage the autocomplete cache
//

import SwiftUI

struct AutocompleteCacheDebugView: View {
    @StateObject private var cache = IngredientAutocompleteCache.shared
    @State private var searchQuery = ""
    @State private var showUnits = true
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cache-Statistiken")
                                .font(.headline)
                            Text("\(cache.cachedUnits.count) Einheiten, \(cache.cachedNotes.count) Zutaten")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(role: .destructive) {
                        cache.clearCache()
                    } label: {
                        Label("Cache leeren", systemImage: "trash")
                    }
                }
                
                Section {
                    Picker("Anzeigen", selection: $showUnits) {
                        Text("Einheiten (\(cache.cachedUnits.count))").tag(true)
                        Text("Zutaten (\(cache.cachedNotes.count))").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    TextField("Suchen...", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section {
                    if showUnits {
                        unitsSection
                    } else {
                        notesSection
                    }
                }
            }
            .navigationTitle("Autocomplete Cache")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var unitsSection: some View {
        Group {
            if cache.cachedUnits.isEmpty {
                Text("Keine Einheiten gecacht")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                let filtered = filteredItems(from: cache.cachedUnits)
                if filtered.isEmpty && !searchQuery.isEmpty {
                    Text("Keine Treffer für '\(searchQuery)'")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(filtered, id: \.self) { unit in
                        HStack {
                            Image(systemName: "ruler")
                                .foregroundColor(.blue)
                            Text(unit)
                        }
                    }
                }
            }
        }
    }
    
    private var notesSection: some View {
        Group {
            if cache.cachedNotes.isEmpty {
                Text("Keine Zutaten gecacht")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                let filtered = filteredItems(from: cache.cachedNotes)
                if filtered.isEmpty && !searchQuery.isEmpty {
                    Text("Keine Treffer für '\(searchQuery)'")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(filtered, id: \.self) { note in
                        HStack {
                            Image(systemName: "leaf")
                                .foregroundColor(.green)
                            Text(note)
                        }
                    }
                }
            }
        }
    }
    
    private func filteredItems(from set: Set<String>) -> [String] {
        let items = Array(set).sorted()
        
        if searchQuery.isEmpty {
            return items
        }
        
        return items.filter { 
            $0.localizedCaseInsensitiveContains(searchQuery)
        }
    }
}

// MARK: - Preview

#Preview {
    AutocompleteCacheDebugView()
}

// MARK: - Settings Integration Helper

extension View {
    func autocompleteCacheDebugButton() -> some View {
        self.toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: AutocompleteCacheDebugView()) {
                    Image(systemName: "doc.text.magnifyingglass")
                }
            }
        }
    }
}
