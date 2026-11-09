// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ar_engine",
    platforms: [
        .iOS(.v14)
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
                .linkedFramework("ARKit"),
                .linkedFramework("SceneKit"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("CoreMotion"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("ImageIO"),
                .linkedFramework("CoreLocation")
            ]
        )
    ]
)
