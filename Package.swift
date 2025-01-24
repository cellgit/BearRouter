// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "BearRouter",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_14)
    ],
    products: [
        .library(
            name: "BearRouter",
            targets: ["BearRouter"]
        )
    ],
    dependencies: [
//        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.6.4")
    ],
    targets: [
        .target(
            name: "BearRouter"
//            dependencies: ["Alamofire"]
        ),
        .testTarget(
            name: "BearRouterTests",
            dependencies: ["BearRouter"]
        )
    ]
)
