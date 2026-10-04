import AVFoundation
import Speech
import Foundation

// MARK: - Protocol

/// Streams recognized text as partials and a single final string.
@MainActor
protocol SpeechTranscribing: AnyObject {
    func start(
        onPartial: @escaping (String) -> Void,
        onFinal:   @escaping (String) -> Void,
        onError:   @escaping (Error)  -> Void
    ) throws
    func stop()
}

// MARK: - SFSpeechRecognizer implementation (iOS 17+)

@MainActor
final class SFTranscriber: SpeechTranscribing {

    private var recognizer: SFSpeechRecognizer?
    private var request:    SFSpeechAudioBufferRecognitionRequest?
    private var task:       SFSpeechRecognitionTask?
    private var engine:     AVAudioEngine?

    // 1.2 s silence timer for tap-to-talk auto-submit
    private var silenceTimer: Task<Void, Never>?
    private var lastPartial   = ""
    private var onFinal:      ((String) -> Void)?
    private var onPartial:    ((String) -> Void)?
    private var onError:      ((Error) -> Void)?

    func start(
        onPartial: @escaping (String) -> Void,
        onFinal:   @escaping (String) -> Void,
        onError:   @escaping (Error)  -> Void
    ) throws {
        self.onPartial = onPartial
        self.onFinal   = onFinal
        self.onError   = onError

        let rec = SFSpeechRecognizer(locale: .current)
        recognizer = rec

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if rec?.supportsOnDeviceRecognition == true {
            req.requiresOnDeviceRecognition = true
        }
        request = req

        let eng = AVAudioEngine()
        let input = eng.inputNode
        let format = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        try eng.start()
        engine = eng

        task = rec?.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error { self.onError?(error) }
                if let result {
                    let text = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.silenceTimer?.cancel()
                        self.onFinal?(text)
                    } else {
                        self.onPartial?(text)
                        self.resetSilenceTimer(text: text)
                    }
                }
            }
        }
    }

    func stop() {
        silenceTimer?.cancel()
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        task?.finish()
        task = nil
        request = nil
    }

    // MARK: - 1.2 s silence detection for tap-to-talk

    private func resetSilenceTimer(text: String) {
        silenceTimer?.cancel()
        lastPartial = text
        silenceTimer = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard let self, !Task.isCancelled else { return }
            let captured = self.lastPartial
            self.stop()
            self.onFinal?(captured)
        }
    }
}

// MARK: - Permission helper

enum SpeechPermission {
    static func request() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    static var isAuthorized: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }
}

// MARK: - Microphone RMS monitor

/// Feeds a smoothed 0…1 RMS level into VegaStore.state while listening.
final class MicLevelMonitor: @unchecked Sendable {
    private var engine:   AVAudioEngine?
    private var smoothed: Float = 0
    private let lock      = NSLock()

    var onLevel: @MainActor @Sendable (CGFloat) -> Void = { _ in }

    func start() {
        guard engine == nil else { return }
        let eng   = AVAudioEngine()
        let input = eng.inputNode
        let format = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            let rms  = Self.rms(buffer: buffer)
            var level: Float = 0
            self.lock.lock()
            self.smoothed = self.smoothed * 0.8 + rms * 0.2
            level = min(self.smoothed * 4, 1)
            self.lock.unlock()
            let cg = CGFloat(level)
            Task { @MainActor [weak self] in self?.onLevel(cg) }
        }

        try? eng.start()
        engine = eng
    }

    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        lock.lock(); smoothed = 0; lock.unlock()
    }

    private static func rms(buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData else { return 0 }
        let length = Int(buffer.frameLength)
        guard length > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<length { sum += data[0][i] * data[0][i] }
        return sqrt(sum / Float(length))
    }
}
