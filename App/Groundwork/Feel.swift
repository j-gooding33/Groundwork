import AVFoundation
import UIKit
import GroundworkView

/// Haptics and placeholder sound, all generated in code so the game makes
/// noise before real audio exists. Every cue the design asks for has a hook.
@MainActor
final class Feel {
    var soundOn = true {
        didSet { if !soundOn { silenceLoops() } }
    }
    var hapticsOn = true
    /// Music layers playing, 1 to 4: each goal and new home adds one.
    var musicLayers = 1

    private let engine = AVAudioEngine()
    private let format: AVAudioFormat
    private var cues: [SoundCue: (player: AVAudioPlayerNode, buffer: AVAudioPCMBuffer)] = [:]
    private let hum = AVAudioPlayerNode()
    private let humSpeed = AVAudioUnitVarispeed()
    private var pads: [AVAudioPlayerNode] = []
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let notify = UINotificationFeedbackGenerator()
    private var started = false

    static let sampleRate = 44_100.0
    /// C3, G3, E4, B4.
    static let padNotes = [130.81, 196.0, 329.63, 493.88]

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1)!
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        for cue in SoundCue.allCases {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            cues[cue] = (player, Self.synth(cue, format: format))
        }
        engine.attach(hum)
        engine.attach(humSpeed)
        engine.connect(hum, to: humSpeed, format: format)
        engine.connect(humSpeed, to: engine.mainMixerNode, format: format)
        // A soft pad: root, fifth, third and seventh, one more layer per milestone.
        for _ in Self.padNotes {
            let pad = AVAudioPlayerNode()
            engine.attach(pad)
            engine.connect(pad, to: engine.mainMixerNode, format: format)
            pad.volume = 0
            pads.append(pad)
        }
        do {
            try engine.start()
            started = true
            hum.volume = 0
            hum.scheduleBuffer(Self.humBuffer(format: format), at: nil, options: .loops, completionHandler: nil)
            hum.play()
            for (pad, frequency) in zip(pads, Self.padNotes) {
                pad.scheduleBuffer(Self.padBuffer(frequency, format: format), at: nil, options: .loops, completionHandler: nil)
                pad.play()
            }
        } catch {
            started = false
        }
        light.prepare()
    }

    func play(_ cue: SoundCue) {
        guard soundOn, started, let entry = cues[cue] else { return }
        entry.player.scheduleBuffer(entry.buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !entry.player.isPlaying { entry.player.play() }
    }

    func haptic(_ haptic: Haptic) {
        guard hapticsOn else { return }
        switch haptic {
        case .light: light.impactOccurred()
        case .double: notify.notificationOccurred(.success)
        case .warning: notify.notificationOccurred(.warning)
        }
    }

    /// The machine hum follows how much is running; the pad follows milestones.
    func update(mix: AudioMix) {
        guard soundOn, started else { return }
        hum.volume = Float(mix.humVolume * 0.35)
        humSpeed.rate = Float(mix.humPitch)
        for (i, pad) in pads.enumerated() {
            pad.volume = i < musicLayers ? 0.06 : 0
        }
    }

    private func silenceLoops() {
        hum.volume = 0
        for pad in pads { pad.volume = 0 }
    }

    // MARK: Synthesis

    private static func buffer(seconds: Double, format: AVAudioFormat, _ sample: (Double) -> Double) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(seconds * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let data = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            data[i] = Float(max(-1, min(1, sample(Double(i) / sampleRate))))
        }
        return buffer
    }

    private static func tone(_ f: Double, _ t: Double) -> Double { sin(2 * .pi * f * t) }

    private static func synth(_ cue: SoundCue, format: AVAudioFormat) -> AVAudioPCMBuffer {
        switch cue {
        case .place:
            return buffer(seconds: 0.14, format: format) { t in tone(140 - 300 * t, t) * exp(-t * 28) * 0.7 }
        case .remove:
            var seed: UInt64 = 7
            return buffer(seconds: 0.12, format: format) { t in
                seed = seed &* 6364136223846793005 &+ 1
                return (Double(seed >> 40) / Double(1 << 24) - 0.5) * exp(-t * 30) * 0.6
            }
        case .belt:
            return buffer(seconds: 0.12, format: format) { t in tone(300 + 1200 * t, t) * exp(-t * 18) * 0.35 }
        case .pickup:
            return buffer(seconds: 0.07, format: format) { t in tone(880, t) * exp(-t * 40) * 0.35 }
        case .drop:
            return buffer(seconds: 0.08, format: format) { t in tone(660, t) * exp(-t * 35) * 0.35 }
        case .produce:
            return buffer(seconds: 0.05, format: format) { t in tone(1200, t) * exp(-t * 70) * 0.25 }
        case .chime:
            return buffer(seconds: 0.9, format: format) { t in
                (tone(1318.5, t) + 0.5 * tone(1975.5, t)) * exp(-t * 5) * 0.3
            }
        case .blocked:
            return buffer(seconds: 0.3, format: format) { t in tone(t < 0.15 ? 220 : 196, t) * exp(-t * 8) * 0.25 }
        case .unblocked:
            return buffer(seconds: 0.2, format: format) { t in tone(t < 0.1 ? 196 : 262, t) * exp(-t * 10) * 0.25 }
        case .goal:
            return buffer(seconds: 1.4, format: format) { t in
                let notes = [523.25, 659.25, 783.99, 1046.5]
                let i = min(Int(t / 0.18), notes.count - 1)
                return tone(notes[i], t) * exp(-(t - Double(i) * 0.18) * 4) * 0.35
            }
        case .tutorial:
            return buffer(seconds: 0.4, format: format) { t in tone(990, t) * exp(-t * 9) * 0.2 }
        case .home:
            return buffer(seconds: 1.0, format: format) { t in
                (tone(392, t) + tone(493.88, t) + tone(587.33, t)) / 3 * exp(-t * 3) * 0.35
            }
        }
    }

    /// One second of low hum that loops cleanly (whole cycles of 110 Hz).
    private static func humBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        buffer(seconds: 1, format: format) { t in (tone(110, t) * 0.7 + tone(220, t) * 0.2 + tone(55, t) * 0.3) * 0.5 }
    }

    /// Four seconds of a soft tone with a slow swell, looping cleanly.
    private static func padBuffer(_ f: Double, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let cycles = (f * 4).rounded()
        return buffer(seconds: 4, format: format) { t in
            tone(cycles / 4, t) * (0.6 + 0.4 * sin(2 * .pi * t / 4)) * 0.5
        }
    }
}
