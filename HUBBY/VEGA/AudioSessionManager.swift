import AVFoundation
import Foundation

// MARK: - Manages AVAudioSession for the VEGA voice pipeline

@MainActor
final class AudioSessionManager {
    static let shared = AudioSessionManager()
    private init() {}

    private var isConfigured = false

    /// Activate playAndRecord / voiceChat.  Call before starting the microphone or TTS.
    func activate() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat,
                                options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true, options: [])
        if !isConfigured {
            observeInterruptions()
            observeRouteChanges()
            isConfigured = true
        }
    }

    /// Deactivate, notifying other apps (e.g. Music) they can resume.
    func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false,
             options: .notifyOthersOnDeactivation)
    }

    // MARK: - Interruption / route

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { note in
            Task { @MainActor in Self.handleInterruption(note) }
        }
    }

    private func observeRouteChanges() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { _ in
            NotificationCenter.default.post(name: .vegaAudioRouteChanged, object: nil)
        }
    }

    private static func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            NotificationCenter.default.post(name: .vegaAudioInterrupted, object: nil)
        case .ended:
            guard let rawOpts = info[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            if AVAudioSession.InterruptionOptions(rawValue: rawOpts).contains(.shouldResume) {
                NotificationCenter.default.post(name: .vegaAudioResumed, object: nil)
            }
        @unknown default: break
        }
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let vegaAudioInterrupted  = Notification.Name("vega.audio.interrupted")
    static let vegaAudioResumed      = Notification.Name("vega.audio.resumed")
    static let vegaAudioRouteChanged = Notification.Name("vega.audio.routeChanged")
}
