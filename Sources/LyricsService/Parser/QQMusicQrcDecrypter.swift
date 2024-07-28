import Foundation

@available(macOS 10.15, *)
class QrcDecoder {
    static let KEY1 = Array("!@#)(NHLiuy*$%^&".utf8)
    static let KEY2 = Array("123ZXC!@#)(*$%^&".utf8)
    static let KEY3 = Array("!@#)(*$%^&abcDEF".utf8)

    static func des(_ data: inout [UInt8], _ key: [UInt8], _ len: Int) {
        var schedule = [[Int]](repeating: [Int](repeating: 0, count: 6), count: 16)
        QrcDecodeHelper.desKeySetup(key.map { Int($0) }, &schedule, QrcDecodeHelper.ENCRYPT)

        for i in stride(from: 0, to: len, by: 8) {
            var inData = Array(data[i ..< min(i + 8, data.count)]).map { Int($0) }
            QrcDecodeHelper.desCrypt(inData, &inData, schedule)
            for j in 0 ..< inData.count {
                data[i + j] = UInt8(inData[j])
            }
        }
    }

    static func ddes(_ data: inout [UInt8], _ key: [UInt8], _ len: Int) {
        var schedule = [[Int]](repeating: [Int](repeating: 0, count: 6), count: 16)
        QrcDecodeHelper.desKeySetup(key.map { Int($0) }, &schedule, QrcDecodeHelper.DECRYPT)

        for i in stride(from: 0, to: len, by: 8) {
            var inData = Array(data[i ..< min(i + 8, data.count)]).map { Int($0) }
            QrcDecodeHelper.desCrypt(inData, &inData, schedule)
            for j in 0 ..< inData.count {
                data[i + j] = UInt8(inData[j])
            }
        }
    }

    static func decode(_ hex: String) throws -> String {
        var data = [UInt8](hex: hex)
        let dataLen = data.count

        ddes(&data, KEY1, dataLen)
        des(&data, KEY2, dataLen)
        ddes(&data, KEY3, dataLen)
        var byteData = Data(data)
        byteData.removeFirst(2)

        let decompressedData = try (byteData as NSData).decompressed(using: .zlib)
        if let result = String(data: decompressedData as Data, encoding: .utf8) {
            return result
        }
        return ""
    }
}

extension Array where Element == UInt8 {
    fileprivate init(hex: String) {
        self = hex.compactMap { $0.hexDigitValue }.enumerated().reduce(into: [UInt8]()) { result, tuple in
            let (index, value) = tuple
            if index % 2 == 0 {
                result.append(UInt8(value) << 4)
            } else {
                result[index / 2] |= UInt8(value)
            }
        }
    }
}

private func toBoolean(_ val: String) -> Bool? {
    if val.isEmpty { return nil }
    return val == "true" || val == "1"
}

private func getPageSize(total: Int, size: Int, currentTotal: Int? = nil, maxTotal: Int? = nil) -> Int {
    var adjustedTotal = total
    if let maxTotal = maxTotal, total > maxTotal {
        adjustedTotal = maxTotal
    }

    if let currentTotal = currentTotal, size - currentTotal > 10 {
        return 1
    } else {
        let remainder = adjustedTotal % size
        let num = adjustedTotal / size
        return remainder != 0 ? num + 1 : num
    }
}

private func toParamsString(_ params: [String: Any]?) -> String {
    return params?.map { "\($0.key)=\($0.value)" }.joined(separator: "&") ?? ""
}

private func lyricFormat(_ lyric: String) -> String {
    return lyric
        .replacingOccurrences(of: "&#10;", with: "\n")
        .replacingOccurrences(of: "&#13;", with: "\r")
        .replacingOccurrences(of: "&#32;", with: " ")
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "&#40;", with: "(")
        .replacingOccurrences(of: "&#41;", with: ")")
        .replacingOccurrences(of: "&#45;", with: "-")
        .replacingOccurrences(of: "&#46;", with: ".")
        .replacingOccurrences(of: "&#58;", with: ":")
        .replacingOccurrences(of: "&#64;", with: "@")
        .replacingOccurrences(of: "&#95;", with: "_")
        .replacingOccurrences(of: "&#124;", with: "|")
}

