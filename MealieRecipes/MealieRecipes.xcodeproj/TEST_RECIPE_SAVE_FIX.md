# 🧪 TEST-ANLEITUNG: Rezept-Speichern Fix

## ⚡ Quick Test

### **Was zu testen ist:**
Das Speichern von Rezepten mit verschiedenen Unit-Namen.

---

## 📝 Test 1: "Stk" → "Stück"

### **Schritte:**
1. Öffne "Nutella Torte" Rezept
2. Erste Zutat ändern:
   - Von: `8 Stk Eier (Größe M)`
   - Zu: `8 Stueck Eier (Größe M)`
3. Save klicken

### **Erwartete Console Logs:**
```
⌨️ Keyboard versteckt - Focus States zurückgesetzt

✅ Loaded 42 units from server
✅ Loaded 157 foods from server

🔍 Resolved Units:
   'Stueck' → 'Stück'

🔄 Ingredient resolved:
   unit: 'Stueck' → 'Stück'
   Final: quantity=8.0 unit="Stück" food="Eier (Größe M)" note="nil"

📤 ═══════════════════════════════════════════
📤 PATCH Request wird vorbereitet
   [1] quantity=8.0 unit=Stück food=Eier (Größe M) note=nil
📤 ═══════════════════════════════════════════

📥 HTTP Response:
   Status Code: 200
✅ Rezept erfolgreich aktualisiert
```

### **Erwartung:**
- ✅ Keine RTIInputSystemClient Warnung
- ✅ Keine ValueError
- ✅ HTTP 200 OK
- ✅ Rezept gespeichert

---

## 📝 Test 2: "gramm" → "Gramm"

### **Schritte:**
1. Öffne Rezept
2. Zutat ändern:
   - Von: `200 Gramm Zucker`
   - Zu: `200 gramm Zucker`
3. Save klicken

### **Erwartete Console Logs:**
```
🔍 Resolved Units:
   'gramm' → 'Gramm'

🔄 Ingredient resolved:
   unit: 'gramm' → 'Gramm'
```

### **Erwartung:**
- ✅ HTTP 200 OK
- ✅ Unit "gramm" zu "Gramm" normalisiert

---

## 📝 Test 3: Neue Unit erstellen

### **Schritte:**
1. Öffne Rezept
2. Neue Zutat hinzufügen:
   - `1 Handvoll Nüsse`
3. Save klicken

### **Erwartete Console Logs:**
```
➕ Creating new unit: 'Handvoll'

📤 Sending ingredient:
  food: "Nüsse"
  unit: "Handvoll"
  quantity: 1.0
```

### **Erwartung:**
- ✅ HTTP 200 OK
- ✅ Neue Unit "Handvoll" im System erstellt
- ✅ Rezept gespeichert

---

## 📝 Test 4: Bestehende Zutat mit Note

### **Schritte:**
1. Öffne Rezept
2. Zutat mit Note:
   - `1 Liter Schlagobers` (Note: "für die Creme")
3. Save klicken

### **Erwartete Console Logs:**
```
📤 Sending ingredient:
  food: "Schlagobers"
  note: "für die Creme"
  quantity: 1.0
  unit: "Liter"
```

### **Erwartung:**
- ✅ HTTP 200 OK
- ✅ Note wird korrekt gesendet

---

## 📝 Test 5: Vollständiges Rezept

### **Schritte:**
1. Öffne "Nutella Torte"
2. Keine Änderungen machen
3. Save klicken

### **Erwartete Console Logs:**
```
✅ Loaded 42 units from server
✅ Loaded 157 foods from server

📤 ═══════════════════════════════════════════
📤 PATCH Request wird vorbereitet
   Recipe: Nutella Torte
   Ingredients: 12
   
   🔍 Zutaten-Details:
      [1] quantity=8.0 unit=Stück food=Eier (Größe M) note=nil
      [2] quantity=200.0 unit=Gramm food=Zucker note=nil
      ...
      [6] quantity=1.0 unit=Liter food=Schlagobers note=für die Creme
      ...
📤 ═══════════════════════════════════════════

📥 HTTP Response:
   Status Code: 200
✅ Rezept erfolgreich aktualisiert
```

