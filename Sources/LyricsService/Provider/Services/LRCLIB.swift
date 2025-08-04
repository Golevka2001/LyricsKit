import Foundation
import LyricsCore
import CXShim
import CXExtensions
import Regex

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// https://lrclib.net/api/search

extension LyricsProviders {
    public final class LRCLIB {
        public init() {}
    }
}

extension LyricsProviders.LRCLIB: _LyricsProvider {
    public typealias LyricsToken = LRCLIBResponse

    public static let service: String? = "LRCLIB"

    public func lyricsSearchPublisher(request: LyricsSearchRequest) -> AnyPublisher<LyricsToken, Never> {
        let url = switch request.searchTerm {
        case let .keyword(string):
            URL(string: "https://lrclib.net/api/search?q=\(string)")!
        case let .info(title, artist):
            URL(string: "https://lrclib.net/api/search?track_name=\(title)&artist_name=\(artist)")!
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        return sharedURLSession.cx.dataTaskPublisher(for: req)
            .map(\.data)
            .decode(type: [LRCLIBResponse].self, decoder: JSONDecoder().cx)
            .replaceError(with: [])
            .flatMap(Publishers.Sequence.init)
            .map { $0 as LyricsToken }
            .eraseToAnyPublisher()
    }

    private func parseLyrics(for token: LyricsToken) -> Lyrics? {
        guard let syncedLyrics = token.syncedLyrics, let lyrics = Lyrics(syncedLyrics) else { return nil }
        lyrics.idTags[.title] = token.trackName
        lyrics.idTags[.artist] = token.artistName
        lyrics.idTags[.album] = token.albumName
        lyrics.length = Double(token.duration) / 1000
        lyrics.metadata.serviceToken = "\(token.id)"
        return lyrics
    }

    public func lyricsFetchPublisher(token: LyricsToken) -> AnyPublisher<Lyrics, Never> {
        if let lyrics = parseLyrics(for: token) {
            return Just(lyrics).eraseToAnyPublisher()
        } else {
            return sharedURLSession.cx.dataTaskPublisher(for: .init(string: "https://lrclib.net/api/get/\(token.id)")!)
                .map(\.data)
                .decode(type: LRCLIBResponse.self, decoder: JSONDecoder().cx)
                .compactMap { [weak self] in
                    guard let self else { return nil }
                    return parseLyrics(for: $0)
                }
                .ignoreError()
                .eraseToAnyPublisher()
        }
    }
}
