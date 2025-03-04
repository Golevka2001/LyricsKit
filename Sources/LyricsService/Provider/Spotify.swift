import Regex
import CXShim
import Foundation
import LyricsCore
import CXExtensions

struct SpotifyAccessToken: Codable {
    let accessToken: String
    let accessTokenExpirationTimestampMs: TimeInterval
    let isAnonymous: Bool
}

struct SpotifySearchResponse: Codable {
    struct Tracks: Codable {
        struct Item: Codable {
            let type: String
            let id: String
        }

        let items: [Item]
    }

    let tracks: Tracks
}

struct SpotifyLyricsResponse: Codable {
    struct Lyric: Codable {
        struct Line: Codable {
            let startTimeMs: TimeInterval
            let words: String
            let endTimeMs: String
        }

        let syncType: String
        let lines: [Line]
        let provider: String
        let providerLyricsID: String
        let providerDisplayName: String
        let syncLyricsUri: String
        let isDenseTypeface: Bool
        let language: String
        let isRtlLanguage: Bool
        let capStatus: String
        let isSnippet: Bool

        private enum CodingKeys: String, CodingKey {
            case syncType
            case lines
            case provider
            case providerLyricsID = "providerLyricsId"
            case providerDisplayName
            case syncLyricsUri
            case isDenseTypeface
            case language
            case isRtlLanguage
            case capStatus
            case isSnippet
        }
    }

    struct Color: Codable {
        let background: Int
        let text: Int
        let highlightText: Int
    }

    let lyrics: Lyric
    let colors: Color
    let hasVocalRemoval: Bool
}

extension LyricsProviders {
    final class Spotify: _LyricsProvider {
        typealias LyricsToken = SpotifySearchResponse.Tracks.Item

        let accessToken: String
        
        init(accessToken: String) {
            self.accessToken = accessToken
        }

        static let fakeSpotifyUserAgentconfig: URLSessionConfiguration = {
            let fakeSpotifyUserAgentconfig = URLSessionConfiguration.default
            fakeSpotifyUserAgentconfig.httpAdditionalHeaders = ["User-Agent": "Spotify/121000760 Win32/0 (PC laptop)"]
            return fakeSpotifyUserAgentconfig
        }()

        static let fakeSpotifyUserAgentSession: URLSession = .init(configuration: fakeSpotifyUserAgentconfig)
    }
}

extension LyricsProviders.Spotify {
    static let service: String? = "Spotify"

    func lyricsSearchPublisher(request: LyricsSearchRequest) -> AnyPublisher<LyricsToken, Never> {
        let url: URL
        switch request.searchTerm {
        case let .keyword(string):
            url = URL(string: "https://api.spotify.com/v1/search?q=track:\(string)+&type=track&limit=10")!
        case let .info(title, artist):
            url = URL(string: "https://api.spotify.com/v1/search?q=track:\(title)+artist:\(artist)+&type=track&limit=10")!
        }

        var req = URLRequest(url: url)
        req.addValue("WebPlayer", forHTTPHeaderField: "app-platform")
        req.addValue("Bearer \(accessToken)", forHTTPHeaderField: "authorization")
        return sharedURLSession.cx.dataTaskPublisher(for: req)
            .map(\.data)
            .decode(type: SpotifySearchResponse.self, decoder: JSONDecoder().cx)
            .map(\.tracks.items)
            .replaceError(with: [])
            .flatMap(Publishers.Sequence.init)
            .map { $0 as LyricsToken }
            .eraseToAnyPublisher()
    }

    func lyricsFetchPublisher(token: LyricsToken) -> AnyPublisher<Lyrics, Never> {
        let url = URL(string: "https://spclient.wg.spotify.com/color-lyrics/v2/track/\(token.id)?format=json&vocalRemoval=false")!
        var request = URLRequest(url: url)
        request.addValue("WebPlayer", forHTTPHeaderField: "app-platform")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "authorization")

        return Self.fakeSpotifyUserAgentSession.cx.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: SpotifyLyricsResponse.self, decoder: JSONDecoder().cx)
            .map { Lyrics(lines: $0.lyrics.lines.map { LyricsLine(content: $0.words, position: $0.startTimeMs / 1000) }, idTags: [:]) }
            .ignoreError()
            .eraseToAnyPublisher()
    }
}
