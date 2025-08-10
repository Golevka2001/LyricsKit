import Foundation
import LyricsCore

extension Lyrics.Metadata.Key {
    public static var request = Lyrics.Metadata.Key("request")
    public static var remoteURL = Lyrics.Metadata.Key("remoteURL")
    public static var artworkURL = Lyrics.Metadata.Key("artworkURL")
    public static var service = Lyrics.Metadata.Key("service")
    public static var serviceToken = Lyrics.Metadata.Key("serviceToken")
    static var quality = Lyrics.Metadata.Key("quality")

    static var searchIndex = Lyrics.Metadata.Key("searchIndex")
}

extension Lyrics.Metadata {
    public var request: LyricsSearchRequest? {
        get { return data[.request] as? LyricsSearchRequest }
        set { data[.request] = newValue }
    }

    public var remoteURL: URL? {
        get { return data[.remoteURL] as? URL }
        set { data[.remoteURL] = newValue }
    }

    public var artworkURL: URL? {
        get { return data[.artworkURL] as? URL }
        set { data[.artworkURL] = newValue }
    }

    public var service: String? {
        get { return data[.service] as? String }
        set { data[.service] = newValue }
    }

    public var serviceToken: String? {
        get { return data[.serviceToken] as? String }
        set { data[.serviceToken] = newValue }
    }

    var quality: Double? {
        get { return data[.quality] as? Double }
        set { data[.quality] = newValue }
    }

    var searchIndex: Int {
        get { return data[.searchIndex] as? Int ?? 0 }
        set { data[.searchIndex] = newValue }
    }
}
