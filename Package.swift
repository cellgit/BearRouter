// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "BearRouter",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(name: "BearRouterCore", targets: ["BearRouterCore"]),
        .library(name: "BearRouter", targets: ["BearRouter"]),
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
