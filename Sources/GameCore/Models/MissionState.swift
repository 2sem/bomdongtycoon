import Foundation

public enum MissionKind: String, Codable, CaseIterable {
    case serveCustomers, harvest, earnCoins, cookDishes, triggerFever, serveGourmets
}

public struct Mission: Codable, Equatable, Identifiable {
    /// "<dayKey>-<kind>": stable, and unique because a day never repeats a kind.
    public let id: String
    public let kind: MissionKind
    public let target: Int
    public var progress: Int
    public var isClaimed: Bool
    /// Fixed at roll time so the number shown is the number paid.
    public let reward: Double

    public var isComplete: Bool { progress >= target }

    public init(id: String, kind: MissionKind, target: Int, progress: Int = 0, isClaimed: Bool = false, reward: Double) {
        self.id = id
        self.kind = kind
        self.target = target
        self.progress = progress
        self.isClaimed = isClaimed
        self.reward = reward
    }

    private enum CodingKeys: String, CodingKey { case id, kind, target, progress, isClaimed, reward }

    /// `id`, `kind` and `target` have no sane default, so a mission missing one throws and is
    /// dropped by the lossy array decode.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(String.self, forKey: .id)
        kind      = try c.decode(MissionKind.self, forKey: .kind)
        target    = max(1, try c.decode(Int.self, forKey: .target))
        progress  = max(0, c.decodeOrDefault(.progress, 0))
        isClaimed = c.decodeOrDefault(.isClaimed, false)
        reward    = max(0, c.decodeOrDefault(.reward, 100.0))
    }
}

/// Persisted under `SaveBlob.missions`. `dayKey` is yyyymmdd of the local day the missions were rolled for.
public struct MissionState: Codable, Equatable {
    public var dayKey: Int = 0
    public var missions: [Mission] = []

    public init() {}

    public init(dayKey: Int, missions: [Mission]) {
        self.dayKey = dayKey
        self.missions = missions
    }

    private enum CodingKeys: String, CodingKey { case dayKey, missions }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dayKey   = c.decodeOrDefault(.dayKey, 0)
        missions = c.decodeLossyArray(Mission.self, forKey: .missions) ?? []
    }
}
