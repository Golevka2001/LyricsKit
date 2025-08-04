import XCTest
@testable import LyricsService

let testSong = "Over"
let testArtist = "yihuik苡慧/白静晨"
let duration = 155.0
let searchReq = LyricsSearchRequest(searchTerm: .info(title: testSong, artist: testArtist), duration: duration)

final class LyricsKitTests: XCTestCase {
    private func test(provider: LyricsProvider) {
        var searchResultEx: XCTestExpectation? = expectation(description: "Search result: \(provider)")
        let token = provider.lyricsPublisher(request: searchReq).sink { lrc in
            print(lrc)
            searchResultEx?.fulfill()
            searchResultEx = nil
        }
        waitForExpectations(timeout: 10)
        token.cancel()
    }

    func testQQMusicProvider() {
        test(provider: LyricsProviders.QQMusic())
    }
    
    func testLRCLIBProvider() {
        test(provider: LyricsProviders.LRCLIB())
    }
    
    func testKugouProvider() {
        test(provider: LyricsProviders.Kugou())
    }
    
    func testNetEaseProvider() {
        test(provider: LyricsProviders.NetEase())
    }
}
