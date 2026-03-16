import ProjectDescription

let project = Project(
    name: "BomDongTycoon",
    targets: [
        .target(
            name: "GameCore",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.leesam.bomdongtycoon.gamecore",
            deploymentTargets: .iOS("17.0"),
            sources: ["Sources/GameCore/**"]
        ),
        .target(
            name: "GameCoreTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.leesam.bomdongtycoon.gamecore.tests",
            deploymentTargets: .iOS("17.0"),
            sources: ["Tests/GameCoreTests/**"],
            dependencies: [.target(name: "GameCore")]
        ),
        .target(
            name: "GameUI",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.leesam.bomdongtycoon.gameui",
            deploymentTargets: .iOS("17.0"),
            sources: ["Sources/GameUI/**"],
            dependencies: [.target(name: "GameCore")]
        ),
        .target(
            name: "BomDongTycoon",
            destinations: .iOS,
            product: .app,
            bundleId: "com.leesam.bomdongtycoon",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchStoryboardName": "LaunchScreen",
                "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
                "NSUserNotificationUsageDescription": "봄동 가게 알림을 보내드려요 🥬",
                "GADApplicationIdentifier": "ca-app-pub-9684378399371172~8825318408"
            ]),
            sources: ["Sources/App/**"],
            resources: ["Resources/**"],
            dependencies: [
                .target(name: "GameCore"),
                .target(name: "GameUI"),
                .xcframework(path: "Tuist/.build/artifacts/swift-package-manager-google-mobile-ads/GoogleMobileAds/GoogleMobileAds.xcframework")
            ]
        )
    ],
    schemes: [
        .scheme(
            name: "GameCoreTests",
            testAction: .targets(["GameCoreTests"])
        )
    ]
)
