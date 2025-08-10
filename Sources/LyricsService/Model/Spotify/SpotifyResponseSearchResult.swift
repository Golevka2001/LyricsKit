import Foundation

struct SpotifyResponseSearchResult: Codable {
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
