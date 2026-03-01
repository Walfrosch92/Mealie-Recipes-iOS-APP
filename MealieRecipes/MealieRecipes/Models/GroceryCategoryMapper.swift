// GroceryCategoryMapper.swift
import Foundation

struct GroceryCategoryMapper {
    /// Versucht: 1) exakter Slug, 2) exakter Name (lc), 3) Fuzzy (Levenshtein <= 2). Sonst nil.
    static func map(categoryHint: String?, availableLabels: [ShoppingItem.LabelWrapper]) -> ShoppingItem.LabelWrapper? {
        guard let hintRaw = categoryHint, !hintRaw.isEmpty else { return nil }

        let hint = lcCondense(hintRaw)
        let hintSlug = slugify(hint)

        // 1) exakter slug match
        if let m1 = availableLabels.first(where: {
            let labelSlug = slugify($0.slug ?? $0.name)
            return labelSlug == hintSlug
        }) {
            return m1
        }

        // 2) exakter name (lc)
        if let m2 = availableLabels.first(where: {
            lcCondense($0.name) == hint
        }) {
            return m2
        }

        // 3) fuzzy <= 2
        let best = availableLabels
            .map { label -> (ShoppingItem.LabelWrapper, Int) in
                let nameSlug  = slugify(label.name)
                let labelSlug = slugify(label.slug ?? label.name)
                let d1 = _lev(nameSlug,  hintSlug)
                let d2 = _lev(labelSlug, hintSlug)
                return (label, min(d1, d2))
            }
            .sorted { $0.1 < $1.1 }
            .first

        if let best, best.1 <= 2 { return best.0 }
        return nil
    }
}

// MARK: - Lokale Helper (bewusst andere Namen als in Utilities, damit keine Redefinitions entstehen)

@inline(__always)
private func lcCondense(_ s: String) -> String {
    s.trimmingCharacters(in: .whitespacesAndNewlines)
     .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
     .lowercased()
}

@inline(__always)
private func slugify(_ s: String) -> String {
    let lowered = s.lowercased()
    let folded  = lowered.folding(options: .diacriticInsensitive, locale: .current)
    let dashed  = folded.replacingOccurrences(of: " ", with: "-")
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
    return dashed.components(separatedBy: allowed.inverted).joined()
}

@inline(__always)
private func _lev(_ aStr: String, _ bStr: String) -> Int {
    if aStr == bStr { return 0 }
    if aStr.isEmpty { return bStr.count }
    if bStr.isEmpty { return aStr.count }

    let a = Array(aStr), b = Array(bStr)
    var prev = Array(0...b.count)
    var curr = Array(repeating: 0, count: b.count + 1)

    for i in 0..<a.count {
        curr[0] = i + 1
        for j in 0..<b.count {
            let cost = (a[i] == b[j]) ? 0 : 1
            curr[j + 1] = min(
                curr[j] + 1,       // insert
                prev[j + 1] + 1,   // delete
                prev[j] + cost     // substitute
            )
        }
        swap(&prev, &curr)
    }
    return prev[b.count]
}