private func paramsToMap(_ params: String) -> [String: String] {
    var map: [String: String] = [:]

    for element in params.components(separatedBy: "&") {
        let entity = element.components(separatedBy: "=")
        if entity.count > 1 {
            map[entity[0]] = entity[1]
        } else {
            map[entity[0]] = ""
        }
    }

    return map
}

private func splitList<T>(_ list: [T], _ len: Int) -> [[T]] {
    return stride(from: 0, to: list.count, by: len).map {
        Array(list[$0 ..< min($0 + len, list.count)])
    }
}

private func getRandom(_ length: Int) -> String {
    let ch = "AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz"
    return String((0 ..< length).map { _ in ch.randomElement()! })
}

extension String {
    fileprivate var uint8List: [UInt8] {
        return Array(utf8)
    }

    fileprivate var hexToUint8List: [UInt8] {
        let hexStr = uppercased()
        var bytes = [UInt8]()
        for i in stride(from: 0, to: hexStr.count, by: 2) {
            let index = hexStr.index(hexStr.startIndex, offsetBy: i)
            let byteString = hexStr[index...].prefix(2)
            if let num = UInt8(byteString, radix: 16) {
                bytes.append(num)
            }
        }
        return bytes
    }
}

extension Array where Element == UInt8 {
    fileprivate var hex: String {
        return map { String(format: "%02X", $0) }.joined()
    }

    fileprivate var str: String? {
        return String(bytes: self, encoding: .utf8)
    }
}

private func restoreQrc(_ hexText: String) -> [UInt8]? {
    guard hexText.count % 2 == 0 else { return nil }

    var bytes = [UInt8]()
    for i in stride(from: 0, to: hexText.count, by: 2) {
        let index = hexText.index(hexText.startIndex, offsetBy: i)
        let byteString = hexText[index...].prefix(2)
        if let num = UInt8(byteString, radix: 16) {
            bytes.append(num)
        }
    }

    return bytes
}

private class QrcDecodeHelper {
    static let ENCRYPT = 1
    static let DECRYPT = 0

    static let sbox1: [Int] = [
        14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7,
        0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8,
        4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0,
        15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13,
    ]

    static let sbox2 = [
        15,
        1,
        8,
        14,
        6,
        11,
        3,
        4,
        9,
        7,
        2,
        13,
        12,
        0,
        5,
        10,
        3,
        13,
        4,
        7,
        15,
        2,
        8,
        15,
        12,
        0,
        1,
        10,
        6,
        9,
        11,
        5,
        0,
        14,
        7,
        11,
        10,
        4,
        13,
        1,
        5,
        8,
        12,
        6,
        9,
        3,
        2,
        15,
        13,
        8,
        10,
        1,
        3,
        15,
        4,
        2,
        11,
        6,
        7,
        12,
        0,
        5,
        14,
        9,
    ]

    static let sbox3 = [
        10,
        0,
        9,
        14,
        6,
        3,
        15,
        5,
        1,
        13,
        12,
        7,
        11,
        4,
        2,
        8,
        13,
        7,
        0,
        9,
        3,
        4,
        6,
        10,
        2,
        8,
        5,
        14,
        12,
        11,
        15,
        1,
        13,
        6,
        4,
        9,
        8,
        15,
        3,
        0,
        11,
        1,
        2,
        12,
        5,
        10,
        14,
        7,
        1,
        10,
        13,
        0,
        6,
        9,
        8,
        7,
        4,
        15,
        14,
        3,
        11,
        5,
        2,
        12,
    ]

    static let sbox4 = [
        7,
        13,
        14,
        3,
        0,
        6,
        9,
        10,
        1,
        2,
        8,
        5,
        11,
        12,
        4,
        15,
        13,
        8,
        11,
        5,
        6,
        15,
        0,
        3,
        4,
        7,
        2,
        12,
        1,
        10,
        14,
        9,
        10,
        6,
        9,
        0,
        12,
        11,
        7,
        13,
        15,
        1,
        3,
        14,
        5,
        2,
        8,
        4,
        3,
        15,
        0,
        6,
        10,
        10,
        13,
        8,
        9,
        4,
        5,
        11,
        12,
        7,
        2,
        14,
    ]

