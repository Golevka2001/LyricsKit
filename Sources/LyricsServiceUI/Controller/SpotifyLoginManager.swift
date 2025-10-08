import AppKit
import WebKit
import Schedule
import LyricsService

private typealias Task = _Concurrency.Task
private typealias ScheduleTask = Schedule.Task

public final class SpotifyLoginManager: NSObject, @unchecked Sendable {
    public static let shared = SpotifyLoginManager()

    @MainActor
    private let loginWindowController = SpotifyLoginWindowController()

    private static let keychainDomain = "com.JH.LyricsKit.SpotifyLoginManager"

    private actor SecureStorage {
        @Keychain(key: "cookie", service: SpotifyLoginManager.keychainDomain, defaultValue: nil)
        var cookie: String?

        @Keychain(key: "lyricsAccessToken", service: SpotifyLoginManager.keychainDomain, defaultValue: nil)
        var lyricsAccessToken: SpotifyAccessToken?

        @Keychain(key: "searchAccessToken", service: SpotifyLoginManager.keychainDomain, defaultValue: nil)
        var searchAccessToken: SpotifyAccessToken?

        func setCookie(_ newCookie: String?) {
            cookie = newCookie
        }

        func setLyricsAccessToken(_ token: SpotifyAccessToken?) {
            lyricsAccessToken = token
        }

        func setSearchAccessToken(_ token: SpotifyAccessToken?) {
            searchAccessToken = token
        }
    }

    private let secureStorage = SecureStorage()

    private var refreshTask: ScheduleTask?

    public var isLogin: Bool {
        get async {
            return await secureStorage.cookie != nil
        }
    }

    public var isAccessible: Bool {
        get async {
            let lyricsToken = await secureStorage.lyricsAccessToken
            let searchToken = await secureStorage.searchAccessToken
            return lyricsToken != nil && searchToken != nil
        }
    }

    public var lyricsAccessTokenString: String? {
        get async {
            return await secureStorage.lyricsAccessToken?.accessToken
        }
    }

    public var searchAccessTokenString: String? {
        get async {
            return await secureStorage.searchAccessToken?.accessToken
        }
    }

    public var accessTokenChanged: (() async throws -> Void)?

    private override init() {
        super.init()

        Task {
            try await self.requestAccessToken()
//            if let accessToken = await secureStorage.lyricsAccessToken {
//                if accessToken.expirationDate <= Date(), await secureStorage.cookie != nil {
//                    try await self.requestAccessToken()
//                } else {
//                    self.scheduleAccessTokenRefresh(accessToken)
//                }
//            }
//            
//            if let accessToken = await secureStorage.searchAccessToken {
//                if accessToken.expirationDate <= Date(), await secureStorage.cookie != nil {
//                    try await self.requestAccessToken()
//                } else {
//                    self.scheduleAccessTokenRefresh(accessToken)
//                }
//            }
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
        guard let cookie = await secureStorage.cookie else { return }
        let lyricsAccessToken = try await SpotifyAccessToken.lyricsAccessToken(forCookie: cookie)
        await secureStorage.setLyricsAccessToken(lyricsAccessToken)
        let searchAccessToken = try await SpotifyAccessToken.searchAccessToken(forCookie: cookie)
        await secureStorage.setSearchAccessToken(searchAccessToken)
        scheduleAccessTokenRefresh(lyricsAccessToken)
        scheduleAccessTokenRefresh(searchAccessToken)
        try await accessTokenChanged?()
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
        
        do {
            try await requestAccessToken()
        } catch {
            print(error)
        }
        
        await MainActor.run {
            loginWindowController.close()
        }
    }

    public func logout() async {
        await secureStorage.setCookie(nil)
        await secureStorage.setLyricsAccessToken(nil)
        await secureStorage.setSearchAccessToken(nil)

        await MainActor.run {
            loginWindowController.showWindow(nil)
            loginWindowController.loginViewController.gotoLogout()
        }
    }
}

extension SpotifyLoginManager: AuthenticationManager {
    public func isAuthenticated() async -> Bool {
        return await isAccessible
    }

    public func authenticate() async throws {
        try await login()
    }

    public func getCredentials() async throws -> [String: String] {
        guard let searchToken = await searchAccessTokenString,
              let lyricsToken = await lyricsAccessTokenString else {
            throw AuthenticationError.credentialsNotFound
        }

        return [
            "searchAccessToken": searchToken,
            "lyricsAccessToken": lyricsToken
        ]
    }
}