### **Erwartung:**
- ✅ Keine Fehler
- ✅ Alle Zutaten korrekt geloggt
- ✅ HTTP 200 OK

---

## ❌ Was bei Fehler zu prüfen ist:

### **Fehler: HTTP 500 ValueError**

**Mögliche Ursachen:**
1. Unit-Lookup funktioniert nicht
   - Prüfe: Werden Units vom Server geladen?
   - Log sollte zeigen: `✅ Loaded X units from server`

2. Unit existiert nicht und konnte nicht erstellt werden
   - Prüfe: Gibt es einen "Creating new unit" Log?
   - Prüfe: Berechtigungen für Unit-Erstellung?

3. Food Name falsch
   - Prüfe: Wird Food auch resolved?
   - Aktiviere Food Lookup ähnlich wie Units

**Debug-Schritte:**
```swift
// In EditRecipeView.swift, vor dem Save:
#if DEBUG
for ingredient in recipe.ingredients {
    print("DEBUG Ingredient:")
    print("  food: \(ingredient.food ?? "nil")")
    print("  unit: \(ingredient.unit ?? "nil")")
    print("  quantity: \(ingredient.quantity?.description ?? "nil")")
    print("  note: \(ingredient.note ?? "nil")")
}
#endif
```

---

### **Fehler: RTIInputSystemClient Warnung**

**Lösung:**
- Stelle sicher dass `hideKeyboard()` **vor** dem Network Request aufgerufen wird
- Prüfe Log: `⌨️ Keyboard versteckt - Focus States zurückgesetzt`

---

### **Fehler: Units werden nicht resolved**

**Prüfe:**
1. Ist `IngredientLookupService` korrekt importiert?
2. Wird `RecipeUpdatePayload.create(from:)` verwendet?
3. Gibt es Netzwerk-Fehler beim Laden der Units?

**Debug:**
```swift
// In EditRecipeView.swift
do {
    payload = try await RecipeUpdatePayload.create(from: recipe)
} catch {
    print("❌ Payload creation failed: \(error)")
    // Fallback verwenden
}
```

---

## ✅ Success Criteria

Nach dem Test sollten folgende Punkte erfüllt sein:

- [x] Keine RTIInputSystemClient Warnung
- [x] Keine HTTP 500 ValueError
- [x] HTTP 200 OK beim Speichern
- [x] Units werden korrekt resolved
- [x] Console Logs sind detailliert und hilfreich
- [x] Rezept wird in der Web-UI korrekt angezeigt
- [x] Neue Units können erstellt werden
- [x] Fuzzy Matching funktioniert ("Stueck" → "Stück")

---

## 📊 Performance

### **Erste Save-Operation:**
- Lädt Units/Foods vom Server (~500ms)
- Resolved alle Ingredients (~50ms)
- Sendet PATCH Request (~300ms)
- **Total: ~850ms**

### **Folgende Save-Operationen:**
- Units/Foods aus Cache (0ms)
- Resolved alle Ingredients (~50ms)
- Sendet PATCH Request (~300ms)
- **Total: ~350ms**

**Cache wird automatisch alle 5 Minuten aufgefrischt.**

---

## 🎯 Nächste Schritte

1. **Teste alle Szenarien** (siehe oben)
2. **Prüfe Console Logs** auf Warnungen/Fehler
3. **Verifiziere in Web-UI** dass Rezepte korrekt gespeichert wurden
4. **Beta-Test** mit echten Usern und verschiedenen Rezepten
5. **Release** wenn alle Tests bestanden

---

**Viel Erfolg beim Testen!** 🎉

Falls Probleme auftreten, schicke mir bitte:
- Vollständige Console Logs
- Schritte zum Reproduzieren
- Screenshot der Web-UI (falls relevant)
