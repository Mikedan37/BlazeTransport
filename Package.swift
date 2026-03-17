// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BlazeTransport",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "BlazeTransport",
            targets: ["BlazeTransport"]
        )
    ],
    targets: [
        .target(
            name: "BlazeTransport"
        ),
        .executableTarget(
            name: "BlazeTransportBenchmarks",
            dependencies: ["BlazeTransport"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "BlazeTransportFuzzing",
            dependencies: ["BlazeTransport"]
        ),
        .testTarget(
            name: "BlazeTransportTests",
            dependencies: ["BlazeTransport"]
        )
    ]
)
