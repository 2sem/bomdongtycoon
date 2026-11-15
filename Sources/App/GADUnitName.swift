import GameCore

/// Keys of the `GADUnitIdentifiers` dictionary in Info.plist (see Project.swift), which holds the
/// production ad unit ids. GADManager looks them up by raw value.
enum GADUnitName: String {
    case launch = "Launch"
    case offlineReward = "OfflineReward"
    case feverReward = "FeverReward"
    case missionReward = "MissionReward"
    case boostReward = "BoostReward"
    case giftReward = "GiftReward"
}

extension AdPlacement {
    var unitName: GADUnitName {
        switch self {
        case .offline: .offlineReward
        case .fever: .feverReward
        case .mission: .missionReward
        case .boost: .boostReward
        case .gift: .giftReward
        }
    }
}
