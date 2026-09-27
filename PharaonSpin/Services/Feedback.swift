import AVFoundation
import UIKit

/// Short synthesized cues. Deliberately no coin-drop or cash-register sounds.
final class SoundEngine {
    enum Cue: CaseIterable {
        case tap, reelStop, tick, win, bigWin, bonus
    }

    private let engine = AVAudioEngine()
    private let players: [AVAudioPlayerNode]
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var nextPlayer = 0
    private let format: AVAudioFormat
    private var started = false

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        players = (0..<6).map { _ in AVAudioPlayerNode() }
        for player in players {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
        engine.mainMixerNode.outputVolume = 0.55
        for cue in Cue.allCases {
            buffers[cue] = makeBuffer(for: cue)
        }
    }

    func play(_ cue: Cue) {
        guard let buffer = buffers[cue] else { return }
        if !started { start() }
        guard started else { return }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.scheduleBuffer(buffer, at: nil)
        player.play()
    }

    private func start() {
        do {
            // Ambient: respects the silent switch and mixes with the player's music.
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            started = true
        } catch {
            started = false
        }
    }

    private func makeBuffer(for cue: Cue) -> AVAudioPCMBuffer? {
        // (frequency Hz, start s, length s)
        let notes: [(Double, Double, Double)]
        var volume = 0.5
        switch cue {
        case .tap: notes = [(880, 0, 0.05)]; volume = 0.25
        case .reelStop: notes = [(196, 0, 0.09)]; volume = 0.5
        case .tick: notes = [(1_400, 0, 0.025)]; volume = 0.18
        case .win: notes = [(523.25, 0, 0.12), (659.25, 0.08, 0.12), (783.99, 0.16, 0.22)]
        case .bigWin: notes = [(523.25, 0, 0.14), (659.25, 0.1, 0.14), (783.99, 0.2, 0.14), (1_046.5, 0.3, 0.4)]
        case .bonus: notes = [(392, 0, 0.1), (523.25, 0.1, 0.1), (659.25, 0.2, 0.1), (783.99, 0.3, 0.1), (1_046.5, 0.4, 0.35)]
        }
        let length = notes.map { $0.1 + $0.2 }.max() ?? 0.1
        let frames = AVAudioFrameCount(format.sampleRate * length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        let rate = format.sampleRate
        for i in 0..<Int(frames) { channel[i] = 0 }
        for (frequency, start, duration) in notes {
            let first = Int(start * rate)
            let count = Int(duration * rate)
            for n in 0..<count where first + n < Int(frames) {
                let t = Double(n) / rate
                let attack = min(1, t / 0.004)
                let decay = exp(-t / (duration * 0.35))
                // Sine plus a soft octave for a bell-like tone.
                let sample = sin(2 * .pi * frequency * t) + 0.3 * sin(4 * .pi * frequency * t)
                channel[first + n] += Float(sample * attack * decay * volume * 0.6)
            }
        }
        return buffer
    }
}

enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

/// Sound and vibration gated by the player's settings.
@MainActor
final class Feedback {
    private let settings: SettingsStore
    private lazy var sound = SoundEngine()

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func play(_ cue: SoundEngine.Cue) {
        guard settings.soundOn else { return }
        sound.play(cue)
    }

    func tap() {
        play(.tap)
        if settings.vibrationOn { Haptics.light() }
    }

    func reelStop() {
        play(.reelStop)
        if settings.vibrationOn { Haptics.light() }
    }

    func tick() {
        play(.tick)
    }

    func win(big: Bool) {
        play(big ? .bigWin : .win)
        if settings.vibrationOn { Haptics.success() }
    }

    func bonus() {
        play(.bonus)
        if settings.vibrationOn { Haptics.success() }
    }
}
