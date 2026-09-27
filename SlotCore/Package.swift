// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SlotCore",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "SlotCore", targets: ["SlotCore"]),
    ],
    targets: [
        .target(name: "SlotCore"),
        .testTarget(name: "SlotCoreTests", dependencies: ["SlotCore"]),
    ]
)
