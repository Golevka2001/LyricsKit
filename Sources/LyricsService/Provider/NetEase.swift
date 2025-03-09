//
//  NetEase.swift
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
import Regex

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private let netEaseSearchBaseURLString = "http://music.163.com/api/search/pc?"
private let netEaseLyricsBaseURLString = "http://music.163.com/api/song/lyric?"

private let baseURLString = "https://neteasecloudmusicapi-ten-wine.vercel.app"
private let searchBaseURLString = "\(baseURLString)/search?"
private let lyricsBaseURLString = "\(baseURLString)/lyric/new?"

extension LyricsProviders {
    public final class NetEase {
        public init() {}
    }
}

public struct NetEaseSearchResponse: Codable {
    public struct Result: Codable {
        public struct Song: Codable {
            struct Artist: Codable {
                let id: Int
                let name: String
                let picURL: URL?
                let alias: [String]
                let albumSize: Int
                let picID: Int
                let fansGroup: String?
                let img1v1URL: URL
                let img1v1: Int
                let trans: String?

                private enum CodingKeys: String, CodingKey {
                    case id
                    case name
                    case picURL = "picUrl"
                    case alias
                    case albumSize
                    case picID = "picId"
                    case fansGroup
                    case img1v1URL = "img1v1Url"
                    case img1v1
                    case trans
                }
            }

            struct Album: Codable {
                struct Artist: Codable {
                    let id: Int
                    let name: String
                    let picURL: URL?
                    let alias: [String]
                    let albumSize: Int
                    let picID: Int
                    let fansGroup: String?
                    let img1v1URL: URL
                    let img1v1: Int
                    let trans: String?

                    private enum CodingKeys: String, CodingKey {
                        case id
                        case name
                        case picURL = "picUrl"
                        case alias
                        case albumSize
                        case picID = "picId"
                        case fansGroup
                        case img1v1URL = "img1v1Url"
                        case img1v1
                        case trans
                    }
                }

                let id: Int
                let name: String
                let artist: Artist
                let publishTime: Date
                let size: Int
                let copyrightID: Int
                let status: Int
                let picID: Int
                let mark: Int
                let alia: [String]?
                let transNames: [String]?

                private enum CodingKeys: String, CodingKey {
                    case id
                    case name
                    case artist
                    case publishTime
                    case size
                    case copyrightID = "copyrightId"
                    case status
                    case picID = "picId"
                    case mark
                    case alia
                    case transNames
                }
            }

            let id: Int
            let name: String
            let artists: [Artist]
            let album: Album
            let duration: Int
            let copyrightID: Int
            let status: Int
            let alias: [String]
            let rtype: Int
            let ftype: Int
            let mvid: Int
            let fee: Int
            let rURL: URL?
            let mark: Int
            let transNames: [String]?

            private enum CodingKeys: String, CodingKey {
                case id
                case name
                case artists
                case album
                case duration
                case copyrightID = "copyrightId"
                case status
                case alias
                case rtype
                case ftype
                case mvid
                case fee
                case rURL = "rUrl"
                case mark
                case transNames
            }
        }

        let songs: [Song]
        let hasMore: Bool
        let songCount: Int
    }

    let result: Result
    let code: Int
}

struct NetEaseLyricsResponse: Codable {
    struct Lrc: Codable {
        let version: Int
        let lyric: String
    }

    struct Klyric: Codable {
        let version: Int
        let lyric: String
    }

    struct Tlyric: Codable {
        let version: Int
        let lyric: String
    }

    struct Romalrc: Codable {
        let version: Int
        let lyric: String
    }

    let sgc: Bool
    let sfy: Bool
    let qfy: Bool
    let lrc: Lrc
    let klyric: Klyric
    let tlyric: Tlyric
    let romalrc: Romalrc
    let code: Int
}

extension LyricsProviders.NetEase: _LyricsProvider {
    public typealias LyricsToken = NetEaseSearchResponse.Result.Song
//    public struct LyricsToken {
//        let value: NetEaseResponseSearchResult.Result.Song
//    }
    public static let service: String? = "NetEase"

    public func lyricsSearchPublisher(request: LyricsSearchRequest) -> AnyPublisher<LyricsToken, Never> {
        let url = URL(string: searchBaseURLString + "keywords=\(request.searchTerm.description)?limit=10")!
        var req = URLRequest(url: url)
        return sharedURLSession.cx.dataTaskPublisher(for: req)
            .map(\.data)
            .decode(type: NetEaseSearchResponse.self, decoder: JSONDecoder().cx)
            .map(\.result.songs)
            .replaceError(with: [])
            .flatMap(Publishers.Sequence.init)
            .map { $0 as LyricsToken }
            .eraseToAnyPublisher()
    }

//    public func lyricsSearchPublisher(request: LyricsSearchRequest) -> AnyPublisher<LyricsToken, Never> {
//        let parameter: [String: Any] = [
//            "s": request.searchTerm.description,
//            "offset": 0,
//            "limit": 10,
//            "type": 1,
//            ]
//        let url = URL(string: netEaseSearchBaseURLString + parameter.stringFromHttpParameters)!
//        var req = URLRequest(url: url)
//        req.httpMethod = "POST"
//        req.setValue("http://music.163.com/", forHTTPHeaderField: "Referer")
//        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.4 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
//        return sharedURLSession.cx.dataTaskPublisher(for: req)
//            .map { data, response -> String? in
//                guard let httpResp = response as? HTTPURLResponse,
//                      let setCookie = httpResp.allHeaderFields["Set-Cookie"] as? String,
//                      let cookieIdx = setCookie.firstIndex(of: ";") else {
//                    return nil
//                }
//                return String(setCookie[..<cookieIdx])
//            }
//            .flatMap { cookie -> CXWrappers.URLSession.DataTaskPublisher in
//                req.setValue(cookie, forHTTPHeaderField: "Cookie")
//                return sharedURLSession.cx.dataTaskPublisher(for: req)
//            }
//            .map(\.data)
//            .decode(type: NetEaseResponseSearchResult.self, decoder: JSONDecoder().cx)
//            .map(\.songs)
//            .replaceError(with: [])
//            .flatMap(Publishers.Sequence.init)
//            .map(LyricsToken.init)
//            .eraseToAnyPublisher()
//    }

