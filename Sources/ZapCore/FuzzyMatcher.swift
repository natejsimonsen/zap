import Foundation

/// Subsequence fuzzy matching with boundary-aware scoring.
///
/// `score` returns `nil` when `query` is not a case-insensitive subsequence of the
/// candidate, otherwise an integer where a higher value is a better match. The
/// scoring favours, in rough order: exact matches, prefix matches, matches at word
/// boundaries (start of word or camelCase hump), and runs of consecutive characters.
public enum FuzzyMatcher {
    // Tunable weights. Chosen so that structural wins (prefix, boundary) dominate.
    private static let boundaryBonus = 12
    private static let consecutiveBonus = 8
    private static let prefixBonus = 20
    private static let exactBonus = 100
    private static let gapPenalty = 1

    public static func matches(query: String, in candidate: String) -> Bool {
        score(query: query, in: candidate) != nil
    }

    public static func score(query: String, in candidate: String) -> Int? {
        let cand = Array(candidate)
        let candLower = cand.map { Character($0.lowercased()) }
        let q = Array(query.lowercased())

        if q.isEmpty { return 0 }
        if q.count > cand.count { return nil }

        var total = 0
        var candIdx = 0
        var lastMatch = -1

        for qc in q {
            var found = -1
            while candIdx < candLower.count {
                if candLower[candIdx] == qc {
                    found = candIdx
                    break
                }
                candIdx += 1
            }
            if found == -1 { return nil }

            var charScore = 1
            if isBoundary(cand, at: found) { charScore += boundaryBonus }
            if found == lastMatch + 1 {
                charScore += consecutiveBonus
            } else if lastMatch >= 0 {
                charScore -= min(found - lastMatch - 1, 6) * gapPenalty
            }
            total += charScore
            lastMatch = found
            candIdx = found + 1
        }

        // Structural bonuses evaluated on the whole match.
        if candLower.count == q.count { total += exactBonus }
        else if candLower.starts(with: q) { total += prefixBonus }

        return total
    }

    /// A boundary is index 0, a char following a separator, or a camelCase hump.
    private static func isBoundary(_ chars: [Character], at index: Int) -> Bool {
        if index == 0 { return true }
        let prev = chars[index - 1]
        if prev == " " || prev == "-" || prev == "_" || prev == "." { return true }
        let cur = chars[index]
        if cur.isUppercase && prev.isLowercase { return true }
        return false
    }
}
