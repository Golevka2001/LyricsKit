import AppKit
import WebKit

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
        view.frame = .init(x: 0, y: 0, width: 800, height: 600)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        gotoLogin()
        webView.navigationDelegate = self
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
        if url.absoluteString.starts(with: "https://accounts.google.com/") {
            webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15"
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
