import XCTest
@testable import SwiftMsgpack

final class DecodeTests: XCTestCase {
    let decoder: MsgPackDecoder = .init()
    private func t<X: Decodable & Equatable>(in input: String, type: X.Type, out: X) throws {
        let actual = try decoder.decode(type, from: Data(hex: input))
        XCTAssertEqual(actual, out)
    }

    func testDecode() throws {
        do {
            try t(in: "01", type: UInt8.self, out: 0x01)
            try t(in: "59", type: UInt16.self, out: 0x59)
            try t(in: "7f", type: UInt32.self, out: 0x7F)
            try t(in: "7f", type: UInt64.self, out: 0x7F)
            try t(in: "7f", type: UInt.self, out: 0x7F)
            try t(in: "01", type: Int8.self, out: 0x01)
            try t(in: "59", type: Int16.self, out: 0x59)
            try t(in: "7f", type: Int32.self, out: 0x7F)
            try t(in: "7f", type: Int64.self, out: 0x7F)
            try t(in: "7f", type: Int.self, out: 0x7F)
            try t(in: "82a15812a15934", type: Pair.self, out: Pair(X: 0x12, Y: 0x34))
            try t(in: "82a15812a15934", type: [String: UInt8].self, out: ["X": 0x12, "Y": 0x34])
            try t(in: "93123456", type: [UInt8].self, out: [0x12, 0x34, 0x56])
            try t(in: "921234", type: PairArray.self, out: PairArray(X: 0x12, Y: 0x34))
            try t(in: "93a3616263a378797aa3646464", type: [String].self, out: ["abc", "xyz", "ddd"])
            try t(in: "c0", type: [String]?.self, out: nil)
            try t(in: "c0", type: Int?.self, out: nil)
            try t(in: "c2", type: Bool.self, out: false)
            try t(in: "c3", type: Bool.self, out: true)
            try t(in: "c403123456", type: Data.self, out: Data([0x12, 0x34, 0x56]))
            try t(in: "c50003123456", type: Data.self, out: Data([0x12, 0x34, 0x56]))
            try t(in: "c600000003123456", type: Data.self, out: Data([0x12, 0x34, 0x56]))
            try t(in: "ca4015c28f", type: Float.self, out: 2.34)
            try t(in: "cb4002b851eb851eb8", type: Double.self, out: 2.34)
            try t(in: "cc80", type: UInt8.self, out: 0x80)
            try t(in: "cd4b6b", type: UInt16.self, out: 0x4B6B)
            try t(in: "ce004b6b34", type: UInt32.self, out: 0x4B6B34)
            try t(in: "cf0000004b6b34abcc", type: UInt64.self, out: 0x4B_6B34_ABCC)
            try t(in: "cf0000004b6b34abcc", type: UInt.self, out: 0x4B_6B34_ABCC)
            try t(in: "d081", type: Int8.self, out: -0x7F)
            try t(in: "d1b495", type: Int16.self, out: -0x4B6B)
            try t(in: "d2ffb494cc", type: Int32.self, out: -0x4B6B34)
            try t(in: "d3ffffffb494cb5434", type: Int64.self, out: -0x4B_6B34_ABCC)
            try t(in: "d3ffffffb494cb5434", type: Int.self, out: -0x4B_6B34_ABCC)
            try t(in: "d90548656c6c6f", type: String.self, out: "Hello")
            try t(in: "da000548656c6c6f", type: String.self, out: "Hello")
            try t(in: "db0000000548656c6c6f", type: String.self, out: "Hello")
            try t(in: "a548656c6c6f", type: String.self, out: "Hello")
            try t(in: "dc00021234", type: PairArray.self, out: PairArray(X: 0x12, Y: 0x34))
            try t(in: "dc0003a3616263a378797aa3646464", type: [String].self, out: ["abc", "xyz", "ddd"])
            try t(in: "dd00000003a3616263a378797aa3646464", type: [String].self, out: ["abc", "xyz", "ddd"])
            try t(in: "de0002a15812a15934", type: Pair.self, out: Pair(X: 0x12, Y: 0x34))
            try t(in: "de0002a15812a15934", type: [String: UInt8].self, out: ["X": 0x12, "Y": 0x34])
            try t(in: "df00000002a15812a15934", type: Pair.self, out: Pair(X: 0x12, Y: 0x34))
            try t(in: "df00000002a15812a15934", type: [String: UInt8].self, out: ["X": 0x12, "Y": 0x34])
            try t(in: "e0", type: Int8.self, out: -0x20)
            try t(in: "e0", type: Int16.self, out: -0x20)
            try t(in: "e0", type: Int32.self, out: -0x20)
            try t(in: "e0", type: Int64.self, out: -0x20)
            try t(in: "e0", type: Int.self, out: -0x20)
            // UnkeyedDecodingContainer
            try t(in: "dc0003a3616263a378797aa3646464", type: SS.self, out: SS(a: ["abc", "xyz", "ddd"]))
            try t(in: "921234", type: UIS.self, out: UIS(a: [0x12, 0x34]))
            try t(in: "92e0e1", type: IS.self, out: IS(a: [-0x20, -0x1F]))
            try t(in: "92ca4015c28fca4048f5c3", type: FS.self, out: FS(a: [2.34, 3.14]))
            try t(in: "92c2c3", type: BS.self, out: BS(a: [false, true]))
            // nestedUnKeyedContainer
            try t(in: "92921234925678", type: UIS2.self, out: UIS2(a: [[0x12, 0x34], [0x56, 0x78]]))
            // nestedContainer
            try t(in: "9282a15812a1593482a15812a15934", type: Pairs.self, out: Pairs(a: [.init(X: 0x12, Y: 0x34), .init(X: 0x12, Y: 0x34)]))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testEncode() throws {
        let encoder = MsgPackEncoder()
        let decoder: MsgPackDecoder = .init()
        let data = try encoder.encode(All.value)
        let actual = try decoder.decode(All.self, from: data)
        XCTAssertEqual(actual, All.value)
    }
}

private extension UnicodeScalar {
    var hexNibble: UInt8 {
        let value = value
        if value >= 48, value <= 57 {
            return UInt8(value - 48)
        } else if value >= 65, value <= 70 {
            return UInt8(value - 55)
        } else if value >= 97, value <= 102 {
            return UInt8(value - 87)
        }
        fatalError("\(self) not a legal hex nibble")
    }
}

private extension Data {
    init(hex: String) {
        let scalars = hex.unicodeScalars
        var bytes = [UInt8](repeating: 0, count: (scalars.count + 1) >> 1)
        for (index, scalar) in scalars.enumerated() {
            var nibble = scalar.hexNibble
            if index & 1 == 0 {
                nibble <<= 4
            }
            bytes[index >> 1] |= nibble
        }
        self = Data(bytes)
    }
}

struct Pair: Codable {
    var X: UInt8
    var Y: UInt8
}

extension Pair: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.X == rhs.X && lhs.Y == rhs.Y
    }
}

