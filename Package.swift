// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Aaron",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "AaronCore", targets: ["AaronCore"]),
        .library(name: "AaronPreview", targets: ["AaronPreview"]),
        .library(name: "AaronAI", targets: ["AaronAI"]),
        .library(name: "AaronPelican", targets: ["AaronPelican"]),
        .library(name: "AaronHelp", targets: ["AaronHelp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.6.0"),
    ],
    targets: [
        .target(name: "AaronCore"),
        .target(name: "AaronPreview", dependencies: [
            "AaronCore",
            .product(name: "Markdown", package: "swift-markdown"),
        ]),
        .target(name: "AaronAI", dependencies: ["AaronCore"]),
        .target(name: "AaronPelican", dependencies: ["AaronCore"]),
        .target(name: "AaronHelp", resources: [.copy("Help")]),
        .testTarget(name: "AaronCoreTests", dependencies: ["AaronCore"]),
        .testTarget(name: "AaronPreviewTests", dependencies: ["AaronPreview"]),
        .testTarget(name: "AaronAITests", dependencies: ["AaronAI"]),
        .testTarget(name: "AaronPelicanTests", dependencies: ["AaronPelican"]),
        .testTarget(name: "AaronHelpTests", dependencies: ["AaronHelp"]),
    ]
)
