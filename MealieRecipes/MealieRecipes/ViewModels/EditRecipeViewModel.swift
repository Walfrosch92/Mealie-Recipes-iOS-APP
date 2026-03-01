//
//  EditRecipeViewModel.swift
//  MealieRecipes
//
//  Created by Michael Haiszan on 05.12.25.
//

import SwiftUI

struct IngredientRow: View {
    @Binding var ingredient: Ingredient
    let onDelete: () -> Void
    let isStructured: Bool
    
    // Direkte Bindings ohne @State
    private var quantityText: Binding<String> {
        Binding(
            get: {
                guard let qty = ingredient.quantity else { return "" }
                return qty.truncatingRemainder(dividingBy: 1) == 0 ?
                       String(Int(qty)) :
                       String(format: "%.2f", qty).replacingOccurrences(of: ".00", with: "")
            },
            set: {
                if $0.isEmpty {
                    ingredient.quantity = nil
                } else if let value = Double($0.replacingOccurrences(of: ",", with: ".")) {
                    ingredient.quantity = value
                }
            }
        )
    }
    
    private var unitText: Binding<String> {
        Binding(
            get: { ingredient.unit ?? "" },
            set: { ingredient.unit = $0.isEmpty ? nil : $0 }
        )
    }
    
    private var noteText: Binding<String> {
        Binding(
            get: { ingredient.note ?? "" },
            set: { ingredient.note = $0.isEmpty ? nil : $0 }
        )
    }
    
    var body: some View {
        if isStructured {
            StructuredRow
        } else {
            SimpleRow
        }
    }
    
    private var StructuredRow: some View {
        HStack(spacing: 8) {
            // Menge
            TextField("", text: quantityText)
                .frame(width: 50)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            
            // Einheit
            TextField("", text: unitText)
                .frame(width: 70)
                .textFieldStyle(.roundedBorder)
            
            // Zutat
            TextField("Zutat", text: noteText)
                .textFieldStyle(.roundedBorder)
            
            Spacer()
            
            // Löschen-Button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
    
    private var SimpleRow: some View {
        HStack {
            // Einfaches Textfeld
            TextField("Zutat", text: Binding(
                get: { buildFullText(from: ingredient) },
                set: { updateIngredient(from: $0) }
            ))
            .textFieldStyle(.roundedBorder)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
    
    private func buildFullText(from ingredient: Ingredient) -> String {
        var parts: [String] = []
        
        if let quantity = ingredient.quantity {
            if quantity.truncatingRemainder(dividingBy: 1) == 0 {
                parts.append(String(Int(quantity)))
            } else {
                parts.append(String(format: "%.2f", quantity).replacingOccurrences(of: ".00", with: ""))
            }
        }
        
        if let unit = ingredient.unit, !unit.isEmpty {
            parts.append(unit)
        }
        
        if let note = ingredient.note, !note.isEmpty {
            parts.append(note)
        }
        
        return parts.joined(separator: " ")
    }
    
    private func updateIngredient(from text: String) {
        let parseResult = IngredientQuantityParser.parse(from: text)
        
        ingredient.quantity = parseResult.qty
        ingredient.unit = parseResult.unit
        ingredient.note = parseResult.cleaned.isEmpty ? nil : parseResult.cleaned
    }
}
