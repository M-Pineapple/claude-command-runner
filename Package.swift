// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "claude-command-runner",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "claude-command-runner",
            targets: ["ClaudeCommandRunner"]
        ),
        .executable(
            name: "ConfigManager",
            targets: ["ConfigManager"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.1.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.3"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.3.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.62.0"),
    ],
    targets: [
        .executableTarget(
            name: "ClaudeCommandRunner",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "ConfigManager",
            dependencies: []
        ),
        .testTarget(
            name: "ClaudeCommandRunnerTests",
            dependencies: ["ClaudeCommandRunner"]
        ),
    ]
)
