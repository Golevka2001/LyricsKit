import Foundation
import LyricsCore

private let qqSearchBaseURLString1 = "https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg"
private let qqSearchBaseURLString2 = "https://u.y.qq.com/cgi-bin/musicu.fcg"
private let qqLyricsBaseURLString1 = "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg"
private let qqLyricsBaseURLString2 = "https://c.y.qq.com/qqmusic/fcgi-bin/lyric_download.fcg"

extension LyricsProviders {
    public final class QQMusic {
        public init() {}
    }
}

extension LyricsProviders.QQMusic: _LyricsProvider {
    public struct LyricsToken {
        let value: QQMusicSongSearchResult
    }

    public static let service: String = "QQMusic"

    public func search(for request: LyricsSearchRequest) async throws -> [LyricsToken] {
        return try await withThrowingTaskGroup(of: [LyricsToken].self, returning: [LyricsToken].self) { group in
            group.addTask {
                return try await self.searchApi1(for: request)
            }

            group.addTask {
                return try await self.searchApi2(for: request)
            }

            var combinedResults: [LyricsToken] = []
            for try await results in group {
                combinedResults.append(contentsOf: results)
            }
            return combinedResults
        }
    }

    private func searchApi1(for request: LyricsSearchRequest) async throws -> [LyricsToken] {
        let parameter = ["key": request.searchTerm.description]
        guard let url = URL(string: qqSearchBaseURLString1 + "?" + parameter.stringFromHttpParameters) else {
            throw LyricsProviderError.invalidURL(urlString: qqSearchBaseURLString1)
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: .init(url: url))
            let result = try JSONDecoder().decode(QQResponseSearchResult.self, from: data)
            return result.data.song.list.map { LyricsToken(value: $0) }
        } catch {
            print("QQMusic search API 1 failed: \(error)")
            return []
        }
    }

    private func searchApi2(for request: LyricsSearchRequest) async throws -> [LyricsToken] {
        return []
    }

    public func fetch(with token: LyricsToken) async throws -> Lyrics {
        let token = token.value
        let parameter: [String: Any] = [
            "musicid": token.id,
            "version": 15,
            "miniversion": 82,
            "lrctype": 4,
        ]
        guard let url = URL(string: qqLyricsBaseURLString2 + "?" + parameter.stringFromHttpParameters) else {
            throw LyricsProviderError.invalidURL(urlString: qqLyricsBaseURLString2)
        }

        var req = URLRequest(url: url)
        req.setValue("y.qq.com/portal/player.html", forHTTPHeaderField: "Referer")

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: req)
        } catch {
            throw LyricsProviderError.networkError(underlyingError: error)
        }

        guard var dataString = String(data: data, encoding: .utf8) else {
            throw LyricsProviderError.processingFailed(reason: "Could not convert data to string.")
        }
        dataString = dataString.replacingOccurrences(of: "<!--", with: "").replacingOccurrences(of: "-->", with: "")

        guard let xmlDocument = try? XMLUtils.create(content: dataString),
              let encryptedString = try? xmlDocument.nodes(forXPath: "//content").first?.stringValue,
              let decryptedString = decryptQQMusicQrc(encryptedString),
              let lrc = Lyrics(qqmusicQrcContent: decryptedString)
        else {
            throw LyricsProviderError.processingFailed(reason: "Failed to parse or decrypt QQMusic QRC XML.")
        }

        lrc.idTags[.title] = token.name
        lrc.idTags[.artist] = token.singers.joined(separator: ",")
        lrc.metadata.serviceToken = "\(token.mid)"
        if let id = Int(token.mid) {
            lrc.metadata.artworkURL = URL(string: "http://imgcache.qq.com/music/photo/album/\(id % 100)/\(id).jpg")
        }

        if let transEncryptedString = try? xmlDocument.nodes(forXPath: "//contentts").first?.stringValue,
           let transDecryptedString = decryptQQMusicQrc(transEncryptedString),
           let transLrc = Lyrics(transDecryptedString) {
            lrc.merge(translation: transLrc)
        }

        return lrc
    }
}
