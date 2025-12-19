// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BearRouter",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "BearRouterCore", targets: ["BearRouterCore"]),
        .library(name: "BearRouter", targets: ["BearRouter"]),
        .library(name: "BearRouterOS26", targets: ["BearRouterOS26"]),
        .library(name: "BearRouterTesting", targets: ["BearRouterTesting"])
    ],
    targets: [
        .target(
            name: "BearRouterCore",
            dependencies: []
        ),
        .target(
            name: "BearRouter",
            dependencies: ["BearRouterCore"]
        ),
        .target(
            name: "BearRouterOS26",
            dependencies: ["BearRouter"]
        ),
        .target(
            name: "BearRouterTesting",
            dependencies: ["BearRouterCore"]
        ),
        .testTarget(
            name: "BearRouterCoreTests",
            dependencies: [
                "BearRouterCore",
                "BearRouterTesting"
            ]
        ),
        .testTarget(
            name: "BearRouterSwiftUITests",
            dependencies: ["BearRouter"]
        )
    ]
)
