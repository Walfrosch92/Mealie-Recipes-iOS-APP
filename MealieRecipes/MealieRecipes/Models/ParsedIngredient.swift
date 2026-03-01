//
//  ParsedIngredient.swift
//  MealieRecipes
//
//  Created by Michael Haiszan on 17.08.25.
//


// IngredientParsing.swift
import Foundation

struct ParsedIngredient {
    let name: String
    let quantity: Double?
    let unit: String?
    let categoryCandidate: String?
    let source: ImportedReminder.SourceKind
}

enum IngredientQuantityParser {
    
    // Result type for parse method
    struct ParseResult {
        let qty: Double?
        let unit: String?
        let cleaned: String
    }
    
    /// Formatiert eine Mengenangabe für die Anzeige
    /// - Entfernt unnötige Dezimalstellen
    /// - Konvertiert zu Brüchen falls passend (z.B. 0.5 → "½", 0.25 → "¼")
    static func formatQuantity(_ quantity: Double) -> String {
        // Bruch-Mapping
        let fractionMap: [(Double, String)] = [
            (0.125, "⅛"),
            (0.25, "¼"),
            (0.333, "⅓"),
            (0.375, "⅜"),
            (0.5, "½"),
            (0.625, "⅝"),
            (0.667, "⅔"),
            (0.75, "¾"),
            (0.875, "⅞")
        ]
        
        // Prüfe auf ganze Zahl
        if quantity == floor(quantity) {
            return "\(Int(quantity))"
        }
        
        // Prüfe auf Bruch-Match (mit Toleranz)
        for (value, symbol) in fractionMap {
            if abs(quantity - value) < 0.01 {
                return symbol
            }
        }
        
        // Prüfe auf gemischte Zahl mit Bruch (z.B. 1.5 → "1 ½")
        let whole = floor(quantity)
        let fraction = quantity - whole
        
        if whole > 0 {
            for (value, symbol) in fractionMap {
                if abs(fraction - value) < 0.01 {
                    return "\(Int(whole)) \(symbol)"
                }
            }
        }
        
        // Fallback: Dezimalzahl mit max. 2 Nachkommastellen
        return String(format: "%.2f", quantity).replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    }
    