    static let sbox5 = [
        2,
        12,
        4,
        1,
        7,
        10,
        11,
        6,
        8,
        5,
        3,
        15,
        13,
        0,
        14,
        9,
        14,
        11,
        2,
        12,
        4,
        7,
        13,
        1,
        5,
        0,
        15,
        10,
        3,
        9,
        8,
        6,
        4,
        2,
        1,
        11,
        10,
        13,
        7,
        8,
        15,
        9,
        12,
        5,
        6,
        3,
        0,
        14,
        11,
        8,
        12,
        7,
        1,
        14,
        2,
        13,
        6,
        15,
        0,
        9,
        10,
        4,
        5,
        3,
    ]
    static let sbox6 = [
        12,
        1,
        10,
        15,
        9,
        2,
        6,
        8,
        0,
        13,
        3,
        4,
        14,
        7,
        5,
        11,
        10,
        15,
        4,
        2,
        7,
        12,
        9,
        5,
        6,
        1,
        13,
        14,
        0,
        11,
        3,
        8,
        9,
        14,
        15,
        5,
        2,
        8,
        12,
        3,
        7,
        0,
        4,
        10,
        1,
        13,
        11,
        6,
        4,
        3,
        2,
        12,
        9,
        5,
        15,
        10,
        11,
        14,
        1,
        7,
        6,
        0,
        8,
        13,
    ]

    static let sbox7 = [
        4,
        11,
        2,
        14,
        15,
        0,
        8,
        13,
        3,
        12,
        9,
        7,
        5,
        10,
        6,
        1,
        13,
        0,
        11,
        7,
        4,
        9,
        1,
        10,
        14,
        3,
        5,
        12,
        2,
        15,
        8,
        6,
        1,
        4,
        11,
        13,
        12,
        3,
        7,
        14,
        10,
        15,
        6,
        8,
        0,
        5,
        9,
        2,
        6,
        11,
        13,
        8,
        1,
        4,
        10,
        7,
        9,
        5,
        0,
        15,
        14,
        2,
        3,
        12,
    ]

    static let sbox8 = [
        13,
        2,
        8,
        4,
        6,
        15,
        11,
        1,
        10,
        9,
        3,
        14,
        5,
        0,
        12,
        7,
        1,
        15,
        13,
        8,
        10,
        3,
        7,
        4,
        12,
        5,
        6,
        11,
        0,
        14,
        9,
        2,
        7,
        11,
        4,
        1,
        9,
        12,
        14,
        2,
        0,
        6,
        10,
        13,
        15,
        3,
        5,
        8,
        2,
        1,
        14,
        7,
        4,
        10,
        8,
        13,
        15,
        12,
        9,
        0,
        3,
        5,
        6,
        11,
    ]

    static func BITNUM(_ a: [Int], _ b: Int, _ c: Int) -> Int {
        return (a[b / 32 * 4 + 3 - b % 32 / 8] >> (7 - b % 8) & 0x01) << c
    }

    static func BITNUMINTR(_ a: Int, _ b: Int, _ c: Int) -> Int {
        return ((a >> (31 - b)) & 0x00000001) << c
    }

    static func BITNUMINTL(_ a: Int, _ b: Int, _ c: Int) -> Int {
        return ((a << b) & 0x80000000) >> c
    }

    static func SBOXBIT(_ a: Int) -> Int {
        return (a & 0x20) | ((a & 0x1F) >> 1) | ((a & 0x01) << 4)
    }

