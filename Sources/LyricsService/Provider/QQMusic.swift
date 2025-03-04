//
//  QQMusic.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import LyricsCore
import CXShim
import CXExtensions
//import SWXMLHash

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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
    public typealias LyricsToken = QQMusicSongSearchResult

    public static let service: String? = "QQMusic"

    public func lyricsSearchPublisher(request: LyricsSearchRequest) -> AnyPublisher<LyricsToken, Never> {
        let parameter = ["key": request.searchTerm.description]
        let url = URL(string: qqSearchBaseURLString1 + "?" + parameter.stringFromHttpParameters)!

        return sharedURLSession.cx.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: QQResponseSearchResult.self, decoder: JSONDecoder().cx)
            .map(\.data.song.list)
            .replaceError(with: [])
            .flatMap(Publishers.Sequence.init)
            .map { $0 as LyricsToken }
            .eraseToAnyPublisher()
//            .merge(with: lyricsSearchPublisher2(request: request))
//            .eraseToAnyPublisher()
    }

    public func lyricsSearchPublisher2(request: LyricsSearchRequest) -> AnyPublisher<LyricsToken, Never> {
        let parameter = [
            "req_1": [
                "method": "DoSearchForQQMusicDesktop",
                "module": "music.search.SearchCgiService",
                "param": [
                    "num_per_page": "20",
                    "page_num": "1",
                    "query": request.searchTerm.titleOnly,
                    "search_type": "0",
                ],
            ],
        ]

        let jsonData = try! JSONSerialization.data(withJSONObject: parameter, options: [])
        let jsonString = String(data: jsonData, encoding: .utf8)!
        let encodedJsonString = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let urlString = qqSearchBaseURLString2 + "?data=" + encodedJsonString
        let url = URL(string: urlString)!
        return sharedURLSession.cx.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: QQResponseSearchResult2.self, decoder: JSONDecoder().cx)
            .map(\.request.data.body.song.list)
            .replaceError(with: [])
            .flatMap(Publishers.Sequence.init)
            .map { $0 as LyricsToken }
            .eraseToAnyPublisher()
    }

    public func lyricsFetchPublisher(token: LyricsToken) -> AnyPublisher<Lyrics, Never> {
        let parameter: [String: Any] = [
            "musicid": token.id,
            "version": 15,
            "miniversion": 82,
            "lrctype": 4,
        ]
        let url = URL(string: qqLyricsBaseURLString2 + "?" + parameter.stringFromHttpParameters)!
        var req = URLRequest(url: url)
        req.setValue("y.qq.com/portal/player.html", forHTTPHeaderField: "Referer")
        return sharedURLSession.cx.dataTaskPublisher(for: req)
            .compactMap { response -> Lyrics? in
                guard var dataString = String(data: response.data, encoding: .utf8) else {
                    return nil
                }
                dataString = dataString.replacingOccurrences(of: "<!--", with: "")
                dataString = dataString.replacingOccurrences(of: "-->", with: "")
                guard let xmlDocument = try? XMLUtils.create(content: dataString),
                      let encryptedString = try? xmlDocument.nodes(forXPath: "//content").first?.stringValue,
                      let decryptedString = decryptQQMusicQrc(encryptedString),
//                      let decryptedXMLDocument = try? XMLDocument(xmlString: decryptedString, options: [.nodePreserveAll, .nodeNeverEscapeContents]),
//                      let qrcContent = try? decryptedXMLDocument.nodes(forXPath: "//@LyricContent").first?.xmlString(options: .nodePreserveAll),
                      let lrc = Lyrics(qqmusicQrcContent: decryptedString)
                else {
                    return nil
                }

//                guard let model = try? JSONDecoder().decode(QQResponseSingleLyrics.self, from: data),
//                    let lrcContent = model.lyricString,
//                    let lrc = Lyrics(lrcContent) else {
//                        return nil
//                }
//                if let transLrcContent = model.transString,
//                    let transLrc = Lyrics(transLrcContent) {
//                    lrc.merge(translation: transLrc)
//                }

                lrc.idTags[.title] = token.name
                lrc.idTags[.artist] = token.singers.joined(separator: ",")
//                lrc.idTags[.album] = token.albumname

//                lrc.length = Double(token.interval)
                lrc.metadata.serviceToken = "\(token.mid)"
                if let id = Int(token.mid) {
                    lrc.metadata.artworkURL = URL(string: "http://imgcache.qq.com/music/photo/album/\(id % 100)/\(id).jpg")
                }

                if let transEncryptedString = try? xmlDocument.nodes(forXPath: "//contentts").first?.stringValue,
                   let transDecryptedString = decryptQQMusicQrc(transEncryptedString),
                   let transLrc = Lyrics(transDecryptedString)
                {
                    lrc.merge(translation: transLrc)
                }
                
                // remove their kana tag. we don't need it.
//                lrc.idTags.removeValue(forKey: .qqMusicKana)

                return lrc
            }.ignoreError()
            .eraseToAnyPublisher()
    }

    public func _lyricsFetchPublisher(token: LyricsToken) -> AnyPublisher<Lyrics, Never> {
        let parameter: [String: Any] = [
            "songmid": token.mid,
            "g_tk": 5381,
        ]
        let url = URL(string: qqLyricsBaseURLString1 + "?" + parameter.stringFromHttpParameters)!
        var req = URLRequest(url: url)
        req.setValue("y.qq.com/portal/player.html", forHTTPHeaderField: "Referer")
        return sharedURLSession.cx.dataTaskPublisher(for: req)
            .compactMap { response -> Lyrics? in
                let data = response.data.dropFirst(18).dropLast()
                guard let model = try? JSONDecoder().decode(QQResponseSingleLyrics.self, from: data),
                      let lrcContent = model.lyricString,
                      let lrc = Lyrics(lrcContent) else {
                    return nil
                }
                if let transLrcContent = model.transString,
                   let transLrc = Lyrics(transLrcContent) {
                    lrc.merge(translation: transLrc)
                }

                lrc.idTags[.title] = token.name
                lrc.idTags[.artist] = token.singers.joined(separator: ",")
//                lrc.idTags[.album] = token.albumname

//                lrc.length = Double(token.interval)
                lrc.metadata.serviceToken = "\(token.mid)"
                if let id = Int(token.mid) {
                    lrc.metadata.artworkURL = URL(string: "http://imgcache.qq.com/music/photo/album/\(id % 100)/\(id).jpg")
                }

                // remove their kana tag. we don't need it.
//                lrc.idTags.removeValue(forKey: .qqMusicKana)

                return lrc
            }.ignoreError()
            .eraseToAnyPublisher()
    }
}
