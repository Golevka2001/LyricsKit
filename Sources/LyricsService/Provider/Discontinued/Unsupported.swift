import Foundation
import LyricsCore

extension LyricsProviders {
    public final class Unsupported {
        public init() {}
    }
}

extension LyricsProviders.Unsupported: LyricsProvider {
    
    public func lyrics(for request: LyricsSearchRequest) -> AsyncThrowingStream<Lyrics, any Error> {
        .init { $0.finish() }
    }
}
