import Foundation

struct ReviewLogger { func info(_: String) {} }
let logger = ReviewLogger()

extension KeyedEncodingContainer {
    mutating func encode(_ key: KeyedEncodingContainer<K>.Key, _ value: some Encodable) throws {
        try encode(value, forKey: key)
    }
}

extension KeyedDecodingContainer {
    func decode<T: Decodable>(_ key: KeyedDecodingContainer<K>.Key,
                              _ type: T.Type,
                              _ defaultValue: @autoclosure () -> T) -> T
    {
        (try? decode(type, forKey: key)) ?? defaultValue()
    }
}
