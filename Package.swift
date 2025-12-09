// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BlazeTransport",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "BlazeTransport",
            targets: ["BlazeTransport"]
        ),
    ],
    dependencies: [
        .package(path: "../BlazeBinary"),
        .package(path: "../BlazeFSM"),
        .package(path: "../BlazeDB"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "BlazeTransport",
            dependencies: [
                .product(name: "BlazeBinary", package: "BlazeBinary"),
                .product(name: "BlazeFSM", package: "BlazeFSM"),
                .product(name: "BlazeDB", package: "BlazeDB"),
            ]
        ),
        .testTarget(
            name: "BlazeTransportTests",
            dependencies: ["BlazeTransport"]
        ),
        .executableTarget(
            name: "BlazeTransportBenchmarks",
            dependencies: ["BlazeTransport"]
        ),
        .executableTarget(
            name: "BlazeTransportFuzzing",
            dependencies: ["BlazeTransport"]
        ),
    ]
)
