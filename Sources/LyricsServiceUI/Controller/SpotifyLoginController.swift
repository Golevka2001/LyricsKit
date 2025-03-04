import AppKit
import WebKit

struct SpotifyAccessToken: Codable {
    let accessToken: String
    let accessTokenExpirationTimestampMs: TimeInterval
    let isAnonymous: Bool
    
    static func accessToken(forCookie cookie: String) async throws -> Self {
        let url = URL(string: "https://open.spotify.com/get_access_token?reason=transport&productType=web_player")!
        var request = URLRequest(url: url)
        request.setValue("sp_dc=\(cookie)", forHTTPHeaderField: "Cookie")
        let accessTokenData = try await URLSession.shared.data(for: request).0
        return try JSONDecoder().decode(SpotifyAccessToken.self, from: accessTokenData)
    }
}

public final class SpotifyLoginController: NSObject {
    public static let shared = SpotifyLoginController()
    
//    var isLogin: Bool {
//        
//    }
    
    
}


public final class SpotifyLoginWindowController: NSWindowController {
    public init() {
        super.init(window: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadWindow() {
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 800, height: 600), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Spotify Login"
        window.setContentSize(NSSize(width: 800, height: 600))
        window.center()
        self.window = window
    }

    public override var windowNibName: NSNib.Name? { "" }

    public override func windowDidLoad() {
        contentViewController = SpotifyLoginViewController()
    }
}

public final class SpotifyLoginViewController: NSViewController {
    private let webView: WKWebView

    private static let loginURL = URL(string: "https://accounts.spotify.com/en/login?continue=https%3A%2F%2Fopen.spotify.com%2F")!

    private static let logoutURL = URL(string: "https://www.spotify.com/logout/")!

    public var didLogin: ((String) -> Void)?

    public init() {
        self.webView = WKWebView(frame: .zero, configuration: .init())
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        view = webView
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        gotoLogin()
    }

    public func gotoLogin() {
        webView.load(.init(url: Self.loginURL))
    }

    public func gotoLogout() {
        webView.load(.init(url: Self.logoutURL))
    }
}

extension SpotifyLoginViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        if url.absoluteString.starts(with: "https://open.spotify.com") {
            Task.detached {
                if let cookie = await WKWebsiteDataStore.default().spotifyCookie() {
                    await MainActor.run {
                        self.didLogin?(cookie)
                    }
                }
            }
        }
    }
}

extension WKWebsiteDataStore {
    public func spotifyCookie() async -> String? {
        let cookies = await httpCookieStore.allCookies()
        if let temporaryCookie = cookies.first(where: { $0.name == "sp_dc" }) {
            return temporaryCookie.value
        }
        return nil
    }
}

@available(macOS 14.0, *)
#Preview {
    SpotifyLoginViewController()
}
