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
        .library(name: "AaronFiles", targets: ["AaronFiles"]),
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
        .target(name: "AaronFiles", dependencies: ["AaronCore"]),
        .testTarget(name: "AaronCoreTests", dependencies: ["AaronCore"]),
        .testTarget(name: "AaronPreviewTests", dependencies: ["AaronPreview"]),
        .testTarget(name: "AaronAITests", dependencies: ["AaronAI"]),
        .testTarget(name: "AaronPelicanTests", dependencies: ["AaronPelican"]),
        .testTarget(name: "AaronHelpTests", dependencies: ["AaronHelp"]),
        .testTarget(name: "AaronFilesTests", dependencies: ["AaronFiles"]),
    ]
)
