// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// BlazeTransport - A QUIC-lite Swift-native transport protocol
// Version: 0.1.0

import PackageDescription

let package = Package(
    name: "BlazeTransport",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        /// Main BlazeTransport library providing transport protocol functionality.
        .library(
            name: "BlazeTransport",
            targets: ["BlazeTransport"]
        ),
        /// Benchmark executable for performance testing.
        .executable(
            name: "BlazeTransportBenchmarks",
            targets: ["BlazeTransportBenchmarks"]
        ),
        /// Fuzzing executable for security testing.
        .executable(
            name: "BlazeTransportFuzzing",
            targets: ["BlazeTransportFuzzing"]
        ),
    ],
    dependencies: [
        .package(
            url: "git@github.com:Mikedan37/BlazeBinary.git",
            branch: "main"
        ),
        .package(
            url: "git@github.com:Mikedan37/BlazeFSM.git",
            branch: "main"
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "BlazeTransport",
            dependencies: [
                .product(name: "BlazeBinary", package: "BlazeBinary"),
                .product(name: "BlazeFSM", package: "BlazeFSM"),
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
