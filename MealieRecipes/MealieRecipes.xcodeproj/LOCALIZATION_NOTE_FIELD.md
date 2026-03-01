# 🌍 Lokalisierung für Note-Feld

Füge diese Strings zu den jeweiligen `.strings` Dateien hinzu:

## Deutsch (de.lproj/Localizable.strings)

```strings
/* Ingredient Note Field */
"note" = "Notiz";
"addNote" = "Notiz hinzufügen";
"ingredientNote" = "Zutat-Notiz";
"noteHint" = "z.B. 'Bio', 'gewürfelt', 'für die Glasur'";
"noteOptional" = "Notiz (optional)";
```

## Englisch (en.lproj/Localizable.strings)

```strings
/* Ingredient Note Field */
"note" = "Note";
"addNote" = "Add Note";
"ingredientNote" = "Ingredient Note";
"noteHint" = "e.g. 'organic', 'diced', 'for frosting'";
"noteOptional" = "Note (optional)";
```

## Usage in Code

```swift
// Im TextField
TextField("note".localized, text: note)
    .placeholder(when: note.wrappedValue.isEmpty) {
        Text("noteHint".localized)
            .foregroundColor(.secondary)
    }

// Als Label
Text("ingredientNote".localized)
    .font(.caption)
    .foregroundColor(.secondary)
```

## Accessibility

```swift
Button(action: { showNoteField.toggle() }) {
    Image(systemName: ingredient.hasNote ? "note.text" : "note.text.badge.plus")
}
.accessibilityLabel(ingredient.hasNote ? 
    "Notiz bearbeiten" : "Notiz hinzufügen")
.accessibilityHint("Zusätzliche Anmerkung zur Zutat")
```
