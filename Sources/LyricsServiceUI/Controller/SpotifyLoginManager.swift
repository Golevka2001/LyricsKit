import AppKit
import WebKit
import KeychainAccess
import Schedule
import SwiftOTP

private typealias Task = _Concurrency.Task

private enum TOTPGenerator {
    static func generate(serverTimeSeconds: Int) -> String? {
        let secretCipher = [12, 56, 76, 33, 88, 44, 88, 33, 78, 78, 11, 66, 22, 22, 55, 69, 54]

        var processed = [UInt8]()
        for (i, byte) in secretCipher.enumerated() {
            processed.append(UInt8(byte ^ (i % 33 + 9)))
        }

        let processedStr = processed.map { String($0) }.joined()

        guard let utf8Bytes = processedStr.data(using: .utf8) else {
            return nil
        }

        let secretBase32 = utf8Bytes.base32EncodedString

        guard let secretData = base32DecodeToData(secretBase32) else {
            return nil
        }

        guard let totp = TOTP(secret: secretData, digits: 6, timeInterval: 30, algorithm: .sha1) else {
            return nil
        }

        return totp.generate(secondsPast1970: serverTimeSeconds)
    }
}

struct SpotifyAccessToken: Codable {
    let accessToken: String
    let accessTokenExpirationTimestampMs: TimeInterval
    let isAnonymous: Bool

    var expirationDate: Date {
        return Date(timeIntervalSince1970: accessTokenExpirationTimestampMs / 1000)
    }

    static func accessToken(forCookie cookie: String) async throws -> Self {
        struct ServerTime: Codable {
            var serverTime: Int
        }

        enum Error: Swift.Error {
            case totpGenerationFailed
        }

        let serverTimeRequest = URLRequest(url: .init(string: "https://open.spotify.com/server-time")!)
        let serverTimeData = try await URLSession.shared.data(for: serverTimeRequest).0
        let serverTime = try JSONDecoder().decode(ServerTime.self, from: serverTimeData).serverTime

        guard let totp = TOTPGenerator.generate(serverTimeSeconds: serverTime) else {
            throw Error.totpGenerationFailed
        }

        let url = URL(string: "https://open.spotify.com/get_access_token?reason=transport&productType=web_player&totpVer=5&ts=\(Int(Date().timeIntervalSince1970))&totp=\(totp)")!
        var request = URLRequest(url: url)
        request.setValue("sp_dc=\(cookie)", forHTTPHeaderField: "Cookie")
        let accessTokenData = try await URLSession.shared.data(for: request).0
        return try JSONDecoder().decode(SpotifyAccessToken.self, from: accessTokenData)
    }
}

@propertyWrapper
public struct Keychain<T: Codable> {
    private let keychain: KeychainAccess.Keychain

    public var wrappedValue: T {
        set {
            do {
                keychain[data: key] = try JSONEncoder().encode(newValue)
                _cacheWrappedValue = newValue
            } catch {
                print(error)
            }
        }
        mutating get {
            if let _cacheWrappedValue {
                return _cacheWrappedValue
            } else {
                if let data = keychain[data: key],
                   let value = try? JSONDecoder().decode(T.self, from: data) {
                    _cacheWrappedValue = value
                    return value
                } else {
                    return defaultValue
                }
            }
        }
    }

    private var _cacheWrappedValue: T?

    private let defaultValue: T

    private let key: String

    public init(key: String, service: String, defaultValue: T) {
        self.keychain = .init(service: service).synchronizable(true)
        self.key = key
        self.defaultValue = defaultValue
    }
}

public final class SpotifyLoginManager: NSObject, @unchecked Sendable {
    public static let shared = SpotifyLoginManager()

    /// 确保UI相关操作在主线程
    @MainActor
    private let loginWindowController = SpotifyLoginWindowController()

    private static let keychainDomain = "com.JH.LyricsKit.SpotifyLoginManager"

    /// 使用actor保护状态访问
    private actor SecureStorage {
        @Keychain(key: "cookie", service: SpotifyLoginManager.keychainDomain, defaultValue: nil)
        var cookie: String?

        @Keychain(key: "accessToken", service: SpotifyLoginManager.keychainDomain, defaultValue: nil)
        var accessToken: SpotifyAccessToken?

        func getCookie() -> String? {
            return cookie
        }

        func setCookie(_ newCookie: String?) {
            cookie = newCookie
        }

        func getAccessToken() -> SpotifyAccessToken? {
            return accessToken
        }

        func setAccessToken(_ token: SpotifyAccessToken?) {
            accessToken = token
        }
    }

    private let secureStorage = SecureStorage()

    private var refreshTask: Schedule.Task?

    public var isLogin: Bool {
        get async {
            return await secureStorage.getCookie() != nil
        }
    }

    public var isAccessible: Bool {
        get async {
            return await secureStorage.getAccessToken() != nil
        }
    }

    public var accessTokenString: String? {
        get async {
            return await secureStorage.getAccessToken()?.accessToken
        }
    }

    private override init() {
        super.init()

        Task {
            if let accessToken = await secureStorage.getAccessToken() {
                if accessToken.expirationDate <= Date(), await secureStorage.getCookie() != nil {
                    try await self.requestAccessToken()
                } else {
                    self.scheduleAccessTokenRefresh(accessToken)
                }
            }
        }
    }

    private func scheduleAccessTokenRefresh(_ accessToken: SpotifyAccessToken) {
        refreshTask?.cancel()
        refreshTask = Plan.at(accessToken.expirationDate).do(queue: .global()) { [weak self] in
            guard let self else { return }
            Task {
                try await self.requestAccessToken()
            }
        }
    }

    public func requestAccessToken() async throws {
        guard let cookie = await secureStorage.getCookie() else { return }
        let accessToken = try await SpotifyAccessToken.accessToken(forCookie: cookie)
        await secureStorage.setAccessToken(accessToken)
        scheduleAccessTokenRefresh(accessToken)
    }

    public func login() async throws {
        await MainActor.run {
            loginWindowController.showWindow(nil)
            loginWindowController.loginViewController.gotoLogin()
        }

        let cookie = try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                loginWindowController.loginViewController.didLogin = { [weak self] cookie in
                    continuation.resume(returning: cookie)
                    guard let self else { return }
                    loginWindowController.loginViewController.didLogin = nil
                }
            }
        }

        await secureStorage.setCookie(cookie)
        try await requestAccessToken()
        await MainActor.run {
            loginWindowController.close()
        }
    }

    public func logout() async {
        await secureStorage.setCookie(nil)
        await secureStorage.setAccessToken(nil)

        await MainActor.run {
            loginWindowController.showWindow(nil)
            loginWindowController.loginViewController.gotoLogout()
        }
    }
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
        self.window = window
    }

    lazy var loginViewController = SpotifyLoginViewController()

    public override var windowNibName: NSNib.Name? { "" }

    public override func windowDidLoad() {
        contentViewController = loginViewController
        window?.center()
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
