import AVFoundation
import Foundation

// MARK: - Three original UI tones synthesized via AVAudioEngine

@MainActor
final class VegaSoundDesign {
    static let shared = VegaSoundDesign()
    private init() {}

    private let engine = AVAudioEngine()
    private var isSetup = false

    // MARK: - Public sounds

    func playListenStart() { play(frequency: 880, duration: 0.10, amplitude: 0.25, envelope: .rise) }
    func playResponseReady() { play(frequency: 660, duration: 0.14, amplitude: 0.22, envelope: .fall) }
    func playAlert() { play(frequency: 440, duration: 0.18, amplitude: 0.30, envelope: .pulse) }

    // MARK: - Tone synthesis

    private enum Envelope { case rise, fall, pulse }

    private func play(frequency: Float, duration: Double, amplitude: Float, envelope: Envelope) {
        let sampleRate = Float(engine.outputNode.outputFormat(forBus: 0).sampleRate)
        guard sampleRate > 0 else { return }

        let frameCount = AVAudioFrameCount(sampleRate * Float(duration))
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!,
            frameCapacity: frameCount
        ) else { return }

        buffer.frameLength = frameCount
        guard let data = buffer.floatChannelData?[0] else { return }

        for i in 0..<Int(frameCount) {
            let t     = Float(i) / sampleRate
            let phase = 2 * Float.pi * frequency * t

            let env: Float
            let progress = Float(i) / Float(frameCount)
            switch envelope {
            case .rise:  env = min(progress * 3, 1) * (1 - progress)
            case .fall:  env = (1 - progress)
            case .pulse: env = sin(Float.pi * progress)
            }

            data[i] = sin(phase) * amplitude * env
        }

        setup()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: buffer.format)

        player.scheduleBuffer(buffer, at: nil, options: .interrupts) {
            Task { @MainActor [weak self] in
                self?.engine.detach(player)
            }
        }

        if !engine.isRunning { try? engine.start() }
        player.play()
    }

    private func setup() {
        guard !isSetup else { return }
        isSetup = true
        try? engine.start()
    }
}
