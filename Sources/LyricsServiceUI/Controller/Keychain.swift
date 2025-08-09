import Foundation
import KeychainAccess

@propertyWrapper
struct Keychain<T: Codable> {
    private let keychain: KeychainAccess.Keychain

    var wrappedValue: T {
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

    init(key: String, service: String, defaultValue: T) {
        self.keychain = .init(service: service).synchronizable(true)
        self.key = key
        self.defaultValue = defaultValue
    }
}
