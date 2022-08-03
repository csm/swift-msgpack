import Foundation

open class MsgPackDecoder {
    public init() {}
    open func decode<T: Decodable>(_: T.Type, from data: Data) throws -> T {
        let scanner: MsgPackScanner = .init(data: data)
        var value: MsgPackValue = .none
        try scanner.parse(&value)
        let decoder: _MsgPackDecoder = .init(from: value)
        return try decoder.unwrap(as: T.self)
    }
}

private class _MsgPackDecoder: Decoder {
    var codingPath: [CodingKey]
    var value: MsgPackValue
    var userInfo: [CodingUserInfoKey: Any] = [:]

    init(from value: MsgPackValue, at codingPath: [CodingKey] = []) {
        self.value = value
        self.codingPath = codingPath
    }

    func container<Key>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        guard case .map = value else {
            throw DecodingError.typeMismatch([MsgPackValue: MsgPackValue].self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected to decode \([MsgPackValue: MsgPackValue].self) but found \(value.debugDataTypeDescription) instead."
            ))
        }
        return KeyedDecodingContainer(MsgPackKeyedDecodingContainer<Key>(referencing: self, container: value))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        switch value {
        case .array: break
        case .none: break
        case .map:
            value = value.asArray()
        default:
            throw DecodingError.typeMismatch([MsgPackValue].self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected to decode \([MsgPackValue].self) but found \(value.debugDataTypeDescription) instead."
            ))
        }

        return MsgPackUnkeyedUnkeyedDecodingContainer(referencing: self, container: value)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        _MsgPackSingleValueDecodingContainer(decoder: self, codingPath: codingPath, value: value)
    }
}

private extension _MsgPackDecoder {
    func unbox(_ value: MsgPackValue, as _: Bool.Type) throws -> Bool? {
        if value == .Nil {
            return nil
        }
        if case let .literal(v) = value {
            guard v.count == 1, let e = v.first else {
                return nil
            }
            if e == 0xC2 {
                return false
            }
            if e == 0xC3 {
                return true
            }
        }
        return nil
    }

    func unbox(_ value: MsgPackValue, as _: String.Type) throws -> String? {
        if value == .Nil {
            return nil
        }
        if case let .literal(v) = value {
            return String(data: v, encoding: .utf8)
        } else {
            return nil
        }
    }

    func unbox(_ value: MsgPackValue, as type: Int.Type) throws -> Int? {
        try unboxInt(value, as: type)
    }

    func unbox(_ value: MsgPackValue, as type: Int8.Type) throws -> Int8? {
        try unboxInt(value, as: type)
    }

    func unbox(_ value: MsgPackValue, as type: Int16.Type) throws -> Int16? {
        try unboxInt(value, as: type)
    }

    func unbox(_ value: MsgPackValue, as type: Int32.Type) throws -> Int32? {
        try unboxInt(value, as: type)
    }

    func unbox(_ value: MsgPackValue, as type: Int64.Type) throws -> Int64? {
        try unboxInt(value, as: type)
    }

    func unbox(_ value: MsgPackValue, as type: UInt.Type) throws -> UInt? {
        try unboxUInt(value, as: type)
    }

    func unbox(_ value: MsgPackValue, as type: UInt8.Type) throws -> UInt8? {
        try unboxUInt(value, as: type)
    }

    func unbox(_ value: MsgPackValue, as type: UInt16.Type) throws -> UInt16? {
        try unboxUInt(value, as: type)
    }

    func unbox(_ value: MsgPackValue, as type: UInt32.Type) throws -> UInt32? {
        try unboxUInt(value, as: type)
    }

    func unbox(_ value: MsgPackValue, as type: UInt64.Type) throws -> UInt64? {
        try unboxUInt(value, as: type)
    }

    func unbox(_ value: MsgPackValue, as type: Float.Type) throws -> Float? {
        try unboxFloat(value, as: type)
    }

    func unbox(_ value: MsgPackValue, as type: Double.Type) throws -> Double? {
        try unboxFloat(value, as: type)
    }

    func unboxFloat<T: BinaryFloatingPoint & DataNumber>(_ value: MsgPackValue, as type: T.Type) throws -> T? {
        if value == .Nil {
            return nil
        }
        if case let .literal(v) = value {
            return try type.init(data: v)
        } else {
            return nil
        }
    }

    func unbox(_ value: MsgPackValue, as _: Data.Type) throws -> Data? {
        if value == .Nil {
            return nil
        }
        if case let .literal(v) = value {
            return v
        } else {
            return nil
        }
    }

