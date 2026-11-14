import AVFoundation

/// Plays the bundled `.wav` effects. `.ambient` keeps the silent switch and other apps' audio in charge.
@MainActor
final class DotSound {
    static let shared = DotSound()

    enum Effect: String, CaseIterable {
        case tap = "sfx_tap"
        case plant = "sfx_plant"
        case harvest = "sfx_harvest"
        case golden = "sfx_golden"
        case cookDone = "sfx_cook_done"
        case coin = "sfx_coin"
        case purchase = "sfx_purchase"
        case error = "sfx_error"
        case feverStart = "sfx_fever_start"
        case missionDone = "sfx_mission_done"
        case rainStart = "sfx_rain_start"
    }

    static let enabledKey = "settings.soundEnabled"

    /// Default on. The UI phase binds its toggle to this.
    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    private var pools: [Effect: [AVAudioPlayer]] = [:]
    private static let voicesPerEffect = 3

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func play(_ effect: Effect) {
        guard isEnabled else { return }
        let pool = pools[effect] ?? makePool(effect)
        guard let player = pool.first(where: { !$0.isPlaying }) ?? pool.first else { return }
        player.currentTime = 0
        player.play()
    }

    private func makePool(_ effect: Effect) -> [AVAudioPlayer] {
        guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") else {
            pools[effect] = []
            return []
        }
        let players = (0..<Self.voicesPerEffect).compactMap { _ -> AVAudioPlayer? in
            let player = try? AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            return player
        }
        pools[effect] = players
        return players
    }
}
