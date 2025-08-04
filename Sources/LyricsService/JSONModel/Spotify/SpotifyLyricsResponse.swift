import Foundation

struct SpotifyResponseSingleLyrics: Codable {
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
