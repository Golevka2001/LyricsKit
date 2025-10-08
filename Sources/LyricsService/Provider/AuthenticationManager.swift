import Foundation

public protocol AuthenticationManager: Sendable {
    func isAuthenticated() async -> Bool
    func authenticate() async throws
    func getCredentials() async throws -> [String: String]
}

public enum AuthenticationError: Error {
    case notAuthenticated
    case credentialsNotFound
    case authenticationFailed(Error)
}