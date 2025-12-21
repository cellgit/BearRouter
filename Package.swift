// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "BearRouter",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2)
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
