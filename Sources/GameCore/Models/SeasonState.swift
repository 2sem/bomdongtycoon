import Foundation

public enum Season: String, Codable {
    case spring = "봄"
    case summer = "여름"
    case autumn = "가을"
    case winter = "겨울"
}

public struct SeasonState: Codable {
    public var currentSeason: Season = .spring
    public var seasonStartDate: Date = Date()
    public var daysRemaining: Int = 30

    public init() {}
}
