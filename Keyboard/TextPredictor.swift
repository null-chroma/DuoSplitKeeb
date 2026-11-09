import UIKit

/// Spelling correction, completions and text replacements, built on `UITextChecker` and the
/// user's supplementary lexicon (contacts and Settings → Keyboard → Text Replacement).
final class TextPredictor {
    var language = "en_US"

    private let checker = UITextChecker()
    private var knownWords: Set<String> = []
    private var shortcuts: [String: String] = [:]
    private var ignored: Set<String> = []

    func load(lexicon: UILexicon) {
        for entry in lexicon.entries {
            let input = entry.userInput
            let output = entry.documentText
            if input.caseInsensitiveCompare(output) == .orderedSame {
                knownWords.insert(output.lowercased())
            } else if !input.isEmpty {
                shortcuts[input.lowercased()] = output
            }
            for word in output.split(whereSeparator: { $0.isWhitespace }) {
                knownWords.insert(word.lowercased())
            }
        }
    }

    /// The word immediately before the cursor.
    func currentWord(in text: String) -> String {
        var chars: [Character] = []
        for c in text.reversed() {
            if c.isLetter || c.isNumber || c == "'" || c == "\u{2019}" {
                chars.append(c)
            } else {
                break
            }
        }
        var word = String(chars.reversed())
        while word.first == "'" || word.first == "\u{2019}" { word.removeFirst() }
        return word
    }

    /// Accept a word as correct from now on.
    func learn(_ word: String) {
        guard !word.isEmpty else { return }
        ignored.insert(word.lowercased())
        if !UITextChecker.hasLearnedWord(word) {
            UITextChecker.learnWord(word)
        }
    }

    /// Don't autocorrect this word again during this session (used after an undo).
    func ignore(_ word: String) {
        ignored.insert(word.lowercased())
    }

    /// The replacement to apply automatically when a word is finished, if any.
    func autocorrection(for word: String) -> String? {
        guard !word.isEmpty, !word.contains(where: { $0.isNumber }) else { return nil }
        let lower = word.lowercased()
        if let expansion = shortcuts[lower] { return expansion }
        if ignored.contains(lower) { return nil }
        if word == "i" { return "I" }
        guard word.count >= 2, !isKnown(word) else { return nil }
        guard let best = guesses(for: word).first else { return nil }
        let limit = word.count <= 3 ? 1 : 2
        guard Self.editDistance(best.lowercased(), lower) <= limit else { return nil }
        return matchCase(best, to: word)
    }

    func suggestions(for word: String, autocorrect: Bool) -> [Suggestion] {
        guard !word.isEmpty else { return [] }
        var out = [Suggestion(text: word, kind: .verbatim)]
        var seen: Set<String> = [word.lowercased()]

        func add(_ text: String, _ kind: Suggestion.Kind, auto: Bool = false) {
            guard out.count < 3, !seen.contains(text.lowercased()) else { return }
            seen.insert(text.lowercased())
            out.append(Suggestion(text: text, kind: kind, isAutocorrection: auto))
        }

        if let fix = autocorrection(for: word), fix != word {
            add(fix, .correction, auto: autocorrect)
        }
        if !word.contains(where: { $0.isNumber }) {
            if !isKnown(word) {
                for g in guesses(for: word) { add(matchCase(g, to: word), .correction) }
            }
            if word.count >= 2 {
                for c in completions(for: word) { add(matchCase(c, to: word), .completion) }
            }
        }
        return out
    }

    // MARK: - Private

    private func isKnown(_ word: String) -> Bool {
        let lower = word.lowercased()
        if knownWords.contains(lower) || ignored.contains(lower) { return true }
        let range = NSRange(location: 0, length: (word as NSString).length)
        let miss = checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0,
                                                 wrap: false, language: language)
        return miss.location == NSNotFound
    }

    private func guesses(for word: String) -> [String] {
        let range = NSRange(location: 0, length: (word as NSString).length)
        return checker.guesses(forWordRange: range, in: word, language: language) ?? []
    }

    private func completions(for word: String) -> [String] {
        let range = NSRange(location: 0, length: (word as NSString).length)
        return checker.completions(forPartialWordRange: range, in: word, language: language) ?? []
    }

    private func matchCase(_ candidate: String, to typed: String) -> String {
        guard let first = typed.first else { return candidate }
        if typed.count > 1, typed == typed.uppercased(), typed != typed.lowercased() {
            return candidate.uppercased()
        }
        if first.isUppercase, let c = candidate.first {
            return c.uppercased() + candidate.dropFirst()
        }
        return candidate
    }

    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        var cur = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            cur[0] = i
            for j in 1...b.count {
                cur[j] = a[i - 1] == b[j - 1]
                    ? prev[j - 1]
                    : 1 + min(prev[j - 1], prev[j], cur[j - 1])
            }
            swap(&prev, &cur)
        }
        return prev[b.count]
    }
}