    static func IP(_ state: inout [Int], _ input: [Int]) {
        state[0] = BITNUM(input, 57, 31) |
            BITNUM(input, 49, 30) |
            BITNUM(input, 41, 29) |
            BITNUM(input, 33, 28) |
            BITNUM(input, 25, 27) |
            BITNUM(input, 17, 26) |
            BITNUM(input, 9, 25) |
            BITNUM(input, 1, 24) |
            BITNUM(input, 59, 23) |
            BITNUM(input, 51, 22) |
            BITNUM(input, 43, 21) |
            BITNUM(input, 35, 20) |
            BITNUM(input, 27, 19) |
            BITNUM(input, 19, 18) |
            BITNUM(input, 11, 17) |
            BITNUM(input, 3, 16) |
            BITNUM(input, 61, 15) |
            BITNUM(input, 53, 14) |
            BITNUM(input, 45, 13) |
            BITNUM(input, 37, 12) |
            BITNUM(input, 29, 11) |
            BITNUM(input, 21, 10) |
            BITNUM(input, 13, 9) |
            BITNUM(input, 5, 8) |
            BITNUM(input, 63, 7) |
            BITNUM(input, 55, 6) |
            BITNUM(input, 47, 5) |
            BITNUM(input, 39, 4) |
            BITNUM(input, 31, 3) |
            BITNUM(input, 23, 2) |
            BITNUM(input, 15, 1) |
            BITNUM(input, 7, 0)

        state[1] = BITNUM(input, 56, 31) |
            BITNUM(input, 48, 30) |
            BITNUM(input, 40, 29) |
            BITNUM(input, 32, 28) |
            BITNUM(input, 24, 27) |
            BITNUM(input, 16, 26) |
            BITNUM(input, 8, 25) |
            BITNUM(input, 0, 24) |
            BITNUM(input, 58, 23) |
            BITNUM(input, 50, 22) |
            BITNUM(input, 42, 21) |
            BITNUM(input, 34, 20) |
            BITNUM(input, 26, 19) |
            BITNUM(input, 18, 18) |
            BITNUM(input, 10, 17) |
            BITNUM(input, 2, 16) |
            BITNUM(input, 60, 15) |
            BITNUM(input, 52, 14) |
            BITNUM(input, 44, 13) |
            BITNUM(input, 36, 12) |
            BITNUM(input, 28, 11) |
            BITNUM(input, 20, 10) |
            BITNUM(input, 12, 9) |
            BITNUM(input, 4, 8) |
            BITNUM(input, 62, 7) |
            BITNUM(input, 54, 6) |
            BITNUM(input, 46, 5) |
            BITNUM(input, 38, 4) |
            BITNUM(input, 30, 3) |
            BITNUM(input, 22, 2) |
            BITNUM(input, 14, 1) |
            BITNUM(input, 6, 0)
    }

