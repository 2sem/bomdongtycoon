import Foundation
import os

/// Non-fatal diagnostics for saves that decode, but not as written.
enum SaveDiagnostics {
    private static let logger = Logger(subsystem: "com.leesam.bomdongtycoon", category: "save")

    /// Test hook; called with `(key, expected type)` for every present-but-mistyped value.
    nonisolated(unsafe) static var onTypeMismatch: ((_ key: String, _ expected: String) -> Void)?

    private static let scopeKey = "SaveDiagnostics.scopes"

    /// Runs `body` and counts the type mismatches reported on this thread while it runs, so a
    /// caller can tell a clean decode from one that silently substituted defaults. The container
    /// extensions below cannot reach the `Decoder`'s `userInfo`, hence a thread-local stack.
    /// Decoding is synchronous, so the thread is stable for the whole call.
    static func countingMismatches<R>(_ body: () throws -> R) rethrows -> (result: R, mismatches: Int) {
        let dict = Thread.current.threadDictionary
        let stack = (dict[scopeKey] as? NSMutableArray) ?? NSMutableArray()
        dict[scopeKey] = stack
        stack.add(0)
        let depth = stack.count - 1
        defer { stack.removeLastObject() }
        let result = try body()
        return (result, stack[depth] as? Int ?? 0)
    }

    static func typeMismatch(key: String, expected: Any.Type) {
        if let stack = Thread.current.threadDictionary[scopeKey] as? NSMutableArray, stack.count > 0 {
            let top = stack.count - 1
            stack[top] = (stack[top] as? Int ?? 0) + 1
        }
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
        var index = 0
        while !list.isAtEnd {
            defer { index += 1 }
            if let item = try? list.decode(T.self) {
                items.append(item)
            } else {
                SaveDiagnostics.typeMismatch(key: "\(key.stringValue)[\(index)]", expected: T.self)
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
