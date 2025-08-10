import Foundation
import Regex
import LyricsCore

extension LyricsProviders {
    public final class Spotify {
        let searchAccessToken: String

        let lyricsAccessToken: String

        init(searchAccessToken: String, lyricsAccessToken: String) {
            self.searchAccessToken = searchAccessToken
            self.lyricsAccessToken = lyricsAccessToken
        }
    }
}

extension LyricsProviders.Spotify: _LyricsProvider {
    public typealias LyricsToken = SpotifyResponseSearchResult.Track.Item

    public static let service: String = "Spotify"

    public func search(for request: LyricsSearchRequest) async throws -> [LyricsToken] {
        let url: URL
        switch request.searchTerm {
        case .keyword(let string):
            url = URL(string: "https://api.spotify.com/v1/search?q=track:\(string)&type=track&limit=\(request.limit)")!
        case .info(let title, let artist):
            url = URL(string: "https://api.spotify.com/v1/search?q=track:\(title) artist:\(artist)&type=track&limit=\(request.limit)")!
        }

        var req = URLRequest(url: url)
        req.addValue("WebPlayer", forHTTPHeaderField: "app-platform")
        req.addValue("Bearer \(searchAccessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let result = try JSONDecoder().decode(SpotifyResponseSearchResult.self, from: data)
            print(result)
            return result.tracks.items
        } catch let error as DecodingError {
            throw LyricsProviderError.decodingError(underlyingError: error)
        } catch {
            throw LyricsProviderError.networkError(underlyingError: error)
        }
    }

    public func fetch(with token: LyricsToken) async throws -> Lyrics {
        guard let url = URL(string: "https://spclient.wg.spotify.com/color-lyrics/v2/track/\(token.id)?format=json&vocalRemoval=false&market=from_token") else {
            throw LyricsProviderError.invalidURL(urlString: "Spotify fetch URL")
        }

        var request = URLRequest(url: url)
        request.addValue("WebPlayer", forHTTPHeaderField: "app-platform")
        request.addValue("Bearer \(lyricsAccessToken)", forHTTPHeaderField: "Authorization")

        let singleLyricsResponse: SpotifyResponseSingleLyrics
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Spotify Received JSON: \(jsonString)")
            }
            singleLyricsResponse = try JSONDecoder().decode(SpotifyResponseSingleLyrics.self, from: data)
        } catch let error as DecodingError {
            print("Spotify Decode error: \(error)")
            throw LyricsProviderError.decodingError(underlyingError: error)
        } catch {
            throw LyricsProviderError.networkError(underlyingError: error)
        }

        let lyrics = Lyrics(lines: singleLyricsResponse.lyrics.lines.map {
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
}
