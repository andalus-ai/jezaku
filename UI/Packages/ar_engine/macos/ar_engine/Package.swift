// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ar_engine",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "ar_engine",
            targets: ["ar_engine"]
        )
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "ar_engine",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            path: "../Classes",
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreImage"),
                .linkedFramework("ImageIO"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit")
            ]
        )
    ]
)
