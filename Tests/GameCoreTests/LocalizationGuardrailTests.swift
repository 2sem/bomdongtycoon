import XCTest

/// Keeps the English build from silently falling back to Korean.
///
/// A catalog entry with no `en` value, or an `en` value whose format specifiers differ from the
/// source text, does not fail anywhere at runtime: Foundation just returns the Korean. These tests
/// are the only place that mistake is visible. Both read files from the checkout, so they need no
/// app host.
final class LocalizationGuardrailTests: XCTestCase {

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private struct Entry {
        let key: String
        let en: String?
        let ko: String?
    }

    private func catalog() throws -> [Entry] {
        let url = Self.root.appendingPathComponent("Resources/Localizable.xcstrings")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let strings = try XCTUnwrap(json?["strings"] as? [String: [String: Any]])
        func value(_ entry: [String: Any], _ language: String) -> String? {
            let localizations = entry["localizations"] as? [String: [String: Any]]
            return (localizations?[language]?["stringUnit"] as? [String: Any])?["value"] as? String
        }
        return strings.map { Entry(key: $0.key, en: value($0.value, "en"), ko: value($0.value, "ko")) }
    }

    /// `%@`, `%lld`, `%1$@`, `%.1f`... as an order-free multiset; `%%` is not a specifier.
    private func specifiers(_ text: String) -> [String] {
        let pattern = #"%(?:\d+\$)?[-+ 0#]*\d*(?:\.\d+)?(?:ll|l|h)?[@dDuUxXfFeEgGcCsSp]"#
        let stripped = text.replacingOccurrences(of: "%%", with: "")
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(stripped.startIndex..., in: stripped)
        return regex.matches(in: stripped, range: range).map { match in
            let spec = String(stripped[Range(match.range, in: stripped)!])
            return spec.replacingOccurrences(of: #"\d+\$"#, with: "", options: .regularExpression)
        }.sorted()
    }

    func testEveryEntryHasAnEnglishValue() throws {
        let missing = try catalog().filter { ($0.en ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
        XCTAssertEqual(missing.map(\.key), [], "entries without an en value fall back to Korean")
    }

    func testEnglishKeepsTheSourceFormatSpecifiers() throws {
        var mismatched: [String] = []
        for entry in try catalog() {
            guard let en = entry.en else { continue }
            // A dotted key carries its Korean in `ko`; a Korean key is its own source text.
            let source = entry.ko ?? entry.key
            if specifiers(source) != specifiers(en) { mismatched.append(entry.key) }
        }
        XCTAssertEqual(mismatched, [], "specifier mismatch silently falls back to Korean")
    }

    func testEnglishContainsNoHangul() throws {
        let leaked = try catalog().filter { $0.en?.range(of: "[가-힣]", options: .regularExpression) != nil }
        XCTAssertEqual(leaked.map(\.key), [])
    }

    // MARK: - Hangul literals in source

    /// Every string literal in `Sources/` that contains Hangul must be a catalog key (an
    /// interpolation stands for any specifier). A new Korean literal that is not in the catalog
    /// renders as Korean in every language. Comments are skipped.
    func testEveryHangulLiteralInSourcesIsACatalogKey() throws {
        let keys = try catalog().map(\.key)
        let specifier = #"%(?:\d+\$)?(?:lld|@|d|lf|f|\.\d+f)"#
        func isKey(_ literal: String) -> Bool {
            let pattern = "^" + NSRegularExpression.escapedPattern(for: literal)
                .replacingOccurrences(of: "\u{0}", with: specifier) + "$"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
            return keys.contains { regex.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil }
        }

        let sources = Self.root.appendingPathComponent("Sources")
        let walker = try XCTUnwrap(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        var offenders: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            for (line, literal) in Self.literals(in: text)
            where literal.range(of: "[가-힣]", options: .regularExpression) != nil && !isKey(literal) {
                let name = url.path.replacingOccurrences(of: Self.root.path + "/", with: "")
                offenders.append("\(name):\(line) \(literal.replacingOccurrences(of: "\u{0}", with: "\\(…)"))")
            }
        }
        XCTAssertEqual(offenders, [], "wrap in String(localized:) and add an en value to Localizable.xcstrings")
    }

    /// String literals outside comments, as (line, text) with each interpolation replaced by NUL.
    private static func literals(in source: String) -> [(Int, String)] {
        let s = Array(source.unicodeScalars)
        var result: [(Int, String)] = []
        var line = 1

        func starts(_ text: String, at i: Int) -> Bool {
            let t = Array(text.unicodeScalars)
            return i + t.count <= s.count && Array(s[i..<(i + t.count)]) == t
        }

        // Returns the index after the closing quote; appends the literal's text to `out`.
        func scanString(from start: Int, into out: inout String) -> Int {
            let triple = starts("\"\"\"", at: start)
            var i = start + (triple ? 3 : 1)
            while i < s.count {
                if triple ? starts("\"\"\"", at: i) : s[i] == "\"" { return i + (triple ? 3 : 1) }
                if s[i] == "\\", i + 1 < s.count, s[i + 1] == "(" {
                    var depth = 1
                    i += 2
                    while i < s.count, depth > 0 {
                        if s[i] == "\"" {
                            var nested = ""
                            i = scanString(from: i, into: &nested)
                            continue
                        }
                        if s[i] == "(" { depth += 1 } else if s[i] == ")" { depth -= 1 }
                        if s[i] == "\n" { line += 1 }
                        i += 1
                    }
                    out.unicodeScalars.append("\u{0}")
                    continue
                }
                if s[i] == "\\", i + 1 < s.count {
                    out.unicodeScalars.append(s[i])
                    out.unicodeScalars.append(s[i + 1])
                    i += 2
                    continue
                }
                if s[i] == "\n" { line += 1 }
                out.unicodeScalars.append(s[i])
                i += 1
            }
            return i
        }

        var i = 0
        while i < s.count {
            if s[i] == "\n" { line += 1; i += 1; continue }
            if starts("//", at: i) {
                while i < s.count, s[i] != "\n" { i += 1 }
                continue
            }
            if starts("/*", at: i) {
                i += 2
                while i < s.count, !starts("*/", at: i) {
                    if s[i] == "\n" { line += 1 }
                    i += 1
                }
                i += 2
                continue
            }
            if s[i] == "\"" {
                let startLine = line
                var text = ""
                i = scanString(from: i, into: &text)
                result.append((startLine, text))
                continue
            }
            i += 1
        }
        return result
    }
}