    static func InvIP(_ state: [Int], _ ina: inout [Int]) {
        ina[3] = (BITNUMINTR(state[1], 7, 7) |
            BITNUMINTR(state[0], 7, 6) |
            BITNUMINTR(state[1], 15, 5) |
            BITNUMINTR(state[0], 15, 4) |
            BITNUMINTR(state[1], 23, 3) |
            BITNUMINTR(state[0], 23, 2) |
            BITNUMINTR(state[1], 31, 1) |
            BITNUMINTR(state[0], 31, 0))

        ina[2] = (BITNUMINTR(state[1], 6, 7) |
            BITNUMINTR(state[0], 6, 6) |
            BITNUMINTR(state[1], 14, 5) |
            BITNUMINTR(state[0], 14, 4) |
            BITNUMINTR(state[1], 22, 3) |
            BITNUMINTR(state[0], 22, 2) |
            BITNUMINTR(state[1], 30, 1) |
            BITNUMINTR(state[0], 30, 0))

        ina[1] = (BITNUMINTR(state[1], 5, 7) |
            BITNUMINTR(state[0], 5, 6) |
            BITNUMINTR(state[1], 13, 5) |
            BITNUMINTR(state[0], 13, 4) |
            BITNUMINTR(state[1], 21, 3) |
            BITNUMINTR(state[0], 21, 2) |
            BITNUMINTR(state[1], 29, 1) |
            BITNUMINTR(state[0], 29, 0))

        ina[0] = (BITNUMINTR(state[1], 4, 7) |
            BITNUMINTR(state[0], 4, 6) |
            BITNUMINTR(state[1], 12, 5) |
            BITNUMINTR(state[0], 12, 4) |
            BITNUMINTR(state[1], 20, 3) |
            BITNUMINTR(state[0], 20, 2) |
            BITNUMINTR(state[1], 28, 1) |
            BITNUMINTR(state[0], 28, 0))

        ina[7] = (BITNUMINTR(state[1], 3, 7) |
            BITNUMINTR(state[0], 3, 6) |
            BITNUMINTR(state[1], 11, 5) |
            BITNUMINTR(state[0], 11, 4) |
            BITNUMINTR(state[1], 19, 3) |
            BITNUMINTR(state[0], 19, 2) |
            BITNUMINTR(state[1], 27, 1) |
            BITNUMINTR(state[0], 27, 0))

        ina[6] = (BITNUMINTR(state[1], 2, 7) |
            BITNUMINTR(state[0], 2, 6) |
            BITNUMINTR(state[1], 10, 5) |
            BITNUMINTR(state[0], 10, 4) |
            BITNUMINTR(state[1], 18, 3) |
            BITNUMINTR(state[0], 18, 2) |
            BITNUMINTR(state[1], 26, 1) |
            BITNUMINTR(state[0], 26, 0))

        ina[5] = (BITNUMINTR(state[1], 1, 7) |
            BITNUMINTR(state[0], 1, 6) |
            BITNUMINTR(state[1], 9, 5) |
            BITNUMINTR(state[0], 9, 4) |
            BITNUMINTR(state[1], 17, 3) |
            BITNUMINTR(state[0], 17, 2) |
            BITNUMINTR(state[1], 25, 1) |
            BITNUMINTR(state[0], 25, 0))

        ina[4] = (BITNUMINTR(state[1], 0, 7) |
            BITNUMINTR(state[0], 0, 6) |
            BITNUMINTR(state[1], 8, 5) |
            BITNUMINTR(state[0], 8, 4) |
            BITNUMINTR(state[1], 16, 3) |
            BITNUMINTR(state[0], 16, 2) |
            BITNUMINTR(state[1], 24, 1) |
            BITNUMINTR(state[0], 24, 0))
    }

