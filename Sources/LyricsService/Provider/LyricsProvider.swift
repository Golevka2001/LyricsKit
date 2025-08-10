import Foundation
import LyricsCore

public enum LyricsProviders {}

public protocol LyricsProvider {
    func lyrics(for request: LyricsSearchRequest) -> AsyncThrowingStream<Lyrics, Error>
}

public protocol _LyricsProvider: LyricsProvider {
    associatedtype LyricsToken

    static var service: String { get }

    func search(for request: LyricsSearchRequest) async throws -> [LyricsToken]

    func fetch(with token: LyricsToken) async throws -> Lyrics
}

extension _LyricsProvider {
    public func lyrics(for request: LyricsSearchRequest) -> AsyncThrowingStream<Lyrics, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let tokens = try await self.search(for: request)
                    let limitedTokens = tokens.prefix(request.limit)

                    let fetchTasks: [Task<Lyrics, Error>] = limitedTokens.map { token in
                        Task {
                            let lrc = try await self.fetch(with: token)
                            lrc.metadata.request = request
                            lrc.metadata.service = Self.service
                            return lrc
                        }
                    }

                    for task in fetchTasks {
                        do {
                            let lyric = try await task.value
                            continuation.yield(lyric)
                        } catch {
                            print("A fetch task failed, skipping. Error: \(error)")
                        }
                    }

                    continuation.finish()

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