    // Alle unterstützten Einheiten in verschiedenen Sprachen
    private static let supportedUnits: [String] = {
        var units = [String]()
        
        // ========== DEUTSCH ==========
        units.append(contentsOf: [
            // Gewicht
            "g", "gramm", "gram", "gr", "gramme",
            "kg", "kilogramm", "kilo", "kgr", "kilogram", "kilogramme",
            "mg", "milligramm", "milligram", "milligramme",
            
            // Volumen
            "ml", "milliliter", "millilitre",
            "l", "liter", "litre", "litr",
            "cl", "centiliter", "centilitre",
            "dl", "deziliter", "deciliter", "decilitre",
            
            // Esslöffel / Teelöffel
            "el", "esslöffel", "essloeffel", "essl", "eßl", "eßlöffel",
            "tl", "teelöffel", "teeloeffel", "teslöffel",
            "msp", "messerspitze", "messersp", "messerspitze",
            "prise", "prisen",
            
            // Tassen / Gläser
            "tasse", "tassen", "tass", "tassn",
            "becher", "bechern",
            "glas", "gläser", "glaeser", "gls",
            "schale", "schalen",
            "schüssel", "schuessel", "schüsseln", "schuesseln",
            "napf", "näpfe", "naepfe",
            "schälchen", "schaelchen",
            
            // Stückangaben
            "stk", "stück", "stueck", "st.", "st", "stk.", "stck", "stck.",
            "stange", "stangen", "stängel", "staengel",
            "scheibe", "scheiben",
            "blatt", "blätter", "blaetter",
            "würfel", "wuerfel", "würfelchen",
            "kugel", "kugeln",
            "rolle", "rollen",
            "stäbchen", "staebchen", "stäb", "staeb",
            
            // Obst/Gemüse
            "zehe", "zehen", "knoblauchzehe", "knoblauchzehen",
            "kopf", "köpfe", "koepfe",
            "knolle", "knollen",
            "bund", "bündel", "buendel", "bd", "bd.",
            "strunk", "strünke", "struenke",
            "busch", "büschel", "bueschel",
            "zweig", "zweige",
            "ast", "äste", "aeste",
            
            // Verpackungen
            "pck", "päckchen", "paeckchen", "pack", "packung", "packungen",
            "dose", "dosen",
            "glas", "gläser", "glaeser",
            "tube", "tuben",
            "beutel", "beuteln",
            "flasche", "flaschen", "fl.",
            "schachtel", "schachteln",
            "tüte", "tuete", "tüten", "tueten",
            
            // Sonstige
            "portion", "portionen", "p.",
            "handvoll", "hand voll", "handvoller",
            "tropfen", "tr.", "trpf", "trpfn",
            "spritzer", "spritzerl",
            "schuss", "schüsse", "schuesse", "schluck", "schlücke", "schluecke",
            "korn", "körner", "koerner",
            "würfel", "würfelzucker", "wuerfelzucker",
            "kelle", "kellen", "schöpfkelle", "schoepfkelle",
            "fingerbreit", "finger breit", "fingerbreite",
            "daumen", "daumengroß", "daumengross",
            "faust", "faustgroß", "faustgross",
            
            // Zeitangaben (für Marinaden etc.)
            "min", "minute", "minuten", "min.",
            "std", "stunde", "stunden", "std.", "h", "hour", "hours",
            "tag", "tage", "tagen", "days"
        ])
        
        // ========== ENGLISCH ==========
        units.append(contentsOf: [
            // Weight
            "g", "gram", "grams", "gr", "gramme", "grammes",
            "kg", "kilogram", "kilograms", "kilo", "kilos",
            "mg", "milligram", "milligrams",
            "oz", "ounce", "ounces",
            "lb", "lbs", "pound", "pounds",
            
            // Volume
            "ml", "milliliter", "milliliters", "millilitre", "millilitres",
            "l", "liter", "liters", "litre", "litres",
            "cl", "centiliter", "centiliters", "centilitre", "centilitres",
            "dl", "deciliter", "deciliters", "decilitre", "decilitres",
            
            // Spoons
            "tbsp", "tablespoon", "tablespoons", "tbl", "tbs", "tbspn",
            "tsp", "teaspoon", "teaspoons", "tspn",
            "dsp", "dessertspoon", "dessertspoons",
            "pinch", "pinches",
            
            // Cups
            "cup", "cups", "c", "c.",
            "glass", "glasses",
            "mug", "mugs",
            "bowl", "bowls",
            "jar", "jars",
            "can", "cans",
            
            // Pieces
            "pc", "pcs", "piece", "pieces",
            "slice", "slices",
            "clove", "cloves",
            "head", "heads",
            "bunch", "bunches",
            "stalk", "stalks",
            "stem", "stems",
            "leaf", "leaves",
            "cube", "cubes",
            "ball", "balls",
            "roll", "rolls",
            "stick", "sticks",
            
            // Packages
            "pack", "package", "packages", "pkg", "pkgs",
            "box", "boxes",
            "bottle", "bottles", "btl", "btls",
            "tube", "tubes",
            "bag", "bags",
            "tin", "tins",
            "carton", "cartons",
            
            // Others
            "dash", "dashes",
            "drop", "drops",
            "splash", "splashes",
            "shot", "shots",
            "grain", "grains",
            "handful", "handfuls",
            "portion", "portions",
            "serving", "servings",
            
            // Time
            "min", "mins", "minute", "minutes",
            "hr", "hrs", "hour", "hours",
            "day", "days"
        ])
        
        // ========== FRANZÖSISCH ==========
        units.append(contentsOf: [
            // Poids
            "g", "gramme", "grammes", "gr",
            "kg", "kilogramme", "kilogrammes", "kilo", "kilos",
            "mg", "milligramme", "milligrammes",
            
            // Volume
            "ml", "millilitre", "millilitres",
            "l", "litre", "litres",
            "cl", "centilitre", "centilitres",
            "dl", "décilitre", "decilitre", "decilitres",
            
            // Cuillères
            "càs", "cuillère à soupe", "cuillères à soupe",
            "càc", "cuillère à café", "cuillères à café",
            "pincée", "pincées",
            
            // Tasses
            "tasse", "tasses",
            "verre", "verres",
            "bol", "bols",
            "pot", "pots",
            
            // Pièces
            "pièce", "pièces", "pc", "pcs",
            "tranche", "tranches",
            "gousse", "gousses",
            "tête", "têtes",
            "bouquet", "bouquets",
            "branche", "branches",
            "feuille", "feuilles",
            "cube", "cubes",
            
            // Emballages
            "paquet", "paquets", "pqt",
            "boîte", "boites", "boîtes",
            "bouteille", "bouteilles",
            "tube", "tubes",
            "sachet", "sachets",
            
            // Autres
            "filet", "filets",
            "goutte", "gouttes",
            "noix", "noix de beurre",
            "morceau", "morceaux"
        ])
        
        // ========== ITALIENISCH ==========
        units.append(contentsOf: [
            // Peso
            "g", "grammo", "grammi", "gr",
            "kg", "chilogrammo", "chilogrammi", "chilo", "chili",
            "mg", "milligrammo", "milligrammi",
            
            // Volume
            "ml", "millilitro", "millilitri",
            "l", "litro", "litri",
            "cl", "centilitro", "centilitri",
            "dl", "decilitro", "decilitri",
            
            // Cucchiai
            "cucchiaio", "cucchiai", "cucch.",
            "cucchiaino", "cucchiaini", "cucchi.",
            "pizzico", "pizzichi",
            
            // Tazze
            "tazza", "tazze",
            "bicchiere", "bicchieri",
            "coppa", "coppe",
            "vasetto", "vasetti",
            
            // Pezzi
            "pezzo", "pezzi", "pz", "pz.",
            "fetta", "fette",
            "spicchio", "spicchi",
            "ciuffo", "ciuffi",
            "rametto", "rametti",
            "foglia", "foglie",
            
            // Confezioni
            "confezione", "confezioni",
            "scatola", "scatole",
            "bottiglia", "bottiglie",
            "tubo", "tubi",
            "bustina", "bustine"
        ])
        
        // ========== SPANISCH ==========
        units.append(contentsOf: [
            // Peso
            "g", "gramo", "gramos", "gr",
            "kg", "kilogramo", "kilogramos", "kilo", "kilos",
            "mg", "miligramo", "miligramos",
            
            // Volumen
            "ml", "mililitro", "mililitros",
            "l", "litro", "litros",
            "cl", "centilitro", "centilitros",
            "dl", "decilitro", "decilitros",
            
            // Cucharas
            "cda", "cucharada", "cucharadas",
            "cdta", "cucharadita", "cucharaditas",
            "pizca", "pizcas",
            
            // Tazas
            "taza", "tazas",
            "vaso", "vasos",
            "copa", "copas",
            "bol", "boles",
            
            // Piezas
            "pieza", "piezas", "pza", "pzas",
            "rodaja", "rodajas",
            "diente", "dientes",
            "manojo", "manojos",
            "rama", "ramas",
            "hoja", "hojas",
            
            // Envases
            "paquete", "paquetes", "pqt",
            "lata", "latas",
            "botella", "botellas",
            "tubo", "tubos",
            "sobre", "sobres"
        ])
        
        // ========== NIEDERLÄNDISCH ==========
        units.append(contentsOf: [
            // Gewicht
            "g", "gram", "grammen",
            "kg", "kilogram", "kilogrammen", "kilo", "kilo's",
            "mg", "milligram", "milligrammen",
            "ons", "onsen",
            
            // Volume
            "ml", "milliliter", "millilitres",
            "l", "liter", "litres", "liters",
            "cl", "centiliter", "centilitres",
            "dl", "deciliter", "decilitres",
            
            // Lepels
            "el", "eetlepel", "eetlepels", "eetl", "eetlep",
            "tl", "theelepel", "theelepels", "theel", "theelep",
            "mespunt", "mespuntje", "mespuntjes",
            "snufje", "snuf", "snufjes",
            
            // Kopjes/glazen
            "kopje", "kopjes", "kop",
            "glas", "glazen",
            "kom", "kommen",
            "schaal", "schalen",
            "bakje", "bakjes",
            "mok", "mokken",
            
            // Stukken
            "st", "st.", "stuk", "stuks", "stukje", "stukjes",
            "plak", "plakje", "plakjes",
            "blad", "bladeren",
            "teen", "tenen", "knoflookteen", "knoflooktenen",
            "krop", "kroppen",
            "bos", "bosje", "bosjes",
            "stengel", "stengels",
            "tros", "trossen",
            "bol", "bollen",
            "rol", "rollen",
            "staaf", "staven",
            
            // Verpakkingen
            "pak", "pakje", "pakjes", "pakket", "pakketten",
            "blik", "blikje", "blikjes",
            "fles", "flesje", "flesjes",
            "tube", "tubes",
            "zak", "zakje", "zakjes",
            "doos", "doosje", "doosjes",
            "pot", "potje", "potjes",
            
            // Overig
            "portie", "porties",
            "handje", "handjes",
            "druppel", "druppels", "druppeltje", "druppeltjes",
            "scheut", "scheutje", "scheutjes",
            "schep", "schepje", "schepjes",
            "knoop", "knoopje", "knoopjes",
            "korrel", "korreltje", "korreltjes",
            "klont", "klontje", "klontjes",
            "pluk", "plukje", "plukjes",
            
            // Tijd
            "min", "minuut", "minuten", "min.",
            "uur", "uren", "u",
            "dag", "dagen"
        ])
        
        // ========== ÖSTERREICHISCH/BAYERISCH (Regionale Varianten) ==========
        units.append(contentsOf: [
            "dag", "deka", "dekagramm", "dekagramme",
            "hg", "hektogramm",
            "pfund", "pf",
            "mass", "maß", "masse",
            "seidel", "seidln",
            "krügel", "kruegel",
            "achtel", "achtln",
            "viertel", "viertln",
            "sechzehntel", "sechzehntln",
            "schöpfer", "schoepfer",
            "kracherl", "kracherln"
        ])
        
        // Entferne Duplikate und sortiere nach Länge (längste zuerst)
        let uniqueUnits = Array(Set(units))
        return uniqueUnits.sorted { $0.count > $1.count }
    }()
    
