import Foundation

/// Where a shop customer is in its visit, as far as which way it faces.
public enum CustomerStage: Equatable, Sendable {
    case approaching   // walking in toward the counter
    case waiting       // parked at the counter: being served, bubble up
    case leaving       // walking back out, after buying or giving up
}

/// Which side of the sprite the camera sees.
public enum CustomerFacing: Equatable, Sendable {
    /// Walking away from the camera, or standing facing the counter.
    case back
    /// Walking toward the camera.
    case front

    /// Customers enter up-left away from the camera and leave back along the
    /// same lane toward it, so only the leg out shows the face. The spawner
    /// plays the reaction and then sets `.leaving` in the same step, so the
    /// reaction pop plays as the customer turns to face the camera.
    public init(stage: CustomerStage) {
        self = stage == .leaving ? .front : .back
    }
}
