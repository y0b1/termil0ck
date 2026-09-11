// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Termilock",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Termilock", targets: ["Termilock"])
    ],
    targets: [
        .executableTarget(
            name: "Termilock",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AuthenticationServices"),
                .linkedFramework("CryptoKit"),
                .linkedFramework("LocalAuthentication"),
                .linkedFramework("Security")
            ]
        ),
        .testTarget(
            name: "TermilockTests",
            dependencies: ["Termilock"]
        )
    ]
)
