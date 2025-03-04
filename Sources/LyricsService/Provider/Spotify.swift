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

struct SpotifyResponse: Codable {
    struct Tracks: Codable {
        struct Item: Codable {
            let type: String
            let id: String
        }

        let items: [Item]
    }

    let tracks: Tracks
}

extension LyricsProviders {
    final class Spotify: _LyricsProvider {
        typealias LyricsToken = SpotifyResponse.Tracks.Item

        let accessToken: String
        let fakeSpotifyUserAgentconfig = URLSessionConfiguration.default
        let fakeSpotifyUserAgentSession: URLSession
        init(accessToken: String) {
            self.accessToken = accessToken
            fakeSpotifyUserAgentconfig.httpAdditionalHeaders = ["User-Agent": "Spotify/121000760 Win32/0 (PC laptop)"]
            fakeSpotifyUserAgentSession = URLSession(configuration: fakeSpotifyUserAgentconfig)
        }
    }
}

extension LyricsProviders.Spotify {
    static var service: LyricsProviders.Service? = .spotify

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
            .decode(type: SpotifyResponse.self, decoder: JSONDecoder().cx)
            .map(\.tracks.items)
            .replaceError(with: [])
            .flatMap(Publishers.Sequence.init)
            .map { $0 as LyricsToken }
            .eraseToAnyPublisher()
    }

    func lyricsFetchPublisher(token: LyricsToken) -> AnyPublisher<Lyrics, Never> {
//        let url = URL(string: "https://spclient.wg.spotify.com/color-lyrics/v2/track/\(token.id)?format=json&vocalRemoval=false")!
//        var request = URLRequest(url: url)
//        request.addValue("WebPlayer", forHTTPHeaderField: "app-platform")
//        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "authorization")
//
//        return fakeSpotifyUserAgentSession.dataTaskPublisher(for: request)
//            .map {
//                
//            }
//            .ignoreOutput()
//            .eraseToAnyPublisher()
//
//        let songObject = try decoder.decode(SongObjectParent.self, from: urlResponseAndData.0)
//        print("downloaded from internet successfully \(trackID) \(trackName)")
//        saveCoreData()
//        let lyricsArray = zip(songObject.lyrics.lyricsTimestamps, songObject.lyrics.lyricsWords).map { LyricLine(startTime: $0, words: $1) }
        fatalError()
    }
}
