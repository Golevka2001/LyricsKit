import Foundation

extension LyricsProviders {
    public enum Service {
        case qq
        case netease
        case kugou
        case lrclib
        case spotify(searchAccessToken: String, lyricsAccessToken: String)

        public var displayName: String {
            switch self {
            case .netease: return "Netease"
            case .qq: return "QQMusic"
            case .kugou: return "Kugou"
            case .lrclib: return "LRCLIB"
            case .spotify: return "Spotify"
            }
        }

        public static var noAuthenticationRequiredServices: [Service] {
            [
                .qq,
                .netease,
                .kugou,
                .lrclib,
            ]
        }
    }
}

extension LyricsProviders.Service {
    func create() -> LyricsProvider {
        switch self {
        case .netease: return LyricsProviders.NetEase()
        case .qq: return LyricsProviders.QQMusic()
        case .kugou: return LyricsProviders.Kugou()
        case .spotify(let searchAccessToken, let lyricsAccessToken): return LyricsProviders.Spotify(searchAccessToken: searchAccessToken, lyricsAccessToken: lyricsAccessToken)
        case .lrclib: return LyricsProviders.LRCLIB()
//        default:        return LyricsProviders.Unsupported()
        }
    }
}