    static func f(_ state: Int, _ key: [Int]) -> Int {
        var state = state
        var lrgstate = [Int](repeating: 0, count: 6)
        var t1, t2: Int

        // Expansion Permutation
        t1 = (BITNUMINTL(state, 31, 0) |
            ((state & 0xF0000000) >> 1) |
            BITNUMINTL(state, 4, 5) |
            BITNUMINTL(state, 3, 6) |
            ((state & 0x0F000000) >> 3) |
            BITNUMINTL(state, 8, 11) |
            BITNUMINTL(state, 7, 12) |
            ((state & 0x00F00000) >> 5) |
            BITNUMINTL(state, 12, 17) |
            BITNUMINTL(state, 11, 18) |
            ((state & 0x000F0000) >> 7) |
            BITNUMINTL(state, 16, 23))

        t2 = (BITNUMINTL(state, 15, 0) |
            ((state & 0x0000F000) << 15) |
            BITNUMINTL(state, 20, 5) |
            BITNUMINTL(state, 19, 6) |
            ((state & 0x00000F00) << 13) |
            BITNUMINTL(state, 24, 11) |
            BITNUMINTL(state, 23, 12) |
            ((state & 0x000000F0) << 11) |
            BITNUMINTL(state, 28, 17) |
            BITNUMINTL(state, 27, 18) |
            ((state & 0x0000000F) << 9) |
            BITNUMINTL(state, 0, 23))

        lrgstate[0] = (t1 >> 24) & 0x000000FF
        lrgstate[1] = (t1 >> 16) & 0x000000FF
        lrgstate[2] = (t1 >> 8) & 0x000000FF
        lrgstate[3] = (t2 >> 24) & 0x000000FF
        lrgstate[4] = (t2 >> 16) & 0x000000FF
        lrgstate[5] = (t2 >> 8) & 0x000000FF

        // Key XOR
        for i in 0 ..< 6 {
            lrgstate[i] ^= key[i]
        }

        // S-Box Permutation
        state = (sbox1[SBOXBIT(lrgstate[0] >> 2)] << 28) |
            (sbox2[SBOXBIT(((lrgstate[0] & 0x03) << 4) | (lrgstate[1] >> 4))] << 24) |
            (sbox3[SBOXBIT(((lrgstate[1] & 0x0F) << 2) | (lrgstate[2] >> 6))] << 20) |
            (sbox4[SBOXBIT(lrgstate[2] & 0x3F)] << 16) |
            (sbox5[SBOXBIT(lrgstate[3] >> 2)] << 12) |
            (sbox6[SBOXBIT(((lrgstate[3] & 0x03) << 4) | (lrgstate[4] >> 4))] << 8) |
            (sbox7[SBOXBIT(((lrgstate[4] & 0x0F) << 2) | (lrgstate[5] >> 6))] << 4) |
            sbox8[SBOXBIT(lrgstate[5] & 0x3F)]

        // P-Box Permutation
        state = BITNUMINTL(state, 15, 0) |
            BITNUMINTL(state, 6, 1) |
            BITNUMINTL(state, 19, 2) |
            BITNUMINTL(state, 20, 3) |
            BITNUMINTL(state, 28, 4) |
            BITNUMINTL(state, 11, 5) |
            BITNUMINTL(state, 27, 6) |
            BITNUMINTL(state, 16, 7) |
            BITNUMINTL(state, 0, 8) |
            BITNUMINTL(state, 14, 9) |
            BITNUMINTL(state, 22, 10) |
            BITNUMINTL(state, 25, 11) |
            BITNUMINTL(state, 4, 12) |
            BITNUMINTL(state, 17, 13) |
            BITNUMINTL(state, 30, 14) |
            BITNUMINTL(state, 9, 15) |
            BITNUMINTL(state, 1, 16) |
            BITNUMINTL(state, 7, 17) |
            BITNUMINTL(state, 23, 18) |
            BITNUMINTL(state, 13, 19) |
            BITNUMINTL(state, 31, 20) |
            BITNUMINTL(state, 26, 21) |
            BITNUMINTL(state, 2, 22) |
            BITNUMINTL(state, 8, 23) |
            BITNUMINTL(state, 18, 24) |
            BITNUMINTL(state, 12, 25) |
            BITNUMINTL(state, 29, 26) |
            BITNUMINTL(state, 5, 27) |
            BITNUMINTL(state, 21, 28) |
            BITNUMINTL(state, 10, 29) |
            BITNUMINTL(state, 3, 30) |
            BITNUMINTL(state, 24, 31)

        // Return the final state value

        return state
    }

    static func desKeySetup(_ key: [Int], _ schedule: inout [[Int]], _ mode: Int) {
        var C = 0, D = 0
        let key_rnd_shift = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1]
        let key_perm_c = [56, 48, 40, 32, 24, 16, 8, 0, 57, 49, 41, 33, 25, 17, 9, 1, 58, 50, 42, 34, 26, 18, 10, 2, 59, 51, 43, 35]
        let key_perm_d = [62, 54, 46, 38, 30, 22, 14, 6, 61, 53, 45, 37, 29, 21, 13, 5, 60, 52, 44, 36, 28, 20, 12, 4, 27, 19, 11, 3]
        let key_compression = [
            13, 16, 10, 23, 0, 4, 2, 27, 14, 5, 20, 9, 22, 18, 11, 3,
            25, 7, 15, 6, 26, 19, 12, 1, 40, 51, 30, 36, 46, 54, 29, 39,
            50, 44, 32, 47, 43, 48, 38, 55, 33, 52, 45, 41, 49, 35, 28, 31,
        ]

        // Permutated Choice #1
        for i in 0 ..< 28 {
            C |= BITNUM(key, key_perm_c[i], 31 - i)
            D |= BITNUM(key, key_perm_d[i], 31 - i)
        }

