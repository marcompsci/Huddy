import AVFoundation
import Foundation

// MARK: - Protocol

@MainActor
protocol VoiceOutputting: AnyObject {
    func speak(_ text: String) async
    func stop()
    var onAmplitude: ((CGFloat) -> Void)? { get set }
}

// MARK: - System voice (AVSpeechSynthesizer)

@MainActor
final class SystemVoice: NSObject, VoiceOutputting, AVSpeechSynthesizerDelegate {

    private let synthesizer     = AVSpeechSynthesizer()
    private var amplitudeTimer: Task<Void, Never>?
    var onAmplitude:            ((CGFloat) -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) async {
        stop()

        let utterance           = AVSpeechUtterance(string: text)
        utterance.rate          = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.pitchMultiplier = 1.0

        // Prefer a high-quality voice; fall back to locale default.
        utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.enhanced.en-US.Evan")
            ?? AVSpeechSynthesisVoice(language: "en-US")

        synthesizer.speak(utterance)
        startAmplitudePolling()
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        amplitudeTimer?.cancel()
        onAmplitude?(0)
    }

    // MARK: - Pseudo-amplitude (AVSpeechSynthesizer has no real output metering)

    private func startAmplitudePolling() {
        amplitudeTimer?.cancel()
        amplitudeTimer = Task { @MainActor [weak self] in
            var phase = 0.0
            while !Task.isCancelled {
                phase += 0.15
                let amp = CGFloat(0.35 + 0.45 * abs(sin(phase)))
                self?.onAmplitude?(amp)
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.amplitudeTimer?.cancel()
            self?.onAmplitude?(0)
        }
    }
}

// MARK: - Cloud voice stub (Step 7: replaced with backend TTS stream)

@MainActor
final class CloudVoice: VoiceOutputting {
    var onAmplitude: ((CGFloat) -> Void)?
    private let fallback = SystemVoice()

    func speak(_ text: String) async {
        fallback.onAmplitude = onAmplitude
        await fallback.speak(text)
    }

    func stop() { fallback.stop() }
}
