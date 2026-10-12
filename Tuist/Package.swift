// swift-tools-version: 6.0
import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings

    let packageSettings = PackageSettings(
        productTypes: [:]
    )
#endif

let package = Package(
    name: "BomDongTycoon",
    dependencies: [
        .package(
            url: "https://github.com/googleads/swift-package-manager-google-mobile-ads",
            from: "11.0.0"
        ),
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk",
            .upToNextMinor(from: "12.18.0")
        )
    ]
)
