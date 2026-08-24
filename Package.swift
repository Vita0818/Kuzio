// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Kuzio",
    platforms: [
        .macOS("26.0"),
    ],
    products: [
        .executable(name: "Kuzio", targets: ["KuzioApp"]),
    ],
    targets: [
        .executableTarget(
            name: "KuzioApp",
            path: "Sources/KuzioApp",
            resources: [
                .copy("Fonts"),
            ]
        ),
        .testTarget(
            name: "KuzioAppTests",
            dependencies: ["KuzioApp"],
            path: "Tests/KuzioAppTests"
        ),
    ]
)