struct PairInt: Codable {
    var X: Int8
    var Y: Int8
}

extension PairInt: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.X == rhs.X && lhs.Y == rhs.Y
    }
}

struct PairStr: Codable {
    var X: String
    var Y: String
}

extension PairStr: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.X == rhs.X && lhs.Y == rhs.Y
    }
}

struct PairArray: Codable {
    var X: UInt8
    var Y: UInt8
    init(X: UInt8, Y: UInt8) {
        self.X = X
        self.Y = Y
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        X = try container.decode(UInt8.self)
        Y = try container.decode(UInt8.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(X)
        try container.encode(Y)
    }
}

extension PairArray: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.X == rhs.X && lhs.Y == rhs.Y
    }
}

struct SS: Codable {
    var a: [String]
    init(a: [String]) {
        self.a = a
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for element in a {
            try container.encode(element)
        }
    }

    init(from decoder: Decoder) throws {
        a = []
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            let element = try container.decode(String.self)
            a.append(element)
        }
    }
}

extension SS: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.a == rhs.a
    }
}

private struct UIS: Decodable {
    var a: [UInt8]
    init(a: [UInt8]) {
        self.a = a
    }

    init(from decoder: Decoder) throws {
        a = []
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            let element = try container.decode(UInt8.self)
            a.append(element)
        }
    }
}

extension UIS: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.a == rhs.a
    }
}

struct IS: Codable {
    var a: [Int8]
    init(a: [Int8]) {
        self.a = a
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for element in a {
            try container.encode(element)
        }
    }

    init(from decoder: Decoder) throws {
        a = []
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            let element = try container.decode(Int8.self)
            a.append(element)
        }
    }
}

extension IS: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.a == rhs.a
    }
}

struct FS: Codable {
    var a: [Float]
    init(a: [Float]) {
        self.a = a
    }

    init(from decoder: Decoder) throws {
        a = []
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            let element = try container.decode(Float.self)
            a.append(element)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for element in a {
            try container.encode(element)
        }
    }
}

extension FS: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.a == rhs.a
    }
}

struct BS: Codable {
    var a: [Bool]
    init(a: [Bool]) {
        self.a = a
    }

    init(from decoder: Decoder) throws {
        a = []
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            let element = try container.decode(Bool.self)
            a.append(element)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for element in a {
            try container.encode(element)
        }
    }
}

extension BS: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.a == rhs.a
    }
}

private struct UIS2: Codable {
    var a: [[UInt8]]
    init(a: [[UInt8]]) {
        self.a = a
    }

    init(from decoder: Decoder) throws {
        a = []
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            var b: [UInt8] = []
            var nestedContainer = try container.nestedUnkeyedContainer()
            while !nestedContainer.isAtEnd {
                let element = try nestedContainer.decode(UInt8.self)
                b.append(element)
            }
            a.append(b)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for b in a {
            var nestedContainer = container.nestedUnkeyedContainer()
            for element in b {
                try nestedContainer.encode(element)
            }
        }
    }
}

extension UIS2: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.a == rhs.a
    }
}

private struct Pairs: Decodable {
    var a: [Pair]
    init(a: [Pair]) {
        self.a = a
    }

    struct Pair: Codable, Equatable {
        var X: UInt8
        var Y: UInt8
        enum CodingKeys: CodingKey {
            case X
            case Y
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.X == rhs.X && lhs.Y == rhs.Y
        }
    }

    init(from decoder: Decoder) throws {
        a = []
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            var b: Pair = .init(X: 0, Y: 0)
            let values = try container.nestedContainer(keyedBy: Pair.CodingKeys.self)
            b.X = try values.decode(UInt8.self, forKey: .X)
            b.Y = try values.decode(UInt8.self, forKey: .Y)
            a.append(b)
        }
    }
}

extension Pairs: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.a == rhs.a
    }
}