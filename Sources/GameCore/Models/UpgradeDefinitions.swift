import Foundation

public struct UpgradeDefinition {
    public let name: String
    public let coinCost: Double
    public let earningsMultiplier: Double
    public let description: String

    public init(name: String, coinCost: Double, earningsMultiplier: Double, description: String) {
        self.name = name
        self.coinCost = coinCost
        self.earningsMultiplier = earningsMultiplier
        self.description = description
    }
}

public enum UpgradeDefinitions {
    public static let menu: [UpgradeDefinition] = [
        .init(name: "겉절이",     coinCost: 0,      earningsMultiplier: 1.0, description: "기본 메뉴"),
        .init(name: "봄동김치",   coinCost: 1_000,  earningsMultiplier: 2.5, description: "인기 메뉴"),
        .init(name: "봄동비빔밥", coinCost: 10_000, earningsMultiplier: 6.0, description: "시그니처 메뉴")
    ]

    public static let staff: [UpgradeDefinition] = [
        .init(name: "알바생",       coinCost: 500,    earningsMultiplier: 1.5, description: "첫 번째 직원"),
        .init(name: "경력 아주머니", coinCost: 3_000,  earningsMultiplier: 3.0, description: "베테랑"),
        .init(name: "봄동 요리사",  coinCost: 15_000, earningsMultiplier: 7.0, description: "전문가")
    ]

    public static let stall: [UpgradeDefinition] = [
        .init(name: "포장마차",   coinCost: 0,      earningsMultiplier: 1.0, description: "시작 가게"),
        .init(name: "분식집",     coinCost: 5_000,  earningsMultiplier: 2.0, description: "업그레이드"),
        .init(name: "봄동 전문점", coinCost: 25_000, earningsMultiplier: 5.0, description: "최고급")
    ]

    public static let location: [UpgradeDefinition] = [
        .init(name: "골목", coinCost: 0,      earningsMultiplier: 1.0, description: "조용한 골목"),
        .init(name: "시장", coinCost: 8_000,  earningsMultiplier: 2.5, description: "사람 많은 시장"),
        .init(name: "강남", coinCost: 50_000, earningsMultiplier: 8.0, description: "핫플레이스")
    ]
}