    func unboxInt<T: SignedInteger>(_ value: MsgPackValue, as type: T.Type) throws -> T? {
        if value == .Nil {
            return nil
        }
        if case let .literal(v) = value {
            return type.init(try bigEndianInt(v))
        } else {
            return nil
        }
    }

    func unboxUInt<T: UnsignedInteger>(_ value: MsgPackValue, as type: T.Type) throws -> T? {
        if value == .Nil {
            return nil
        }
        if case let .literal(v) = value {
            return try type.init(bigEndianUInt(v))
        } else {
            return nil
        }
    }

    func unbox<T: Decodable>(_ value: MsgPackValue, as type: T.Type) throws -> T? {
        try unbox_(value, as: type) as? T
    }

    func unbox_<T: Decodable>(_ value: MsgPackValue, as type: T.Type) throws -> Any? {
        if type == Data.self || type == NSData.self {
            return try unbox(value, as: Data.self)
        }
        return try T(from: self)
    }
}

extension _MsgPackDecoder {
    func unwrap<T: Decodable>(as type: T.Type) throws -> T {
        if type == Data.self || type == NSData.self {
            return try unwrapData() as! T
        }
        return try T(from: self)
    }

    func unwrapData() throws -> Data {
        guard case let .literal(v) = value else {
            throw DecodingError.typeMismatch(Data.self, DecodingError.Context(codingPath: codingPath, debugDescription: ""))
        }
        return v
    }
}

private struct _MsgPackSingleValueDecodingContainer: SingleValueDecodingContainer {
    let decoder: _MsgPackDecoder
    let codingPath: [CodingKey]
    let value: MsgPackValue

    init(decoder: _MsgPackDecoder, codingPath: [CodingKey], value: MsgPackValue) {
        self.decoder = decoder
        self.codingPath = codingPath
        self.value = value
    }

    func decodeNil() -> Bool {
        value == .Nil
    }

    func decode(_: Bool.Type) throws -> Bool {
        try decoder.unbox(value, as: Bool.self)!
    }

    func decode(_ type: String.Type) throws -> String {
        try decoder.unbox(value, as: type)!
    }

    func decode(_ type: Double.Type) throws -> Double {
        try decoder.unbox(value, as: type)!
    }

    func decode(_ type: Float.Type) throws -> Float {
        try decoder.unbox(value, as: type)!
    }

    func decode(_ type: Int.Type) throws -> Int {
        try decoder.unbox(value, as: type)!
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        try decoder.unbox(value, as: type)!
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        try decoder.unbox(value, as: type)!
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        try decoder.unbox(value, as: type)!
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        try decoder.unbox(value, as: type)!
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        try decoder.unbox(value, as: type)!
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        try decoder.unbox(value, as: type)!
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        try decoder.unbox(value, as: type)!
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        try decoder.unbox(value, as: type)!
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        try decoder.unbox(value, as: type)!
    }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        try decoder.unbox(value, as: type)!
    }
}

