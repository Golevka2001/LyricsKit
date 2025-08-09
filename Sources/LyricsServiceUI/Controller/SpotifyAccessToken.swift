import Foundation

struct SpotifyAccessToken: Codable {
    let accessToken: String
    let accessTokenExpirationTimestampMs: TimeInterval
    let isAnonymous: Bool

    var expirationDate: Date {
        return Date(timeIntervalSince1970: accessTokenExpirationTimestampMs / 1000)
    }

    static func searchAccessToken(forCookie cookie: String) async throws -> Self {
        try await accessToken(forCookie: cookie, reason: "init", productType: "mobile-web-player")
    }

    static func lyricsAccessToken(forCookie cookie: String) async throws -> Self {
        try await accessToken(forCookie: cookie, reason: "transport", productType: "web-player")
    }

    private static func accessToken(forCookie cookie: String, reason: String, productType: String) async throws -> Self {
        struct ServerTime: Codable {
            var serverTime: Int
        }
        struct SecretKeyEntry: Codable {
            let version: Int
            let secret: String
        }
        enum Error: Swift.Error {
            case totpGenerationFailed
        }
        let secretKeyURL = URL(string: "https://raw.githubusercontent.com/Thereallo1026/spotify-secrets/refs/heads/main/secrets/secrets.json")!
        let serverTimeRequest = URLRequest(url: .init(string: "https://open.spotify.com/api/server-time")!)
        let serverTimeData = try await URLSession.shared.data(for: serverTimeRequest).0
        let serverTime = try JSONDecoder().decode(ServerTime.self, from: serverTimeData).serverTime
        let (data, _) = try await URLSession.shared.data(from: secretKeyURL)
        let secretEntries = try JSONDecoder().decode([SecretKeyEntry].self, from: data)
        guard let lastEntry = secretEntries.last else {
            throw Error.totpGenerationFailed
        }
        guard let totp = TOTPGenerator.generate(secretCipher: .init(lastEntry.secret.utf8), serverTimeSeconds: serverTime) else {
            throw Error.totpGenerationFailed
        }
        let tokenURL = URL(string: "https://open.spotify.com/api/token")!
        let params: [String: String] = [
            "reason": reason,
            "productType": productType,
            "totp": totp,
            "totpVer": lastEntry.version.description,
            "ts": String(Int(Date().timeIntervalSince1970)),
        ]
        var components = URLComponents(url: tokenURL, resolvingAgainstBaseURL: false)!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("sp_dc=\(cookie)", forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        let accessTokenData = try await URLSession.shared.data(for: request).0
        try print(JSONSerialization.jsonObject(with: accessTokenData))
        return try JSONDecoder().decode(SpotifyAccessToken.self, from: accessTokenData)
    }
}