    // Erstelle Regex-Pattern aus allen Einheiten
    private static var unitsRegexPattern: String {
        // Escape spezielle Regex-Zeichen
        let escapedUnits = supportedUnits.map { NSRegularExpression.escapedPattern(for: $0) }
        return escapedUnits.joined(separator: "|")
    }
    
    static func parse(from text: String) -> ParseResult {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // "ca.", "circa", "approx" entfernen in verschiedenen Sprachen
        let approxPatterns = [
            // Deutsch
            "\\bca\\.?\\s*", "\\bcirka\\s*", "\\betwa\\s*", "\\bungefähr\\s*", "\\bungef\\.?\\s*",
            // Englisch
            "\\bapprox\\.?\\s*", "\\bapproximately\\s*", "\\babout\\s*", "\\baround\\s*",
            // Französisch
            "\\benviron\\s*", "\\bapprox\\.?\\s*",
            // Italienisch
            "\\bcirca\\s*", "\\bappross\\.?\\s*",
            // Spanisch
            "\\baproximadamente\\s*", "\\baprox\\.?\\s*",
            // Niederländisch
            "\\bongeveer\\s*", "\\bonge\\.?\\s*", "\\bcirk\\s*"
        ]
        
        for pattern in approxPatterns {
            s = s.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        
        // Brüche Unicode → Dezimal
        let fractionMap: [String: Double] = [
            "¼": 0.25, "½": 0.5, "¾": 0.75,
            "⅓": 0.333, "⅔": 0.667,
            "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875
        ]
        
        for (f, v) in fractionMap {
            s = s.replacingOccurrences(of: f, with: String(v))
        }
        
        // Text-Brüche erkennen: "1/2", "2/3", etc.
        let fractionRegex = #"(\d+)\s*/\s*(\d+)"#
        if let range = s.range(of: fractionRegex, options: .regularExpression) {
            let fractionStr = String(s[range])
            let parts = fractionStr.split(separator: "/")
            if parts.count == 2,
               let numerator = Double(parts[0].trimmingCharacters(in: .whitespaces)),
               let denominator = Double(parts[1].trimmingCharacters(in: .whitespaces)),
               denominator != 0 {
                let value = numerator / denominator
                s = s.replacingOccurrences(of: fractionRegex, with: String(value), options: .regularExpression)
            }
        }
        
        // Bereiche wie "500-600 g" → nehme untere Grenze
        let rangePattern = #"(\d+(?:[.,]\d+)?)\s*[-–—]\s*(\d+(?:[.,]\d+)?)\s*([a-zA-ZäöüÄÖÜéèêëáàâäíìîïóòôöúùûüçßñ]+)?"#
        if let range = s.range(of: rangePattern, options: .regularExpression) {
            let rangeStr = String(s[range])
            let parts = rangeStr.replacingOccurrences(of: ",", with: ".")
                .split { $0 == "-" || $0 == "–" || $0 == "—" }
            
            if let first = parts.first?.trimmingCharacters(in: .whitespaces),
               let value = Double(first.filter("0123456789.".contains)) {
                
                // Extrahiere Einheit aus dem gesamten Bereich
                let unitMatch = rangeStr.range(of: #"[a-zA-ZäöüÄÖÜéèêëáàâäíìîïóòôöúùûüçßñ]+$"#, options: .regularExpression)
                let unit = unitMatch.map { String(rangeStr[$0]) }?.trimmedCondensedLowercased
                
                let cleaned = s.replacingOccurrences(of: rangeStr, with: "").trimmedCondensedLowercased
                return ParseResult(qty: value, unit: unit, cleaned: cleaned)
            }
        }
        
        // Multiplikatoren in verschiedenen Sprachen
        let multiplierPatterns = [
            // Deutsch
            #"(\d+(?:[.,]\d+)?)\s*x\b"#,                    // 2x
            #"(\d+(?:[.,]\d+)?)\s*mal\b"#,                  // 2 mal
            #"(\d+(?:[.,]\d+)?)\s*-fach\b"#,                // 2-fach
            // Englisch
            #"(\d+(?:[.,]\d+)?)\s*times\b"#,                // 2 times
            // Französisch
            #"(\d+(?:[.,]\d+)?)\s*fois\b"#,                 // 2 fois
            // Italienisch
            #"(\d+(?:[.,]\d+)?)\s*volte\b"#,                // 2 volte
            // Spanisch
            #"(\d+(?:[.,]\d+)?)\s*veces\b"#,                // 2 veces
            // Niederländisch
            #"(\d+(?:[.,]\d+)?)\s*keer\b"#,                 // 2 keer
            #"(\d+(?:[.,]\d+)?)\s*maal\b"#                  // 2 maal
        ]
        
        for pattern in multiplierPatterns {
            if let range = s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matchStr = String(s[range])
                let numberStr = matchStr.replacingOccurrences(of: #"[^0-9.,]"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: ",", with: ".")
                let value = Double(numberStr)
                let cleaned = s.replacingOccurrences(of: matchStr, with: "").trimmingCharacters(in: .whitespaces)
                return ParseResult(qty: value, unit: nil, cleaned: cleaned)
            }
        }
        
        // Haupt-Pattern für Menge + Einheit
        // Pattern: Zahl (optional Dezimal) + optionaler Leerraum + Einheit
        let mainPattern = #"(\d+(?:[.,]\d+)?)(?:\s*)("# + unitsRegexPattern + #")(?:\b|$)"#
        
        // Zuerst von links nach rechts suchen
        if let range = s.range(of: mainPattern, options: [.regularExpression, .caseInsensitive]) {
            let matchStr = String(s[range])
            
            // Extrahiere Zahl
            let numberPart = matchStr.prefix(while: { $0.isNumber || $0 == "." || $0 == "," })
            let numberStr = String(numberPart).replacingOccurrences(of: ",", with: ".")
            let value = Double(numberStr)
            
            // Extrahiere Einheit
            let unitPart = matchStr.dropFirst(numberPart.count).trimmingCharacters(in: .whitespaces)
            let unit = String(unitPart).trimmedCondensedLowercased
            
            // Bereinigten Text
            let cleaned = s.replacingOccurrences(of: matchStr, with: "").trimmingCharacters(in: .whitespaces)
            
            return ParseResult(qty: value, unit: unit, cleaned: cleaned)
        }
        
        // Auch von rechts nach links suchen (für "Zucker 250g")
        let reversePattern = #"\b("# + unitsRegexPattern + #")(?:\s*)(\d+(?:[.,]\d+)?)"#
        
        if let range = s.range(of: reversePattern, options: [.regularExpression, .caseInsensitive]) {
            let matchStr = String(s[range])
            
            // Finde die Zahl am Ende
            let numberRegex = #"\d+(?:[.,]\d+)?"#
            if let numberRange = matchStr.range(of: numberRegex, options: .regularExpression) {
                let numberStr = String(matchStr[numberRange]).replacingOccurrences(of: ",", with: ".")
                let value = Double(numberStr)
                
                // Einheit ist alles vor der Zahl
                let unitPart = matchStr[..<numberRange.lowerBound].trimmingCharacters(in: .whitespaces)
                let unit = unitPart.trimmedCondensedLowercased
                
                // Bereinigten Text
                let cleaned = s.replacingOccurrences(of: matchStr, with: "").trimmingCharacters(in: .whitespaces)
                
                return ParseResult(qty: value, unit: unit, cleaned: cleaned)
            }
        }
        
        // Nur Zahl am Anfang: "2 Bananen", "1.5 Milch"
        if let range = s.range(of: #"^\s*(\d+(?:[.,]\d+)?)\b"#, options: .regularExpression) {
            let numberStr = String(s[range]).replacingOccurrences(of: ",", with: ".")
            let value = Double(numberStr)
            let cleaned = s.replacingOccurrences(of: s[range], with: "").trimmingCharacters(in: .whitespaces)
            return ParseResult(qty: value, unit: nil, cleaned: cleaned)
        }
        
        // Zahl am Ende: "Bananen 2", "Milch 1.5"
        if let range = s.range(of: #"(\d+(?:[.,]\d+)?)\s*$"#, options: .regularExpression) {
            let numberStr = String(s[range]).replacingOccurrences(of: ",", with: ".")
            let value = Double(numberStr)
            let cleaned = s.replacingOccurrences(of: s[range], with: "").trimmingCharacters(in: .whitespaces)
            return ParseResult(qty: value, unit: nil, cleaned: cleaned)
        }
        
        return ParseResult(qty: nil, unit: nil, cleaned: s)
    }
}

// MARK: - Hilfs-Erweiterung für String (Global verfügbar)

extension String {
    /// Trimmt Whitespace, kondensiert mehrfache Leerzeichen zu einem und konvertiert zu Kleinbuchstaben
    var trimmedCondensedLowercased: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
    }
}

// MARK: - Globale Hilfs-Funktionen für Zeitformatierung

/// Formatiert Minuten in ein lesbares Format (z.B. "1h 45min" oder "45min")
func formatMinutes(_ minutes: Int) -> String {
    if minutes < 60 {
        return "\(minutes)min"
    }
    let hours = minutes / 60
    let mins = minutes % 60
    if mins == 0 {
        return "\(hours)h"
    }
    return "\(hours)h \(mins)min"
}

// Debug-Funktion zum Testen
func debugQuantityParser() {
    let testCases = [
        // Deutsch
        "1 Gramm Butter",
        "250 g Zucker",
        "2 Esslöffel Öl",
        "3 Stück Eier",
        "500ml Milch",
        "½ Tasse Mehl",
        "1/2 Bund Petersilie",
        "ca. 300 g Hackfleisch",
        "2-3 Zehen Knoblauch",
        
        // Englisch
        "1 cup flour",
        "2 tbsp oil",
        "3 cloves garlic",
        "1.5 pounds potatoes",
        "approx 250 ml milk",
        
        // Französisch
        "2 cuillères à soupe d'huile",
        "3 gousses d'ail",
        "1 paquet de beurre",
        
        // Italienisch
        "2 cucchiai di olio",
        "3 spicchi d'aglio",
        "1 confezione di burro",
        
        // Spanisch
        "2 cucharadas de aceite",
        "3 dientes de ajo",
        "1 paquete de mantequilla",
        
        // Niederländisch
        "2 eetlepels olie",
        "3 tenen knoflook",
        "1 bosje peterselie",
        "ongeveer 250 ml melk",
        "1 stukje boter",
        
        // Komplexe Fälle
        "1-2 EL Honig",
        "ca. 200-250g Mehl",
        "2x 125g Joghurt",
        "3 mal 1 EL Zucker"
    ]
    
    print("=== QuantityParser Tests ===")
    for test in testCases {
        let result = QuantityParser.parse(from: test)
        print("Eingabe: '\(test)'")
        print("  → Menge: \(result.qty?.description ?? "nil")")
        print("  → Einheit: \(result.unit ?? "nil")")
        print("  → Bereinigt: '\(result.cleaned)'")
        print()
    }
}

enum CategoryHeuristics {
    /// Erkenne Kategorie-Hinweis im Titel/Notizen:
    /// [Produce] Äpfel, ⟨Meat⟩ Rind, "(Kategorie: Backwaren) Brötchen"
    static func extractCategoryHint(in text: String) -> (hint: String?, cleaned: String) {
        var s = text
        let patterns = [
            #"\[([^\]]+)\]"#,          // [Produce]
            #"⟨([^⟩]+)⟩"#,             // ⟨Meat⟩
            #"(?i)kategorie:\s*([A-Za-zäöüÄÖÜ\s\-]+)"#
        ]
        for p in patterns {
            if let r = s.range(of: p, options: .regularExpression) {
                let match = String(s[r])
                if let inner = match.trimmingCharacters(in: CharacterSet(charactersIn: "[]⟨⟩")).split(separator: ":").last {
                    s = s.replacingOccurrences(of: match, with: "").trimmingCharacters(in: .whitespaces)
                    return (String(inner).trimmedCondensedLowercased, s)
                }
            }
        }
        return (nil, text)
    }