        // Generate the 16 subkeys
        for i in 0 ..< 16 {
            C = ((C << key_rnd_shift[i]) | (C >> (28 - key_rnd_shift[i]))) & 0xFFFFFFF0
            D = ((D << key_rnd_shift[i]) | (D >> (28 - key_rnd_shift[i]))) & 0xFFFFFFF0

            let to_gen = mode == DECRYPT ? 15 - i : i
            schedule[to_gen] = [Int](repeating: 0, count: 6)

            for j in 0 ..< 48 {
                if j < 24 {
                    schedule[to_gen][j / 8] |= BITNUMINTR(C, key_compression[j], 7 - j % 8)
                } else {
                    schedule[to_gen][j / 8] |= BITNUMINTR(D, key_compression[j] - 27, 7 - j % 8)
                }
            }
        }
    }

    static func desCrypt(_ input: [Int], _ output: inout [Int], _ key: [[Int]]) {
        var state = [0, 0]
        IP(&state, input)

        for idx in 0 ..< 15 {
            let t = state[1]
            state[1] = f(state[1], key[idx]) ^ state[0]
            state[0] = t
        }
        state[0] = f(state[1], key[15]) ^ state[0]

        InvIP(state, &output)
    }
}

enum XMLUtils {
    private static let ampRegex = try! NSRegularExpression(pattern: "&(?![a-zA-Z]{2,6};|#[0-9]{2,4};)")

    private static let quotRegex = try! NSRegularExpression(pattern: "(\\s+[\\w:.-]+\\s*=\\s*\")(([^\"]*)((\")((?!\\s+[\\w:.-]+\\s*=\\s*\"|\\s*(?:/?|\\?)>))[^\"]*)*)\"")

    /// 创建 XML DOM
    static func create(content: String) throws -> XMLDocument {
        var modifiedContent = removeIllegalContent(content)
        modifiedContent = replaceAmp(modifiedContent)
        modifiedContent = replaceQuot(modifiedContent)

        return try XMLDocument(xmlString: modifiedContent, options: [])
    }

    private static func replaceAmp(_ content: String) -> String {
        return ampRegex.stringByReplacingMatches(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count), withTemplate: "&amp;")
    }

    private static func replaceQuot(_ content: String) -> String {
        var result = ""
        var currentIndex = content.startIndex

        quotRegex.enumerateMatches(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count)) { match, _, _ in
            guard let match = match else { return }

            let matchRange = Range(match.range, in: content)!
            result += content[currentIndex ..< matchRange.lowerBound]

            let group1 = content[Range(match.range(at: 1), in: content)!]
            let group2 = content[Range(match.range(at: 2), in: content)!].replacingOccurrences(of: "\"", with: "&quot;")
            result += "\(group1)\(group2)\""

            currentIndex = matchRange.upperBound
        }

        result += content[currentIndex...]
        return result
    }

    /// 移除 XML 内容中无效的部分
    private static func removeIllegalContent(_ content: String) -> String {
        var modifiedContent = content
        var i = 0
        var left = 0

        while i < modifiedContent.count {
            let index = modifiedContent.index(modifiedContent.startIndex, offsetBy: i)
            if modifiedContent[index] == "<" {
                left = i
            }

            if i > 0 && modifiedContent[index] == ">" && modifiedContent[modifiedContent.index(before: index)] == "/" {
                let partStartIndex = modifiedContent.index(modifiedContent.startIndex, offsetBy: left)
                let partEndIndex = modifiedContent.index(after: index)
                let part = String(modifiedContent[partStartIndex ..< partEndIndex])

                if part.contains("=") && part.firstIndex(of: "=") == part.lastIndex(of: "=") {
                    let equalIndex = part.firstIndex(of: "=")!
                    let part1 = part[..<equalIndex]
                    if !part1.trimmingCharacters(in: .whitespaces).contains(" ") {
                        modifiedContent.removeSubrange(partStartIndex ..< partEndIndex)
                        i = 0
                        continue
                    }
                }
            }

            i += 1
        }

        return modifiedContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 递归查找 XML DOM
    static func recursionFindElement(xmlNode: XMLNode, mappingDict: [String: String], resDict: inout [String: XMLNode]) {
        if let value = mappingDict[xmlNode.name ?? ""] {
            resDict[value] = xmlNode
        }

        guard let children = xmlNode.children else { return }

        for child in children {
            recursionFindElement(xmlNode: child, mappingDict: mappingDict, resDict: &resDict)
        }
    }
}

func decryptQQMusicQrc(_ data: String) -> String? {
    try? QrcDecoder.decode(data)
}
