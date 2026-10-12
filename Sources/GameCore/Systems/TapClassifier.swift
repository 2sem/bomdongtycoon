import CoreGraphics

/// Tells a tap from a pan for one touch, in **screen (view) points**.
///
/// Feed it view-space locations only. Scene coordinates are wrong for this:
/// the camera follows the finger, so a pan's start and end scene points
/// nearly coincide and the pan would read as a tap.
///
/// Travel is the accumulated path length, not start-to-end displacement, so a
/// drag that leaves and returns to its start is still a pan. Duration is
/// deliberately ignored: a held, stationary touch is still a tap.
public struct TapClassifier: Equatable {

    /// Total movement at or below this (screen points) still counts as a tap.
    public let slop: CGFloat

    private var last: CGPoint?
    private var travel: CGFloat = 0

    public init(slop: CGFloat = 10) {
        self.slop = slop
    }

    public mutating func begin(at point: CGPoint) {
        last = point
        travel = 0
    }

    public mutating func move(to point: CGPoint) {
        guard let previous = last else { return }
        travel += Self.distance(previous, point)
        last = point
    }

    /// Finishes the touch. `true` when the whole gesture stayed within `slop`.
    /// `false` if there was no matching `begin` or the touch moved too far.
    public mutating func end(at point: CGPoint) -> Bool {
        guard last != nil else { return false }
        move(to: point)
        defer { cancel() }
        return travel <= slop
    }

    public mutating func cancel() {
        last = nil
        travel = 0
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
