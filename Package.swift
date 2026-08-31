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
    dependencies: [
        .package(path: "../../Intatis"),
    ],
    targets: [
        .executableTarget(
            name: "KuzioApp",
            dependencies: [
                .product(name: "IntatisCore", package: "Intatis"),
                .product(name: "IntatisProtocol", package: "Intatis"),
                .product(name: "IntatisProviders", package: "Intatis"),
                .product(name: "IntatisConversation", package: "Intatis"),
                .product(name: "IntatisCodexRuntime", package: "Intatis"),
                .product(name: "IntatisCoworkUI", package: "Intatis"),
                .product(name: "IntatisSharedUI", package: "Intatis"),
            ],
            path: "Sources/KuzioApp",
            exclude: [
                "Fonts/JetBrainsMono-Regular.ttf",
                "Fonts/JetBrainsMono-Medium.ttf",
                "Fonts/JetBrainsMono-SemiBold.ttf",
                "Fonts/JetBrainsMono-Bold.ttf",
            ],
            resources: [
                .copy("Fonts/JetBrainsMono-OFL.txt"),
            ]
        ),
        .testTarget(
            name: "KuzioAppTests",
            dependencies: ["KuzioApp"],
            path: "Tests/KuzioAppTests"
        ),
    ]
)
