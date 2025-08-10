import Foundation
import LyricsCore

private let kugouSearchBaseURLString = "http://lyrics.kugou.com/search"
private let kugouLyricsBaseURLString = "http://lyrics.kugou.com/download"

extension LyricsProviders {
    public final class Kugou {
        public init() {}
    }
}

extension LyricsProviders.Kugou: _LyricsProvider {
    public struct LyricsToken {
        let value: KugouResponseSearchResult.Data.Info
    }

    public static let service: String = "Kugou"

    public func search(for request: LyricsSearchRequest) async throws -> [LyricsToken] {
//        let parameter: [String: Any] = [
//            "keyword": request.searchTerm.description,
//            "duration": Int(request.duration * 1000),
//            "client": "pc",
//            "ver": 1,
//            "man": "yes",
//        ]

        let urlString = "http://mobilecdn.kugou.com/api/v3/search/song?format=json&keyword=\(request.searchTerm.description)&page=1&pagesize=20&showtype=1"
//        let urlString = kugouSearchBaseURLString + "?" + parameter.stringFromHttpParameters
        guard let url = URL(string: urlString) else {
            throw LyricsProviderError.invalidURL(urlString: urlString)
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let searchResult = try JSONDecoder().decode(KugouResponseSearchResult.self, from: data)

            return searchResult.data.info.map { .init(value: $0) }

//            return searchResult.candidates.map(LyricsToken.init)
        } catch let error as DecodingError {
            throw LyricsProviderError.decodingError(underlyingError: error)
        } catch {
            throw LyricsProviderError.networkError(underlyingError: error)
        }
    }

    public func fetch(with token: LyricsToken) async throws -> Lyrics {
        let url = URL(string: "https://krcs.kugou.com/search?ver=1&man=yes&client=mobi&keyword=&duration=&hash=\(token.value.hash)&album_audio_id=\(token.value.albumAudioID)")!

        let (candidatesData, _) = try await URLSession.shared.data(for: .init(url: url))

        guard let candidate = try JSONDecoder().decode(KugouResponseSearchResultCandidates.self, from: candidatesData).candidates.first else {
            throw LyricsProviderError.processingFailed(reason: "No candidates found for the provided token.")
        }

        let parameter: [String: Any] = [
            "id": candidate.id,
            "accesskey": candidate.accesskey,
            "fmt": "krc",
            "charset": "utf8",
            "client": "pc",
            "ver": 1,
        ]

        let urlString = kugouLyricsBaseURLString + "?" + parameter.stringFromHttpParameters
        guard let url = URL(string: urlString) else {
            throw LyricsProviderError.invalidURL(urlString: urlString)
        }

        let singleLyricsResponse: KugouResponseSingleLyrics
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            singleLyricsResponse = try JSONDecoder().decode(KugouResponseSingleLyrics.self, from: data)
        } catch let error as DecodingError {
            throw LyricsProviderError.decodingError(underlyingError: error)
        } catch {
            throw LyricsProviderError.networkError(underlyingError: error)
        }

        guard let lrcContent = decryptKugouKrc(singleLyricsResponse.content) else {
            throw LyricsProviderError.processingFailed(reason: "Failed to decrypt KRC content.")
        }

        guard let lrc = Lyrics(kugouKrcContent: lrcContent) else {
            throw LyricsProviderError.processingFailed(reason: "Failed to initialize Lyrics from KRC content.")
        }

        lrc.idTags[.title] = candidate.song
        lrc.idTags[.artist] = candidate.singer
        lrc.idTags[.lrcBy] = "Kugou"
        lrc.length = Double(candidate.duration) / 1000

        var urlComponents = URLComponents(string: "https://wwwapi.kugou.com/yy/index.php")!

        urlComponents.queryItems = [
            URLQueryItem(name: "r", value: "play/getdata"),
            URLQueryItem(name: "hash", value: token.value.hash),
            URLQueryItem(name: "dfid", value: randomString(
                length: 23,
                characters: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
            )),
            URLQueryItem(name: "mid", value: randomString(
                length: 23,
                characters: "abcdefghijklmnopqrstuvwxyz0123456789"
            )),
            URLQueryItem(name: "album_id", value: token.value.albumID),
//            URLQueryItem(name: "_", value: String(Date().timeIntervalSince1970 * 1000)),
        ]

        lrc.metadata.artworkURL = urlComponents.url

        lrc.metadata.serviceToken = "\(candidate.id),\(candidate.accesskey)"

        return lrc
    }

    func randomString(length: Int, characters: String) -> String {
        return String((0 ..< length).map { _ in
            characters.randomElement()!
        })
    }
}
