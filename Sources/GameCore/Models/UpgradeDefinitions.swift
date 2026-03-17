import Foundation

// MARK: - FarmUpgradeDefinition

public struct FarmUpgradeDefinition {
    public let name: String
    public let coinCost: Double
    public let description: String
    public let plotCount: Int
    public let growthMultiplier: Double
    public let harvestYield: Int

    public var displayEffect: String {
        "🌱 \(plotCount)칸 · ×\(String(format: "%.1f", growthMultiplier)) 성장 · 수확 \(harvestYield)개"
    }
}

// MARK: - UpgradeDefinition

public struct UpgradeDefinition {
    public let name: String
    public let coinCost: Double
    public let description: String
    /// Multiplier on items-per-second production rate (staff, location)
    public let productionMultiplier: Double
    /// Multiplier on coins-per-item sale price (menu, location)
    public let priceMultiplier: Double
    /// Maximum stock capacity (stall upgrades only; 0 = not applicable)
    public let maxStock: Int

    public init(
        name: String,
        coinCost: Double,
        description: String,
        productionMultiplier: Double = 1.0,
        priceMultiplier: Double = 1.0,
        maxStock: Int = 0
    ) {
        self.name = name
        self.coinCost = coinCost
        self.description = description
        self.productionMultiplier = productionMultiplier
        self.priceMultiplier = priceMultiplier
        self.maxStock = maxStock
    }

    /// Human-readable effect summary for the upgrade sheet
    public var displayEffect: String {
        var parts: [String] = []
        if productionMultiplier != 1.0 {
            parts.append("🍳 \(Int(round(productionMultiplier)))개 일괄조리")
        }
        if priceMultiplier != 1.0 {
            parts.append("₩ ×\(String(format: "%.1f", priceMultiplier)) 판매가")
        }
        if maxStock > 0 {
            parts.append("🥬 \(maxStock)개 보관")
        }
        return parts.joined(separator: " · ")
    }
}

public enum UpgradeDefinitions {

    /// Menu upgrades — increase price per item sold
    public static let menu: [UpgradeDefinition] = [
        .init(name: "겉절이",     coinCost: 0,      description: "기본 메뉴",      priceMultiplier: 1.0),
        .init(name: "봄동김치",   coinCost: 1_000,  description: "인기 메뉴",      priceMultiplier: 2.5),
        .init(name: "봄동비빔밥", coinCost: 10_000, description: "시그니처 메뉴",  priceMultiplier: 6.0)
    ]

    /// Staff upgrades — increase items produced per batch cook
    public static let staff: [UpgradeDefinition] = [
        .init(name: "알바생",      coinCost: 500,    description: "조리 1개씩 도와줘요", productionMultiplier: 2.0),
        .init(name: "이모님",      coinCost: 3_000,  description: "빠르게 조리해요",     productionMultiplier: 4.0),
        .init(name: "봄동 요리사", coinCost: 15_000, description: "전문 조리사",         productionMultiplier: 7.0)
    ]

    /// Stall upgrades — increase maximum stock capacity
    public static let stall: [UpgradeDefinition] = [
        .init(name: "포장마차",    coinCost: 0,      description: "시작 가게", maxStock: 20),
        .init(name: "봄동 식당",    coinCost: 5_000,  description: "업그레이드", maxStock: 50),
        .init(name: "봄동 전문점", coinCost: 25_000, description: "최고급",    maxStock: 150)
    ]

/// Farm upgrades — increase plot count, growth speed, and harvest yield
    public static let farm: [FarmUpgradeDefinition] = [
        .init(name: "텃밭",     coinCost: 0,      description: "작은 시작",  plotCount: 2, growthMultiplier: 1.0, harvestYield: 1),
        .init(name: "주말농장", coinCost: 3_000,  description: "더 넓은 밭", plotCount: 3, growthMultiplier: 1.5, harvestYield: 2),
        .init(name: "봄동농장", coinCost: 20_000, description: "전문 농장",  plotCount: 5, growthMultiplier: 2.5, harvestYield: 3),
    ]
}
