// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChatGPTQuotaOverlay",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ChatGPTQuotaOverlay", targets: ["QuotaOverlay"])
    ],
    targets: [
        .executableTarget(
            name: "QuotaOverlay",
            path: "Sources/QuotaOverlay"
        ),
        .testTarget(
            name: "QuotaOverlayTests",
            dependencies: ["QuotaOverlay"],
            path: "Tests/QuotaOverlayTests"
        )
    ]
)
