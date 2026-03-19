import ProjectDescription

let skAdNetworkIDs: [String] = [
    "cstr6suwn9", "4fzdc2evr5", "2fnua5tdw4", "ydx93a7ass", "p78axxw29g",
    "v72qych5uu", "ludvb6z3bs", "cp8zw746q7", "3sh42y64q3", "c6k4g5qg8m",
    "s39g8k73mm", "wg4vff78zm", "3qy4746246", "f38h382jlk", "hs6bdukanm",
    "mlmmfzh3r3", "v4nxqhlyqp", "wzmmz9fp6w", "su67r6k2v3", "yclnxrl5pm",
    "t38b2kh725", "7ug5zh24hu", "gta9lk7p23", "vutu7akeur", "y5ghdn5j9k",
    "v9wttpbfk9", "n38lu8286q", "47vhws6wlr", "kbd757ywx3", "9t245vhmpl",
    "a2p9lx4jpn", "22mmun2rn5", "44jx6755aq", "k674qkevps", "4468km3ulz",
    "2u9pt9hc89", "8s468mfl3y", "klf5c3l5u5", "ppxm28t8ap", "kbmxgpxpgc",
    "uw77j35x4d", "578prtvx9j", "4dzt52r2t5", "tl55sbb4fm", "c3frkrj4fj",
    "e5fvkxwrpn", "8c4e2ghe7u", "3rd42ekr43", "97r2b46745", "3qcr597p9d"
]

let skAdNetworks: [Plist.Value] = skAdNetworkIDs
    .map { .dictionary(["SKAdNetworkIdentifier": .string("\($0).skadnetwork")]) }

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
                "GADApplicationIdentifier": "ca-app-pub-9684378399371172~8825318408",
                "SKAdNetworkItems": .array(skAdNetworks)
            ]),
            sources: ["Sources/App/**"],
            resources: ["Resources/**"],
            dependencies: [
                .target(name: "GameCore"),
                .target(name: "GameUI"),
                .external(name: "GoogleMobileAds")
            ],
            settings: .settings(base: ["OTHER_LDFLAGS": "$(inherited) -ObjC"])
        )
    ],
    schemes: [
        .scheme(
            name: "GameCoreTests",
            testAction: .targets(["GameCoreTests"])
        )
    ]
)