    public func lyricsFetchPublisher(token: LyricsToken) -> AnyPublisher<Lyrics, Never> {
        let url = URL(string: lyricsBaseURLString + "id=\(token.id)")!
        return sharedURLSession.cx.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: NetEaseResponseSingleLyrics.self, decoder: JSONDecoder().cx)
            .compactMap {
                let lyrics: Lyrics
                let transLrc = ($0.tlyric?.fixedLyric).flatMap(Lyrics.init(_:))
                if let yrc = $0.yrc?.lyric.flatMap(Lyrics.init(netEaseYrcContent:)) {
                    transLrc.map(yrc.forceMerge)
                    lyrics = yrc
                } else if let kLrc = ($0.klyric?.fixedLyric).flatMap(Lyrics.init(netEaseKLyricContent:)) {
                    transLrc.map(kLrc.forceMerge)
                    lyrics = kLrc
                } else if let lrc = ($0.lrc?.fixedLyric).flatMap(Lyrics.init(_:)) {
                    transLrc.map(lrc.merge)
                    lyrics = lrc
                } else {
                    return nil
                }

                // FIXME: merge inline time tags back to lyrics
                // if let taggedLrc = (model.klyric?.lyric).flatMap(Lyrics.init(netEaseKLyricContent:))

                lyrics.idTags[.title] = token.name
                lyrics.idTags[.artist] = token.artists.first?.name
                lyrics.idTags[.album] = token.album.name
                lyrics.idTags[.lrcBy] = $0.lyricUser?.nickname

                lyrics.length = Double(token.duration) / 1000
//                lyrics.metadata.artworkURL = token.album.artist.img1v1URL
                lyrics.metadata.serviceToken = "\(token.id)"

                return lyrics
            }
            .ignoreError()
            .eraseToAnyPublisher()
    }

//    public func lyricsFetchPublisher(token: LyricsToken) -> AnyPublisher<Lyrics, Never> {
//        let parameter: [String: Any] = [
//            "id": token.value.id,
//            "lv": 1,
//            "kv": 1,
//            "tv": -1,
//        ]
//        let url = URL(string: netEaseLyricsBaseURLString + parameter.stringFromHttpParameters)!
//        return sharedURLSession.cx.dataTaskPublisher(for: url)
//            .map(\.data)
//            .decode(type: NetEaseResponseSingleLyrics.self, decoder: JSONDecoder().cx)
//            .compactMap {
//                let lyrics: Lyrics
//                let transLrc = ($0.tlyric?.fixedLyric).flatMap(Lyrics.init(_:))
//                if let kLrc = ($0.klyric?.fixedLyric).flatMap(Lyrics.init(netEaseKLyricContent:)) {
//                    transLrc.map(kLrc.forceMerge)
//                    lyrics = kLrc
//                } else if let lrc = ($0.lrc?.fixedLyric).flatMap(Lyrics.init(_:)) {
//                    transLrc.map(lrc.merge)
//                    lyrics = lrc
//                } else {
//                    return nil
//                }
//
//                // FIXME: merge inline time tags back to lyrics
//                // if let taggedLrc = (model.klyric?.lyric).flatMap(Lyrics.init(netEaseKLyricContent:))
//
//                lyrics.idTags[.title]   = token.value.name
//                lyrics.idTags[.artist]  = token.value.artists.first?.name
//                lyrics.idTags[.album]   = token.value.album.name
//                lyrics.idTags[.lrcBy]   = $0.lyricUser?.nickname
//
//                lyrics.length = Double(token.value.duration) / 1000
//                lyrics.metadata.artworkURL = token.value.album.picUrl
//                lyrics.metadata.serviceToken = "\(token.value.id)"
//
//                return lyrics
//            }.ignoreError()
//            .eraseToAnyPublisher()
//    }
}

private let netEaseTimeTagFixer = Regex(#"(\[\d+:\d+):(\d+\])"#)

extension NetEaseResponseSingleLyrics.Lyric {
    fileprivate var fixedLyric: String? {
        return lyric?.replacingMatches(of: netEaseTimeTagFixer, with: "$1.$2")
    }
}
