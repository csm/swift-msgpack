import Foundation

indirect enum MsgPackValue {
    case none
    case literal(Data)
    case array([MsgPackValue])
    case map([MsgPackValue], [MsgPackValue: MsgPackValue])
    static let Nil = literal(.init([0xC0]))
}

extension MsgPackValue {
    var count: Int {
        switch self {
        case .none:
            return 0
        case .literal:
            return 1
        case let .array(a):
            return a.count
        case let .map(keys, _):
            return keys.count
        }
    }

    func asArray() -> MsgPackValue {
        switch self {
        case .none:
            return .array([])
        case .literal:
            return .array([self])
        case .array:
            return self
        case let .map(keys, map):
            var a: [MsgPackValue] = []
            for key in keys {
                if let value = map[key] {
                    a.append(key)
                    a.append(value)
                }
            }
            return .array(a)
        }
    }

    func asMap() -> MsgPackValue {
        switch self {
        case .none:
            return .map([], [:])
        case .literal:
            return .map([], [:])
        case let .array(a):
            if a.count % 2 != 0 {
                return .map([], [:])
            }
            var keys: [MsgPackValue] = []
            var m: [MsgPackValue: MsgPackValue] = [:]
            let n = a.count / 2
            m.reserveCapacity(n)
            keys.reserveCapacity(n)
            for i in 0 ..< n {
                let key = a[i * 2]
                keys.append(key)
                m[key] = a[i * 2 + 1]
            }
            return .map(keys, m)
        case .map:
            return self
        }
    }

    subscript(index: Int) -> MsgPackValue {
        switch self {
        case .none:
            return .none
        case .literal:
            return .none
        case let .array(a):
            return a[index]
        case let .map(keys, map):
            return map[keys[index]]!
        }
    }

    subscript(key: MsgPackValue) -> MsgPackValue? {
        if case let .map(_, m) = self {
            return m[key]
        } else {
            return nil
        }
    }

    var keys: Dictionary<MsgPackValue, MsgPackValue>.Keys {
        if case let .map(_, m) = self {
            return m.keys
        } else {
            return [:].keys
        }
    }
}

extension MsgPackValue: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self = .literal(Data(value.utf8))
    }
}

extension MsgPackValue {
    var debugDataTypeDescription: String {
        switch self {
        case .none:
            return "none"
        case .literal:
            return "a literal"
        case .array:
            return "an array"
        case .map:
            return "a map"
        }
    }
}

extension MsgPackValue: Hashable {
    static func == (lhs: MsgPackValue, rhs: MsgPackValue) -> Bool {
        switch (lhs, rhs) {
        case let (.literal(l), .literal(r)):
            return l == r
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case let .literal(data):
            hasher.combine(0x1)
            hasher.combine(data)
        case let .array(array):
            hasher.combine(0x2)
            hasher.combine(array)
        case let .map(_, map):
            hasher.combine(0x3)
            hasher.combine(map)
        case .none:
            break
        }
    }
}

extension MsgPackValue {
    struct Writer {
        func writeValue(_ value: MsgPackValue) -> [UInt8] {
            var bytes: [UInt8] = .init()
            writeValue(value, into: &bytes)
            return bytes
        }

