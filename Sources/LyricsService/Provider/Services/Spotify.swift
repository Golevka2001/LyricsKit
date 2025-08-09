import Regex
import CXShim
import Foundation
import LyricsCore
import CXExtensions

extension LyricsProviders {
    final class Spotify: _LyricsProvider {
        typealias LyricsToken = SpotifyResponseSearchResult.Track.Item

        let searchAccessToken: String

        let lyricsAccessToken: String

        init(searchAccessToken: String, lyricsAccessToken: String) {
            self.searchAccessToken = searchAccessToken
            self.lyricsAccessToken = lyricsAccessToken
        }
    }
}

extension LyricsProviders.Spotify {
    static let service: String? = "Spotify"

    func lyricsSearchPublisher(request: LyricsSearchRequest) -> AnyPublisher<LyricsToken, Never> {
        let url: URL
        switch request.searchTerm {
        case .keyword(let string):
            url = URL(string: "https://api.spotify.com/v1/search?q=track:\(string)&type=track&limit=10")!
        case .info(let title, let artist):
            url = URL(string: "https://api.spotify.com/v1/search?q=track:\(title) artist:\(artist)&type=track&limit=10")!
        }

        var req = URLRequest(url: url)
        req.addValue("WebPlayer", forHTTPHeaderField: "app-platform")
        req.addValue("Bearer \(searchAccessToken)", forHTTPHeaderField: "Authorization")
        return sharedURLSession.cx.dataTaskPublisher(for: req)
            .map(\.data)
            .decode(type: SpotifyResponseSearchResult.self, decoder: JSONDecoder().cx)
            .map(\.tracks.items)
            .replaceError(with: [])
            .flatMap(Publishers.Sequence.init)
            .map {
                $0 as LyricsToken
            }
            .eraseToAnyPublisher()
    }

    func lyricsFetchPublisher(token: LyricsToken) -> AnyPublisher<Lyrics, Never> {
        let url = URL(string: "https://spclient.wg.spotify.com/color-lyrics/v2/track/\(token.id)?format=json&vocalRemoval=false&market=from_token")!
        var request = URLRequest(url: url)
        request.addValue("WebPlayer", forHTTPHeaderField: "app-platform")
        request.addValue("Bearer \(lyricsAccessToken)", forHTTPHeaderField: "Authorization")

        return sharedURLSession.cx.dataTaskPublisher(for: request)
            .map(\.data)
            .handleEvents(receiveOutput: { data in
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Received JSON: \(jsonString)")
                }
            })
            .decode(type: SpotifyResponseSingleLyrics.self, decoder: JSONDecoder().cx)
            .catch { error -> AnyPublisher<SpotifyResponseSingleLyrics, Error> in
                print("Decode error: \(error)")
                return Fail(error: error).eraseToAnyPublisher()
            }
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
            .ignoreError()
            .eraseToAnyPublisher()
    }
}
