import Foundation
import SwiftOTP

enum TOTPGenerator {
    static func generate(secretCipher: [UInt8], serverTimeSeconds: Int) -> String? {
        var processed = [UInt8]()

        for (i, byte) in secretCipher.enumerated() {
            processed.append(UInt8(byte ^ UInt8(i % 33 + 9)))
        }

        let processedStr = processed.map { String($0) }.joined()

        guard let utf8Bytes = processedStr.data(using: .utf8) else {
            return nil
        }

        let secretBase32 = utf8Bytes.base32EncodedString

        guard let secretData = base32DecodeToData(secretBase32) else {
            return nil
        }

        guard let totp = TOTP(secret: secretData, digits: 6, timeInterval: 30, algorithm: .sha1) else {
            return nil
        }

        return totp.generate(secondsPast1970: serverTimeSeconds)
    }
}
