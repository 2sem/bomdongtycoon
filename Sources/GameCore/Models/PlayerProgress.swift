import Foundation

public struct PlayerProgress: Codable {
    public var isFirstLaunch: Bool = true
    public var lastActiveDate: Date? = nil
    public var seasonStartDate: Date? = nil
    public var totalEarned: Double = 0

    public init() {}
}
