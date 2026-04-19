// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BowPress",
    platforms: [.iOS(.v17), .macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.0.0"),
        .package(url: "https://github.com/airbnb/lottie-ios", from: "4.5.0"),
        .package(url: "https://github.com/willdale/SwiftUICharts", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0")
    ],
    targets: [
        .target(
            name: "BowPress",
            dependencies: [
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "GoogleSignInSwift", package: "GoogleSignIn-iOS"),
                .product(name: "Lottie", package: "lottie-ios"),
                .product(name: "SwiftUICharts", package: "SwiftUICharts")
            ],
            path: "Sources/BowPress",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "BowPressTests",
            dependencies: [
                "BowPress",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            path: "Tests/BowPressTests"
        )
    ]
)
