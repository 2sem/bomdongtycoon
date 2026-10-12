import Foundation

extension KeyedDecodingContainer {
    /// A missing key — or a value of an unexpected type or unknown enum case — yields `fallback`
    /// instead of throwing. Saves are decoded whole, so one throw here discards all progress.
    func decodeOrDefault<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }

    /// Same, for optional properties whose default is `nil`.
    func decodeOrNil<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        (try? decodeIfPresent(type, forKey: key)) ?? nil
    }
}
