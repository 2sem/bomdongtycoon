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
        case snowStart = "sfx_snow_start"
        case leavesStart = "sfx_leaves_start"
        case petalsStart = "sfx_petals_start"
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
        // Activating the session can block for a while on a cold launch; nothing plays before it is ready.
        DispatchQueue.global(qos: .utility).async {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.ambient, mode: .default)
            try? session.setActive(true)
        }
    }

    /// `volume` below 1 is for cues that should not startle, like the golden-crop chime that
    /// plays on its own rather than from a tap. `rate` shifts pitch and speed together (1 = as
    /// recorded): a run of taps climbs it so the player hears the hurry building.
    func play(_ effect: Effect, volume: Float = 1, rate: Float = 1) {
        guard isEnabled else { return }
        let pool = pools[effect] ?? makePool(effect)
        guard let player = pool.first(where: { !$0.isPlaying }) ?? pool.first else { return }
        player.currentTime = 0
        player.volume = volume
        player.rate = rate
        player.play()
    }

    private func makePool(_ effect: Effect) -> [AVAudioPlayer] {
        guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") else {
            pools[effect] = []
            return []
        }
        let players = (0..<Self.voicesPerEffect).compactMap { _ -> AVAudioPlayer? in
            let player = try? AVAudioPlayer(contentsOf: url)
            player?.enableRate = true
            player?.prepareToPlay()
            return player
        }
        pools[effect] = players
        return players
    }
}
