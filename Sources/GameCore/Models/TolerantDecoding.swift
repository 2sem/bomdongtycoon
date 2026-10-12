import Foundation
import os

/// Non-fatal diagnostics for saves that decode, but not as written.
enum SaveDiagnostics {
    private static let logger = Logger(subsystem: "com.leesam.bomdongtycoon", category: "save")

    /// Test hook; called with `(key, expected type)` for every present-but-mistyped value.
    nonisolated(unsafe) static var onTypeMismatch: ((_ key: String, _ expected: String) -> Void)?

    static func typeMismatch(key: String, expected: Any.Type) {
        logger.error("save key '\(key, privacy: .public)' is present but not a \(String(describing: expected), privacy: .public); using default")
        onTypeMismatch?(key, String(describing: expected))
    }

    static func corruptBlob(_ name: String, bytes: Int) {
        logger.error("save blob '\(name, privacy: .public)' failed to decode (\(bytes) bytes); raw copy kept, using fresh state")
    }
}

extension KeyedDecodingContainer {
    /// A missing key — or a value of an unexpected type or unknown enum case — yields `fallback`
    /// instead of throwing. Saves are decoded whole, so one throw here discards all progress.
    /// An absent key is silent; a present key of the wrong type is reported to `SaveDiagnostics`.
    func decodeOrDefault<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        decodeOrNil(T.self, forKey: key) ?? fallback
    }

    /// Same, for optional properties whose default is `nil`.
    func decodeOrNil<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        do {
            return try decodeIfPresent(type, forKey: key)
        } catch {
            SaveDiagnostics.typeMismatch(key: key.stringValue, expected: type)
            return nil
        }
    }

    /// Decodes an array element by element, dropping entries that fail. Returns nil when the key
    /// is absent or is not an array at all, so the caller can apply its own fallback.
    func decodeLossyArray<T: Decodable>(_ type: T.Type, forKey key: Key) -> [T]? {
        guard contains(key) else { return nil }
        guard var list = try? nestedUnkeyedContainer(forKey: key) else {
            SaveDiagnostics.typeMismatch(key: key.stringValue, expected: [T].self)
            return nil
        }
        var items: [T] = []
        while !list.isAtEnd {
            if let item = try? list.decode(T.self) {
                items.append(item)
            } else {
                SaveDiagnostics.typeMismatch(key: "\(key.stringValue)[\(items.count)]", expected: T.self)
                // A failed decode does not advance the cursor; consume the element to step past it.
                _ = try? list.decode(DiscardedElement.self)
            }
        }
        return items
    }
}

private struct DiscardedElement: Decodable {
    init(from decoder: Decoder) throws {}
}