        private func writeValue(_ value: MsgPackValue, into bytes: inout [UInt8]) {
            switch value {
            case let .literal(data):
                let bs: [UInt8] = data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> [UInt8] in
                    let unsafeBufferPointer = pointer.bindMemory(to: UInt8.self)
                    let unsafePointer = unsafeBufferPointer.baseAddress!
                    return [UInt8](UnsafeBufferPointer(start: unsafePointer, count: data.count))
                }
                bytes.append(contentsOf: bs)
            case let .array(array):
                let n = array.count
                if n <= UInt.maxUint4 {
                    bytes.append(contentsOf: [UInt8(0x90 + n)])
                } else if n <= UInt16.max {
                    var bb: [UInt8] = []
                    bb.append(0xDC)
                    let bits = withUnsafePointer(to: UInt16(n).bigEndian) {
                        Data(buffer: UnsafeBufferPointer(start: $0, count: 1))
                    }
                    bb.append(contentsOf: bits)
                    bytes.append(contentsOf: bb)
                } else {
                    var bb: [UInt8] = []
                    bb.append(0xDD)
                    let bits = withUnsafePointer(to: UInt32(n).bigEndian) {
                        Data(buffer: UnsafeBufferPointer(start: $0, count: 1))
                    }
                    bb.append(contentsOf: bits)
                    bytes.append(contentsOf: bb)
                }
                for item in array {
                    writeValue(item, into: &bytes)
                }
            case let .map(keys, map):
                let n = keys.count
                if n <= UInt.maxUint4 {
                    bytes.append(contentsOf: [UInt8(0x80 + n)])
                } else if n <= UInt16.max {
                    var bb: [UInt8] = []
                    bb.append(0xDE)
                    let bits = withUnsafePointer(to: UInt16(n).bigEndian) {
                        Data(buffer: UnsafeBufferPointer(start: $0, count: 1))
                    }
                    bb.append(contentsOf: bits)
                    bytes.append(contentsOf: bb)
                } else {
                    var bb: [UInt8] = []
                    bb.append(0xDF)
                    let bits = withUnsafePointer(to: UInt32(n).bigEndian) {
                        Data(buffer: UnsafeBufferPointer(start: $0, count: 1))
                    }
                    bb.append(contentsOf: bits)
                    bytes.append(contentsOf: bb)
                }

                for key in keys {
                    if let value = map[key] {
                        writeValue(key, into: &bytes)
                        writeValue(value, into: &bytes)
                    }
                }
            default:
                bytes.append(contentsOf: [])
            }
        }
    }
}

enum MsgPackOpCode {
    case begin
    case literal
    case array
    case map
    case neverUsed
    case end
}

class MsgPackScanner {
    private let data: Data
    private var off = 0
    private var opcode: MsgPackOpCode = .begin
    init(data: Data) {
        self.data = data
        off = 0
    }

    func parse(_ v: inout MsgPackValue) throws {
        scanNext()
        try value(&v)
    }

    private func rescanLiteral() throws {
        var i = off
        let c = data[i - 1]
        switch c {
        case 0xC0, 0xC2, 0xC3: // nil, false, true
            break
        case 0xC4, 0xC5, 0xC6: // bin 8, bin 16, bin 32
            let nn = 1 << (c - 0xC4)
            let dd = data[i ..< i + nn]
            i += try bigEndianInt(dd) + nn
        case 0xCA, 0xCB: // Float, Double
            i += 4 << (c - 0xCA)
        case 0xCC, 0xCD, 0xCE, 0xCF: // uint8, uint16, uint32, uint64
            i += 1 << (c - 0xCC)
        case 0xD0, 0xD1, 0xD2, 0xD3: // int8, int16, int32, int64
            i += 1 << (c - 0xD0)
        case 0xD9, 0xDA, 0xDB: // str8, str16, str32
            let nn = 1 << (c - 0xD9)
            let dd = data[i ..< i + nn]
            i += try bigEndianInt(dd) + nn
        default:
            if c & 0xE0 == 0xE0 { // negative fixint
                break
            }
            if c & 0xA0 == 0xA0 { // fixstr
                i += Int(c - 0xA0)
            }
        }
        off = i + 1
    }

    private func value(_ v: inout MsgPackValue) throws {
        let opcode = opcode
        switch opcode {
        case .begin:
            break
        case .literal:
            let start = readIndex()
            try rescanLiteral()
            literal(data[start ..< readIndex()], &v)
        case .array:
            try array(&v)
        case .map:
            try map(&v)
        case .neverUsed:
            break
        case .end:
            break
        }
    }