    /// #Kategorie oder @label aus Titel entfernen und liefern
    static func extractHashAndAt(in text: String) -> (hash: [String], at: [String], cleaned: String) {
        var s = text
        let hash = matches(in: s, pattern: #"(?:^|\s)#([A-Za-z0-9äöüÄÖÜ\-]+)"#)
        let at = matches(in: s, pattern: #"(?:^|\s)@([A-Za-z0-9äöüÄÖÜ\-]+)"#)
        s = s.replacingOccurrences(of: #"(?:^|\s)[#@]([A-Za-z0-9äöüÄÖÜ\-]+)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return (hash.map { $0.trimmedCondensedLowercased }, at.map { $0.trimmedCondensedLowercased }, s)
    }

    private static func matches(in s: String, pattern: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: pattern)
        let ns = s as NSString
        return regex.matches(in: s, range: NSRange(location: 0, length: ns.length)).compactMap {
            guard $0.numberOfRanges >= 2 else { return nil }
            return ns.substring(with: $0.range(at: 1))
        }
    }
}

enum IngredientParser {
    static func parse(rawTitle: String, notes: String?, isGrocery: Bool) -> ParsedIngredient {
        // Fallback Kategorie aus []/⟨⟩/Kategorie:
        let (hint, s1) = CategoryHeuristics.extractCategoryHint(in: rawTitle)

        // Mengen & Einheit
        let parseResult = QuantityParser.parse(from: s1)
        let qty = parseResult.qty
        let unit = parseResult.unit
        let s2 = parseResult.cleaned

        // Hashtags & @label entfernen (am Ende/mitte)
        let (hash, at, s3) = CategoryHeuristics.extractHashAndAt(in: s2)

        // Wenn Grocery-Liste: nutze Category-Hint bevorzugt, sonst hash/at
        let categoryCandidate = (isGrocery ? (hint ?? hash.first ?? at.first) : (hash.first ?? at.first ?? hint))

        // Name bereinigen
        let name = s3.replacingOccurrences(of: "^-\\s*", with: "", options: String.CompareOptions.regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespaces)

        let source: ImportedReminder.SourceKind = isGrocery
            ? (hint != nil ? .groceryApple : (!hash.isEmpty ? .hashtag : (!at.isEmpty ? .atLabel : .heuristic)))
            : (!hash.isEmpty ? .hashtag : (!at.isEmpty ? .atLabel : (hint != nil ? .heuristic : .normal)))

        return ParsedIngredient(name: name, quantity: qty, unit: unit, categoryCandidate: categoryCandidate, source: source)
    }
}