private struct MsgPackUnkeyedUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    private let decoder: _MsgPackDecoder
    private(set) var codingPath: [CodingKey]
    public private(set) var currentIndex: Int
    private var container: MsgPackValue

    init(referencing decoder: _MsgPackDecoder, container: MsgPackValue) {
        self.decoder = decoder
        codingPath = decoder.codingPath
        currentIndex = 0
        self.container = container
    }

    var count: Int? {
        container.count
    }

    var isAtEnd: Bool {
        self.currentIndex >= self.count!
    }

    mutating func decodeNil() throws -> Bool {
        let value = try getNextValue(ofType: Never.self)
        if value == .Nil {
            currentIndex += 1
            return true
        }
        return false
    }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        let decoder = try decoderForNextElement(ofType: UnkeyedDecodingContainer.self)
        let container: KeyedDecodingContainer = try decoder.container(keyedBy: type)
        currentIndex += 1
        return container
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let decoder = try decoderForNextElement(ofType: UnkeyedDecodingContainer.self)
        let container: UnkeyedDecodingContainer = try decoder.unkeyedContainer()
        currentIndex += 1
        return container
    }

    mutating func superDecoder() throws -> Decoder {
        let decoder = try decoderForNextElement(ofType: Decoder.self)
        currentIndex += 1
        return decoder
    }

    mutating func decode(_: Bool.Type) throws -> Bool {
        let value = try getNextValue(ofType: String.self)
        currentIndex += 1
        return try decoder.unbox(value, as: Bool.self)!
    }

    mutating func decode(_: String.Type) throws -> String {
        let value = try getNextValue(ofType: String.self)
        currentIndex += 1
        return try decoder.unbox(value, as: String.self)!
    }

    mutating func decode(_: Double.Type) throws -> Double {
        try decodeFloat(as: Double.self)
    }

    mutating func decode(_: Float.Type) throws -> Float {
        try decodeFloat(as: Float.self)
    }

    mutating func decode(_: Int.Type) throws -> Int {
        try decodeInt(as: Int.self)
    }

    mutating func decode(_: Int8.Type) throws -> Int8 {
        try decodeInt(as: Int8.self)
    }

    mutating func decode(_: Int16.Type) throws -> Int16 {
        try decodeInt(as: Int16.self)
    }

    mutating func decode(_: Int32.Type) throws -> Int32 {
        try decodeInt(as: Int32.self)
    }

    mutating func decode(_: Int64.Type) throws -> Int64 {
        try decodeInt(as: Int64.self)
    }

    mutating func decode(_: UInt.Type) throws -> UInt {
        try decodeUInt(as: UInt.self)
    }

    mutating func decode(_: UInt8.Type) throws -> UInt8 {
        try decodeUInt(as: UInt8.self)
    }

    mutating func decode(_: UInt16.Type) throws -> UInt16 {
        try decodeUInt(as: UInt16.self)
    }

    mutating func decode(_: UInt32.Type) throws -> UInt32 {
        try decodeUInt(as: UInt32.self)
    }

    mutating func decode(_: UInt64.Type) throws -> UInt64 {
        try decodeUInt(as: UInt64.self)
    }

    mutating func decode<T>(_: T.Type) throws -> T where T: Decodable {
        let newDecoder: _MsgPackDecoder = try decoderForNextElement(ofType: T.self)
        let result: T = try newDecoder.unwrap(as: T.self)
        currentIndex += 1
        return result
    }

    private mutating func decoderForNextElement<T>(ofType _: T.Type) throws -> _MsgPackDecoder {
        let value = try getNextValue(ofType: T.self)
        let newPath = codingPath + [MsgPackKey(index: currentIndex)]
        return _MsgPackDecoder(from: value, at: newPath)
    }

    @inline(__always)
    private func getNextValue<T>(ofType _: T.Type) throws -> MsgPackValue {
        guard !isAtEnd else {
            let message: String
            if T.self == MsgPackUnkeyedUnkeyedDecodingContainer.self {
                message = "Cannot get nested unkeyed container -- unkeyed container is at end."
            } else if T.self == Decoder.self {
                message = "Cannot get superDecoder() -- unkeyed container is at end."
            } else {
                message = "Unkeyed container is at end."
            }

            var path = codingPath
            path.append(MsgPackKey(index: currentIndex))

            throw DecodingError.valueNotFound(
                T.self,
                .init(codingPath: path,
                      debugDescription: message,
                      underlyingError: nil)
            )
        }
        return container[currentIndex]
    }

    @inline(__always)
    private mutating func decodeUInt<T: UnsignedInteger>(as _: T.Type) throws -> T {
        let value = try getNextValue(ofType: T.self)
        let result = try decoder.unboxUInt(value, as: T.self)!
        currentIndex += 1
        return result
    }

    @inline(__always)
    private mutating func decodeInt<T: SignedInteger>(as _: T.Type) throws -> T {
        let value = try getNextValue(ofType: T.self)
        let result = try decoder.unboxInt(value, as: T.self)!
        currentIndex += 1
        return result
    }

    @inline(__always)
    private mutating func decodeFloat<T: BinaryFloatingPoint & DataNumber>(as _: T.Type) throws -> T {
        let value = try getNextValue(ofType: T.self)
        let result = try decoder.unboxFloat(value, as: T.self)!
        currentIndex += 1
        return result
    }
}

