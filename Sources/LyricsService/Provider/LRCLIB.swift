import Foundation
import LyricsCore
import CXShim
import CXExtensions
import Regex

// https://lrclib.net/api/search
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension LyricsProviders {
    public final class LRCLIB {
        public init() {}
    }
}

public struct LRCLIBResponse: Codable {
  let id: Int
  let name: String
  let trackName: String
  let artistName: String
  let albumName: String
  let duration: Double
  let instrumental: Bool
  let plainLyrics: String?
  let syncedLyrics: String?
}

extension LyricsProviders.LRCLIB: _LyricsProvider {
    
    public typealias LyricsToken = LRCLIBResponse
    
    public static let service: String? = "LRCLIB"
    
    public func lyricsSearchPublisher(request: LyricsSearchRequest) -> AnyPublisher<LyricsToken, Never> {
        let url = switch request.searchTerm {
        case .keyword(let string):
            URL(string: "https://lrclib.net/api/search?q=\(string)")!
        case .info(let title, let artist):
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
    
    public func lyricsFetchPublisher(token: LyricsToken) -> AnyPublisher<Lyrics, Never> {
        guard let syncedLyrics = token.syncedLyrics, let lyrics = Lyrics(syncedLyrics) else { return Empty<Lyrics, Never>().eraseToAnyPublisher() }
        
        
        return Just(lyrics).eraseToAnyPublisher()
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
    }
}
