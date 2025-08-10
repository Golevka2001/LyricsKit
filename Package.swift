// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "LyricsKit",
    platforms: [
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "LyricsKit",
            targets: ["LyricsKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ddddxxx/Regex", from: "1.0.1"),
        .package(url: "https://github.com/MxIris-Library-Forks/SwiftCF", branch: "master"),
        .package(url: "https://github.com/1024jp/GzipSwift", from: "5.0.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", .upToNextMajor(from: "4.0.0")),
        .package(url: "https://github.com/MxIris-Library-Forks/Schedule", branch: "master"),
        .package(url: "https://github.com/lachlanbell/SwiftOTP", from: "3.0.2"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/attaswift/BigInt", from: "5.6.0"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift", from: "1.9.0"),
    ],
    targets: [
        .target(
            name: "LyricsKit",
            dependencies: [
                "LyricsCore",
                "LyricsService",
                "LyricsServiceUI",
            ]
        ),
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
                .product(name: "Regex", package: "Regex"),
                .product(name: "Gzip", package: "GzipSwift"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "BigInt", package: "BigInt"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
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
