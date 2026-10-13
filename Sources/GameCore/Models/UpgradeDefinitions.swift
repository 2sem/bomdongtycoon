import Foundation

// MARK: - UpgradeDefinition

public struct UpgradeDefinition {
    public let name: String
    public let coinCost: Double
    public let description: String
    /// Multiplier on a worker's speed (staff, farmer, veteran alba)
    public let productionMultiplier: Double
    /// Multiplier on coins-per-item sale price (menu)
    public let priceMultiplier: Double
    /// Maximum stock capacity (stall upgrades only; 0 = not applicable)
    public let maxStock: Int
    /// Staff or features unlocked by purchasing this upgrade
    public let unlocks: String?

    public init(
        name: String,
        coinCost: Double,
        description: String,
        productionMultiplier: Double = 1.0,
        priceMultiplier: Double = 1.0,
        maxStock: Int = 0,
        unlocks: String? = nil
    ) {
        self.name = name
        self.coinCost = coinCost
        self.description = description
        self.productionMultiplier = productionMultiplier
        self.priceMultiplier = priceMultiplier
        self.maxStock = maxStock
        self.unlocks = unlocks
    }

    /// Human-readable effect summary for the upgrade sheet
    public var displayEffect: String {
        var parts: [String] = []
        if priceMultiplier != 1.0 {
            parts.append("₩ ×\(String(format: "%.1f", priceMultiplier)) 판매가")
        }
        if maxStock > 0 {
            parts.append("🥬 \(maxStock)개 보관")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - LocationDefinition

public struct LocationDefinition {
    public let name: String
    public let coinCost: Double
    public let description: String
    /// Stall tier the player must already own before moving here.
    public let requiredStallTier: Int
    /// Multiplier on every sale price (live, offline and ads inherit it).
    public let saleMultiplier: Double
    public let unlocks: String?
    /// Shown while `requiredStallTier` is unmet.
    public let lockedReason: String?
    /// Particle-correct destination form for the alert and goal bar ("시장으로").
    public let destination: String

    public var displayEffect: String { "판매 수익 x\(Int(saleMultiplier))" }
}

public enum UpgradeDefinitions {

    /// Locations — one forward-only tier that multiplies sale price. Append a row for a new one.
    public static let location: [LocationDefinition] = [
        .init(name: "골목", coinCost: 0, description: "한적한 골목 어귀, 봄동 장사의 시작",
              requiredStallTier: 0, saleMultiplier: 1.0, unlocks: nil, lockedReason: nil,
              destination: "골목으로"),
        .init(name: "시장", coinCost: 40_000, description: "사람 북적이는 전통시장 한복판",
              requiredStallTier: 1, saleMultiplier: 2.0, unlocks: "시장 풍경과 새 손님",
              lockedReason: "봄동 식당이 필요해요", destination: "시장으로"),
        .init(name: "강남", coinCost: 200_000, description: "유동 인구 가득한 강남 대로변",
              requiredStallTier: 2, saleMultiplier: 4.0, unlocks: "강남 풍경과 새 손님",
              lockedReason: "봄동 전문점이 필요해요", destination: "강남으로")
    ]

    /// Menu upgrades — increase price per item sold
    public static let menu: [UpgradeDefinition] = [
        .init(name: "겉절이",     coinCost: 0,      description: "기본 메뉴",      priceMultiplier: 1.0),
        .init(name: "봄동김치",   coinCost: 1_000,  description: "인기 메뉴",      priceMultiplier: 2.5),
        .init(name: "봄동비빔밥", coinCost: 10_000, description: "시그니처 메뉴",  priceMultiplier: 6.0)
    ]

    /// Staff tiers — each hire's cook speed
    public static let staff: [UpgradeDefinition] = [
        .init(name: "알바생",      coinCost: 500,    description: "밭·계산대·주방 모두 가능", productionMultiplier: 2.0),
        .init(name: "이모님",      coinCost: 3_000,  description: "계산대·주방 배치 가능",     productionMultiplier: 4.0),
        .init(name: "봄동 요리사", coinCost: 15_000, description: "주방 전담, 최고 속도",       productionMultiplier: 7.0)
    ]

    /// Stall upgrades — increase maximum stock capacity
    public static let stall: [UpgradeDefinition] = [
        .init(name: "포장마차",    coinCost: 0,      description: "시작 가게", maxStock: 15),
        .init(name: "봄동 식당",    coinCost: 5_000,  description: "재고 30개", maxStock: 30, unlocks: "이모님 · 농부 고용 가능"),
        .init(name: "봄동 전문점", coinCost: 25_000, description: "재고 60개", maxStock: 60, unlocks: "봄동 요리사 고용 가능")
    ]

    /// Stall tier a staff hire needs: 알바생 (tier 1) is open from the start,
    /// 이모님 needs 봄동 식당 and 봄동 요리사 needs 봄동 전문점. The hire tab and the
    /// goal selector both read this so they cannot disagree.
    public static func requiredStallTier(forStaffTier staffTier: Int) -> Int {
        max(staffTier - 1, 0)
    }

    public static func isStaffTierUnlocked(_ staffTier: Int, stallTier: Int) -> Bool {
        staffTier >= 1 && staffTier <= staff.count
            && stallTier >= requiredStallTier(forStaffTier: staffTier)
    }

    /// Farmer staff — farm-only, 2× growth speed
    public static let farmer: [UpgradeDefinition] = [
        .init(name: "농부", coinCost: 2_000, description: "농장 전문 — 빠른 수확", productionMultiplier: 2.0)
    ]

    /// Veteran alba staff — farm-only, 1.4× growth speed
    public static let veteranAlba: [UpgradeDefinition] = [
        .init(name: "고참 알바", coinCost: 800, description: "농장·계산대 배치 가능", productionMultiplier: 1.4)
    ]
}
