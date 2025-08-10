import Foundation

public struct SpotifyResponseSearchResult: Codable {
    public struct Track: Codable {
        public struct Item: Codable {
            public struct Album: Codable {
                public struct Artist: Codable {
                    public struct ExternalURL: Codable {
                        public let spotify: URL
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

                public struct ExternalURL: Codable {
                    public let spotify: URL
                }

                public struct Image: Codable {
                    public let height: Int
                    public let width: Int
                    public let url: URL
                }

                public let albumType: String
                public let artists: [Artist]
                public let availableMarkets: [String]
                public let externalUrls: ExternalURL
                public let href: URL
                public let id: String
                public let images: [Image]
                public let isPlayable: Bool
                public let name: String
                public let releaseDate: String
                public let releaseDatePrecision: String
                public let totalTracks: Int
                public let type: String
                public let uri: String

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

            public struct Artist: Codable {
                public struct ExternalURL: Codable {
                    public let spotify: URL
                }

                public let externalUrls: ExternalURL
                public let href: URL
                public let id: String
                public let name: String
                public let type: String
                public let uri: String

                private enum CodingKeys: String, CodingKey {
                    case externalUrls = "external_urls"
                    case href
                    case id
                    case name
                    case type
                    case uri
                }
            }

            public struct ExternalID: Codable {
                public let isrc: String
            }

            public struct ExternalURL: Codable {
                public let spotify: URL
            }

            public let album: Album
            public let artists: [Artist]
            public let availableMarkets: [String]
            public let discNumber: Int
            public let durationMs: Int
            public let explicit: Bool
            public let externalIds: ExternalID
            public let externalUrls: ExternalURL
            public let href: URL
            public let id: String
            public let isLocal: Bool
            public let isPlayable: Bool
            public let name: String
            public let popularity: Int
            public let previewURL: URL
            public let trackNumber: Int
            public let type: String
            public let uri: String

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

        public let href: URL
        public let limit: Int
        public let offset: Int
        public let total: Int
        public let items: [Item]
    }

    public let tracks: Track
}