private struct MsgPackKeyedDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K

    private let decoder: _MsgPackDecoder
    private(set) var codingPath: [CodingKey]
    private(set) var allKeys: [Key]
    private var container: MsgPackValue

    init(referencing decoder: _MsgPackDecoder, container: MsgPackValue) {
        self.decoder = decoder
        self.container = container
        allKeys = container.keys.compactMap { Key(stringValue: try! decoder.unbox($0, as: String.self)!) }
        codingPath = decoder.codingPath
    }

    func contains(_ key: Key) -> Bool {
        container[.init(stringLiteral: key.stringValue)] != nil
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        let value = try getValue(forKey: key)
        return value == .Nil
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        let value = try getValue(forKey: key)
        return try decoder.unbox(value, as: type)!
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        let value = try getValue(forKey: key)
        return try decoder.unbox(value, as: type)!
    }

    func decode(_: Double.Type, forKey key: Key) throws -> Double {
        try decodeFloat(key: key)
    }

    func decode(_: Float.Type, forKey key: Key) throws -> Float {
        try decodeFloat(key: key)
    }

    func decode(_: Int.Type, forKey key: Key) throws -> Int {
        try decodeInt(key: key)
    }

    func decode(_: Int8.Type, forKey key: Key) throws -> Int8 {
        try decodeInt(key: key)
    }

    func decode(_: Int16.Type, forKey key: Key) throws -> Int16 {
        try decodeInt(key: key)
    }

    func decode(_: Int32.Type, forKey key: Key) throws -> Int32 {
        try decodeInt(key: key)
    }

    func decode(_: Int64.Type, forKey key: Key) throws -> Int64 {
        try decodeInt(key: key)
    }

    func decode(_: UInt.Type, forKey key: Key) throws -> UInt {
        try decodeUInt(key: key)
    }

    func decode(_: UInt8.Type, forKey key: Key) throws -> UInt8 {
        try decodeUInt(key: key)
    }

    func decode(_: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try decodeUInt(key: key)
    }

    func decode(_: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try decodeUInt(key: key)
    }

    func decode(_: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try decodeUInt(key: key)
    }

    func decode<T>(_: T.Type, forKey key: Key) throws -> T where T: Decodable {
        let newDecoder: _MsgPackDecoder = try decoderForKey(key)
        return try newDecoder.unwrap(as: T.self)
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        try decoderForKey(key).container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        try decoderForKey(key).unkeyedContainer()
    }

    func superDecoder() throws -> Decoder {
        try decoderForKey(MsgPackKey.super)
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        try decoderForKey(key)
    }

    private func decoderForKey<LocalKey: CodingKey>(_ key: LocalKey) throws -> _MsgPackDecoder {
        let value = try getValue(forKey: key)
        let newPath: [CodingKey] = codingPath + [key]
        return _MsgPackDecoder(from: value, at: newPath)
    }

    @inline(__always)
    private func getValue<LocalKey: CodingKey>(forKey key: LocalKey) throws -> MsgPackValue {
        guard let value = container[.init(stringLiteral: key.stringValue)] else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "No value assosiated with key \(key) (\"\(key.stringValue)\"")
            throw DecodingError.keyNotFound(key, context)
        }
        return value
    }

    @inline(__always)
    private func decodeFloat<T: BinaryFloatingPoint & DataNumber>(key: K) throws -> T {
        let value = try getValue(forKey: key)
        return try decoder.unboxFloat(value, as: T.self)!
    }

    @inline(__always)
    private func decodeInt<T: SignedInteger>(key: K) throws -> T {
        let value = try getValue(forKey: key)
        do {
            return try decoder.unboxInt(value, as: T.self)!
        } catch {
            if let error = error as? MsgPackDecodingError {
                throw error.asDecodingError(T.self, codingPath: codingPath)
            }
            throw error
        }
    }

    @inline(__always)
    private func decodeUInt<T: UnsignedInteger>(key: K) throws -> T {
        let value = try getValue(forKey: key)
        do {
            return try decoder.unboxUInt(value, as: T.self)!
        } catch {
            if let error = error as? MsgPackDecodingError {
                throw error.asDecodingError(T.self, codingPath: codingPath)
            }
            throw error
        }
    }
}

internal protocol DataNumber {
    init(data: Data) throws
    var data: Data { get }
}

extension Float: DataNumber {
    init(data: Data) throws {
        self = .init(bitPattern: .init(try bigEndianUInt(data)))
    }

    var data: Data {
        withUnsafePointer(to: bitPattern.bigEndian) {
            Data(buffer: UnsafeBufferPointer(start: $0, count: 1))
        }
    }
}

extension Double: DataNumber {
    init(data: Data) throws {
        self = .init(bitPattern: .init(try bigEndianUInt(data)))
    }

    var data: Data {
        withUnsafePointer(to: bitPattern.bigEndian) {
            Data(buffer: UnsafeBufferPointer(start: $0, count: 1))
        }
    }
}

enum MsgPackDecodingError: Error {
    case dataCorrupted
}

extension MsgPackDecodingError {
    func asDecodingError<T>(_ type: T.Type, codingPath: [CodingKey]) -> DecodingError {
        switch self {
        case .dataCorrupted:
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "Expected to decode \(type) but it failed")
            return DecodingError.dataCorrupted(context)
        }
    }
}