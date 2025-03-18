// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "LyricsKit",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(
            name: "LyricsKit",
            targets: ["LyricsCore", "LyricsService", "LyricsServiceUI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/MxIris-LyricsX-Project/CXShim", branch: "master"),
        .package(url: "https://github.com/MxIris-LyricsX-Project/CXExtensions", branch: "master"),
        .package(url: "https://github.com/ddddxxx/Regex", from: "1.0.1"),
        .package(url: "https://github.com/MxIris-Library-Forks/SwiftCF", branch: "master"),
        .package(url: "https://github.com/1024jp/GzipSwift", from: "5.0.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", .upToNextMajor(from: "4.0.0")),
        .package(url: "https://github.com/MxIris-Library-Forks/Schedule", branch: "master"),
        .package(url: "https://github.com/lachlanbell/SwiftOTP", from: "3.0.2"),
    ],
    targets: [
        .target(
            name: "LyricsCore",
            dependencies: [
                .product(name: "Regex", package: "Regex"),
                .product(name: "SwiftCF", package: "SwiftCF"),
            ]
        ),
        .target(
            name: "LyricsService",
            dependencies: [
                "LyricsCore",
                .product(name: "CXShim", package: "CXShim"),
                .product(name: "CXExtensions", package: "CXExtensions"),
                .product(name: "Regex", package: "Regex"),
                .product(name: "Gzip", package: "GzipSwift"),
            ]
        ),
        .target(
            name: "LyricsServiceUI",
            dependencies: [
                "LyricsCore",
                "LyricsService",
                .product(name: "KeychainAccess", package: "KeychainAccess"),
                .product(name: "Schedule", package: "Schedule"),
                .product(name: "SwiftOTP", package: "SwiftOTP"),
            ]
        ),
        .testTarget(
            name: "LyricsKitTests",
            dependencies: [
                "LyricsCore",
                "LyricsService",
            ]
        ),
    ]
)

enum CombineImplementation {
    case combine
    case combineX
    case openCombine

    static var `default`: CombineImplementation {
        return .combineX
    }

    init?(_ description: String) {
        let desc = description.lowercased().filter(\.isLetter)
        switch desc {
        case "combine": self = .combine
        case "combinex": self = .combineX
        case "opencombine": self = .openCombine
        default: return nil
        }
    }
}

extension ProcessInfo {
    var combineImplementation: CombineImplementation {
        return environment["CX_COMBINE_IMPLEMENTATION"].flatMap(CombineImplementation.init) ?? .default
    }
}

import Foundation

if ProcessInfo.processInfo.combineImplementation == .combine {
    package.platforms = [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)]
}