    private func literal(_ item: Data, _ v: inout MsgPackValue) {
        let c = item.first!
        switch c {
        case 0xC0, 0xC2, 0xC3: // nil, false, true
            v = .literal(item)
        case 0xC4, 0xC5, 0xC6: // bin8, bin16, bin32
            v = .literal(item.dropFirst(1 + (1 << (c - 0xC4))))
        case 0xCA, 0xCB:
            v = .literal(item.dropFirst(1))
        case 0xCC, 0xCD, 0xCE, 0xCF: // uint8, uint16, uint32, uint64
            v = .literal(item.dropFirst(1))
            return
        case 0xD0, 0xD1, 0xD2, 0xD3: // int8, int16, int32, int64
            v = .literal(item.dropFirst(1))
            return
        case 0xD9, 0xDA, 0xDB: // str8, str16, str32
            v = .literal(item.dropFirst(1 + (1 << (c - 0xD9))))
        default:
            if item.count == 1, c & 0xE0 == 0xE0 { // negative fixint
                v = .literal(item)
                return
            }
            if c & 0xA0 == 0xA0 { // fixstr
                v = .literal(item.dropFirst(1))
                return
            }
            if item.count == 1, c & 0x80 == 0 { // fixint
                v = .literal(item)
                return
            }
        }
    }

    private func array(_ v: inout MsgPackValue) throws {
        let c = data[off - 1]
        let n: Int = try { () -> Int in
            switch c {
            case 0xDC, 0xDD: // array 16, array 32
                let nn = 1 << (c - 0xDB)
                let dd = self.data[self.off ..< self.off + nn]
                self.off += nn
                return try Int(bigEndianUInt(dd))
            default:
                if c & 0x90 == 0x90 {
                    return Int(c - 0x90)
                }
                return 0
            }
        }()
        scanNext()
        var a: [MsgPackValue] = []
        for _ in 0 ..< n {
            var ch: MsgPackValue = .none
            try value(&ch)
            scanCurrent()
            a.append(ch)
        }
        v = .array(a)
    }

    private func map(_ v: inout MsgPackValue) throws {
        let c = data[off - 1]
        let n: Int = try { () -> Int in
            switch c {
            case 0xDE, 0xDF: // map 16, map 32
                let nn = 1 << (c - 0xDD)
                let dd = self.data[self.off ..< self.off + nn]
                self.off += nn
                return try Int(bigEndianUInt(dd))
            default:
                if c & 0x80 == 0x80 { // fixmap
                    return Int(c - 0x80)
                }
                return 0
            }
        }()
        scanNext()
        var keys: [MsgPackValue] = []
        var m: [MsgPackValue: MsgPackValue] = [:]
        for _ in 0 ..< n {
            var key: MsgPackValue = .none
            var val: MsgPackValue = .none
            scanCurrent()
            try value(&key)
            scanCurrent()
            try value(&val)
            m[key] = val
            keys.append(key)
        }
        v = .map(keys, m)
    }

    private func readIndex() -> Int {
        off - 1
    }

    private func scanNext() {
        if off < data.count {
            opcode = Self.step(data[off])
            off += 1
        } else {
            opcode = .end
            off = data.count + 1
        }
    }

    private func scanCurrent() {
        if off > 0, off < data.count {
            opcode = Self.step(data[off - 1])
        }
    }

    private static func step(_ c: UInt8) -> MsgPackOpCode {
        if c <= 0xBF || c >= 0xE0 {
            if c & 0xE0 == 0xE0 { // negative fixint
                return .literal
            }
            if c & 0xA0 == 0xA0 { // fixstr
                return .literal
            }
            if c & 0x90 == 0x90 { // fixarray
                return .array
            }
            if c & 0x80 == 0x80 { // fixmap
                return .map
            }
            if c & 0x80 == 0 { // positive fixint
                return .literal
            }
            return .neverUsed
        }

        switch c {
        case 0xC1: // never used
            return .neverUsed
        case 0xDC, 0xDD: // array 16, array 32
            return .array
        case 0xDE, 0xDF: // map 16, map 32
            return .map
        default:
            return .literal
        }
    }

    subscript(_: Int) -> Data {
        Data()
    }
}

private extension Data {
    var hexDescription: String {
        reduce("") { $0 + String(format: "%02x", $1) }
    }
}