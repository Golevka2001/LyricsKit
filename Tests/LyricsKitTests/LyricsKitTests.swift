import Testing
@testable import LyricsService

let testSong = "Over"
let testArtist = "yihuik苡慧/白静晨"
let duration = 155.0
let searchReq = LyricsSearchRequest(searchTerm: .info(title: testSong, artist: testArtist), duration: duration)

struct LyricsKitTests {
    private func test(provider: LyricsProvider) async throws {
        for try await lyrics in provider.lyrics(for: searchReq) {
            print(lyrics)
        }
    }

    @Test
    func qqMusicProvider() async throws {
        try await test(provider: LyricsProviders.QQMusic())
    }

    @Test
    func LRCLIBProvider() async throws {
        try await test(provider: LyricsProviders.LRCLIB())
    }

    @Test
    func kugouProvider() async throws {
        try await test(provider: LyricsProviders.Kugou())
    }

    @Test
    func netEaseProvider() async throws {
        try await test(provider: LyricsProviders.NetEase())
    }
}
