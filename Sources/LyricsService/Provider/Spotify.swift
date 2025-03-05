import Regex
import CXShim
import Foundation
import LyricsCore
import CXExtensions

struct SpotifySearchResponse: Codable {
    struct Track: Codable {
        struct Item: Codable {
            struct Album: Codable {
                struct Artist: Codable {
                    struct ExternalURL: Codable {
                        let spotify: URL
                    }

                    let externalUrls: ExternalURL
                    let href: URL
                    let id: String
                    let name: String
                    let type: String
                    let uri: String

                    private enum CodingKeys: String, CodingKey {
                        case externalUrls = "external_urls"
                        case href
                        case id
                        case name
                        case type
                        case uri
                    }
                }

                struct ExternalURL: Codable {
                    let spotify: URL
                }

                struct Image: Codable {
                    let height: Int
                    let width: Int
                    let url: URL
                }

                let albumType: String
                let artists: [Artist]
                let availableMarkets: [String]
                let externalUrls: ExternalURL
                let href: URL
                let id: String
                let images: [Image]
                let isPlayable: Bool
                let name: String
                let releaseDate: String
                let releaseDatePrecision: String
                let totalTracks: Int
                let type: String
                let uri: String

                private enum CodingKeys: String, CodingKey {
                    case albumType = "album_type"
                    case artists
                    case availableMarkets = "available_markets"
                    case externalUrls = "external_urls"
                    case href
                    case id
                    case images
                    case isPlayable = "is_playable"
                    case name
                    case releaseDate = "release_date"
                    case releaseDatePrecision = "release_date_precision"
                    case totalTracks = "total_tracks"
                    case type
                    case uri
                }
            }

            struct Artist: Codable {
                struct ExternalURL: Codable {
                    let spotify: URL
                }

                let externalUrls: ExternalURL
                let href: URL
                let id: String
                let name: String
                let type: String
                let uri: String

                private enum CodingKeys: String, CodingKey {
                    case externalUrls = "external_urls"
                    case href
                    case id
                    case name
                    case type
                    case uri
                }
            }

            struct ExternalID: Codable {
                let isrc: String
            }

            struct ExternalURL: Codable {
                let spotify: URL
            }

            let album: Album
            let artists: [Artist]
            let availableMarkets: [String]
            let discNumber: Int
            let durationMs: Int
            let explicit: Bool
            let externalIds: ExternalID
            let externalUrls: ExternalURL
            let href: URL
            let id: String
            let isLocal: Bool
            let isPlayable: Bool
            let name: String
            let popularity: Int
            let previewURL: URL
            let trackNumber: Int
            let type: String
            let uri: String

            private enum CodingKeys: String, CodingKey {
                case album
                case artists
                case availableMarkets = "available_markets"
                case discNumber = "disc_number"
                case durationMs = "duration_ms"
                case explicit
                case externalIds = "external_ids"
                case externalUrls = "external_urls"
                case href
                case id
                case isLocal = "is_local"
                case isPlayable = "is_playable"
                case name
                case popularity
                case previewURL = "preview_url"
                case trackNumber = "track_number"
                case type
                case uri
            }
        }

        let href: URL
        let limit: Int
        let offset: Int
        let total: Int
        let items: [Item]
    }

    let tracks: Track
}

struct SpotifyLyricsResponse: Codable {
    struct Lyric: Codable {
        struct Line: Codable {
            let startTimeMs: String
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
        typealias LyricsToken = SpotifySearchResponse.Track.Item

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
            url = URL(string: "https://api.spotify.com/v1/search?q=track:\(string)&type=track&limit=10")!
        case let .info(title, artist):
            url = URL(string: "https://api.spotify.com/v1/search?q=track:\(title) artist:\(artist)&type=track&limit=10")!
        }

        var req = URLRequest(url: url)
        req.addValue("WebPlayer", forHTTPHeaderField: "app-platform")
        req.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
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
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        return Self.fakeSpotifyUserAgentSession.cx.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: SpotifyLyricsResponse.self, decoder: JSONDecoder().cx)
            .map {
                let lyrics = Lyrics(lines: $0.lyrics.lines.map {
                    LyricsLine(content: $0.words, position: (Double($0.startTimeMs) ?? 0) / 1000)
                }, idTags: [:])
                lyrics.idTags[.title] = token.name
                lyrics.idTags[.artist] = token.artists.map(\.name).joined(separator: ", ")
                lyrics.idTags[.album] = token.album.name
                lyrics.length = Double(token.durationMs) / 1000
                lyrics.metadata.artworkURL = token.album.images.first?.url
                lyrics.metadata.serviceToken = token.id
                return lyrics
            }
//            .ignoreError()
            .catch { error in
                print(error)
                return Empty<Lyrics, Never>()
            }
            .eraseToAnyPublisher()
    }
}
