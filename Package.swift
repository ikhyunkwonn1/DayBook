// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Daybook",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Daybook",
            targets: ["Daybook"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Daybook",
            path: "Sources/Daybook"
        ),
        .testTarget(
            name: "DaybookTests",
            dependencies: ["Daybook"],
            path: "Tests/DaybookTests"
        )
    ]
)
