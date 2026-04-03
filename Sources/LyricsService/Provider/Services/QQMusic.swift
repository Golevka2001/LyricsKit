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

    // Search via the musicu endpoint (POST JSON).
    private func searchApi2(for request: LyricsSearchRequest) async throws -> [LyricsToken] {
        let requestBody: [String: Any] = [
            "req_1": [
                "method": "DoSearchForQQMusicDesktop",
                "module": "music.search.SearchCgiService",
                "param": [
                    "num_per_page": 20,
                    "page_num": 1,
                    "query": request.searchTerm.description,
                    "search_type": 0,   // 0 = single track
                ],
            ],
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: requestBody),
              let url = URL(string: qqSearchBaseURLString2) else {
            return []
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = bodyData
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let result = try JSONDecoder().decode(QQResponseSearchResult2.self, from: data)
            guard result.request.code == 0 else { return [] }
            return result.request.data.body.song.list.map { LyricsToken(value: $0) }
        } catch {
            print("QQMusic search API 2 failed: \(error)")
            return []
        }
    }

    public func fetch(with token: LyricsToken) async throws -> Lyrics {
        let token = token.value
        let parameter: [String: Any] = [
            "musicid": token.id,
            "version": 15,
            "miniversion": 82,
            "lrctype": 4,
        ]

        guard let url = URL(string: qqLyricsBaseURLString2) else {
            throw LyricsProviderError.invalidURL(urlString: qqLyricsBaseURLString2)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        // The server checks the Referer header.
        req.setValue("https://c.y.qq.com/", forHTTPHeaderField: "Referer")
        req.httpBody = parameter.stringFromHttpParameters.data(using: .utf8)

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

        guard let xmlDocument = try? XMLUtils.create(content: dataString) else {
            throw LyricsProviderError.processingFailed(reason: "Failed to parse QQMusic XML response.")
        }

        // Extract the main (original) lyrics.
        guard let origContent = extractLyricContent(from: xmlDocument, xpath: "//content"),
              let lrc = Lyrics(qqmusicQrcContent: origContent) else {
            throw LyricsProviderError.processingFailed(reason: "Failed to parse or decrypt QQMusic QRC lyrics.")
        }

        lrc.idTags[.title] = token.name
        lrc.idTags[.artist] = token.singers.joined(separator: ",")
        lrc.metadata.serviceToken = "\(token.mid)"
        lrc.metadata.artworkURL = await fetchAlbumCoverURL(songMid: token.mid)

        // Merge translated lyrics when available (contentts element).
        if let transContent = extractLyricContent(from: xmlDocument, xpath: "//contentts"),
           let transLrc = Lyrics(transContent) {
            lrc.merge(translation: transLrc)
        }

        return lrc
    }

    /// Reads the text of the XML element at `xpath`, decrypts it (if hex-encoded),
    /// and unwraps any nested XML document.
    ///
    /// - Returns: The ready-to-parse lyric string, or `nil` if anything goes wrong.
    private func extractLyricContent(from document: XMLDocument, xpath: String) -> String? {
        guard let node = (try? document.nodes(forXPath: xpath))?.first,
              let text = node.stringValue else { return nil }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Even length, every character in [0-9 a-f A-F].
        let isHex = trimmed.count % 2 == 0 && trimmed.allSatisfy { $0.isHexDigit }

        let decoded: String
        if isHex {
            // Triple-DES decrypt + zlib inflate.
            guard let decrypted = decryptQQMusicQrc(trimmed) else { return nil }
            decoded = decrypted
        } else {
            // Content is already plaintext (e.g. an LRC block passed without encryption).
            decoded = trimmed
        }

        // Some responses embed the real QRC data one level deeper inside a second XML
        // document — the lyrics live in the LyricContent attribute of <Lyric_1/>.
        //
        // IMPORTANT: We must NOT use XMLDocument to read this attribute, because the
        // XML spec requires parsers to normalize attribute values by replacing literal
        // newlines with spaces.  The QRC parser relies on real newlines, so we extract
        // the attribute value directly from the raw decoded string instead.
        if decoded.contains("<?xml") {
            if let content = extractLyricContentAttribute(from: decoded) {
                return content
            }
        }

        return decoded
    }

    /// Extracts the value of the `LyricContent` attribute from a raw XML string
    /// without going through an XML parser (which would collapse newlines to spaces).
    private func extractLyricContentAttribute(from xmlString: String) -> String? {
        let marker = "LyricContent=\""
        guard let markerRange = xmlString.range(of: marker) else { return nil }
        let afterMarker = xmlString[markerRange.upperBound...]
        // The attribute value ends at the first unescaped double-quote.
        // QRC lyrics do not contain literal double-quote characters, so a simple
        // search for the next `"` is safe here.
        guard let endQuote = afterMarker.firstIndex(of: "\"") else { return nil }
        let content = String(afterMarker[..<endQuote])
        return content.isEmpty ? nil : content
    }

    private func fetchAlbumCoverURL(songMid: String) async -> URL? {
        let requestBody: [String: Any] = [
            "comm": ["ct": 24, "cv": 0],
            "songinfo": [
                "module": "music.pf_song_detail_svr",
                "method": "get_song_detail_yqq",
                "param": ["song_mid": songMid],
            ],
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: requestBody) else { return nil }
        var request = URLRequest(url: URL(string: qqSearchBaseURLString2)!)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let response = try? JSONDecoder().decode(QQResponseSongDetail.self, from: data),
              !response.songinfo.data.trackInfo.album.mid.isEmpty else {
            return nil
        }
        let albumMid = response.songinfo.data.trackInfo.album.mid
        return URL(string: "https://y.gtimg.cn/music/photo_new/T002R800x800M000\(albumMid).jpg")
    }
}
