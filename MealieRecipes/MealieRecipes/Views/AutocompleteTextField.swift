//
//  AutocompleteTextField.swift
//  MealieRecipes
//
//  TextField with autocomplete dropdown suggestions
//

import SwiftUI

struct AutocompleteTextField: View {
    let placeholder: String
    @Binding var text: String
    let suggestions: [String]
    var keyboardType: UIKeyboardType = .default
    var onCommit: (() -> Void)? = nil
    
    @FocusState private var isFocused: Bool
    @State private var showSuggestions = false
    
    var body: some View {
        VStack(spacing: 0) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .keyboardType(keyboardType)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    showSuggestions = isFocused && !newValue.isEmpty && !suggestions.isEmpty
                }
                .onChange(of: isFocused) { _, focused in
                    showSuggestions = focused && !text.isEmpty && !suggestions.isEmpty
                }
                .onSubmit {
                    onCommit?()
                }
            
            if showSuggestions {
                suggestionsList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private var suggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button(action: {
                    text = suggestion
                    showSuggestions = false
                    isFocused = false
                    onCommit?()
                }) {
                    HStack {
                        Text(suggestion)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        Spacer()
                        Image(systemName: "arrow.turn.down.left")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.trailing, 8)
                    }
                    .background(Color(.systemBackground))
                }
                .buttonStyle(.plain)
                
                if suggestion != suggestions.last {
                    Divider()
                        .padding(.leading, 12)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(.top, 4)
        .zIndex(1000)
    }
}

// MARK: - Compact Version (für StructuredIngredientRow)

struct CompactAutocompleteTextField: View {
    let placeholder: String
    @Binding var text: String
    let suggestions: [String]
    var width: CGFloat? = nil
    var keyboardType: UIKeyboardType = .default
    var onCommit: (() -> Void)? = nil
    
    @FocusState private var isFocused: Bool
    @State private var showSuggestions = false
    
    var body: some View {
        VStack(spacing: 0) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .keyboardType(keyboardType)
                .frame(width: width)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSuggestions = isFocused && !newValue.isEmpty && !suggestions.isEmpty
                    }
                }
                .onChange(of: isFocused) { _, focused in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSuggestions = focused && !text.isEmpty && !suggestions.isEmpty
                    }
                }
                .onSubmit {
                    onCommit?()
                }
            
            if showSuggestions {
                compactSuggestionsList
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }
    
    private var compactSuggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions.prefix(5), id: \.self) { suggestion in
                        Button(action: {
                            text = suggestion
                            withAnimation {
                                showSuggestions = false
                            }
                            isFocused = false
                            onCommit?()
                        }) {
                            HStack {
                                Text(suggestion)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                Spacer()
                            }
                            .background(Color(.systemBackground))
                        }
                        .buttonStyle(.plain)
                        
                        if suggestion != suggestions.prefix(5).last {
                            Divider()
                                .padding(.leading, 8)
                        }
                    }
                }
            }
            .frame(maxHeight: 150)
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1.5)
        )
        .padding(.top, 2)
        .zIndex(1000)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        AutocompleteTextField(
            placeholder: "Einheit",
            text: .constant("gr"),
            suggestions: ["gramm", "gram", "grams"]
        )
        .padding()
        
        CompactAutocompleteTextField(
            placeholder: "Einheit",
            text: .constant("ml"),
            suggestions: ["ml", "milliliter", "milliliters"],
            width: 100
        )
        .padding()
    }
}
