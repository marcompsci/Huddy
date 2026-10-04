import Foundation
import Observation
import UIKit
import AVFoundation
import Speech

// MARK: - Observable store for VEGA — owns voice pipeline + brain

@Observable
@MainActor
final class VegaStore {

    // MARK: - State

    var state:            VegaState        = .idle
    var pendingText:      String          = ""    // partial transcript while listening
    var isMicAllowed:     Bool            = false
    var isSpeechAllowed:  Bool            = false
    /// Updated by VegaTab whenever DashboardStore.snapshot changes.
    var latestSnapshot:   SnapshotPayload? = nil
    /// Non-nil while VEGA is executing a backend tool call (e.g. "Fetching balance…").
    var toolStatusMessage: String?         = nil

    /// Observed by VegaTab to render conversation.
    var turns: [VegaTurn] { session.turns }

    // MARK: - Pipeline components

    private let transcriber  = SFTranscriber()
    private let micMonitor   = MicLevelMonitor()
    private let voice: any VoiceOutputting
    private let client:      AssistantClient
    private let session      = VegaSession.shared

    // MARK: - Haptics

    private let lightImpact   = UIImpactFeedbackGenerator(style: .light)
    private let softImpact    = UIImpactFeedbackGenerator(style: .soft)
    private let notifFeedback = UINotificationFeedbackGenerator()

    // MARK: - Init

    init() {
        let sysVoice = SystemVoice()
        voice  = sysVoice
        client = AssistantClient(backend: LiveAssistantBackend.makeOrMock())

        lightImpact.prepare()
        softImpact.prepare()
        notifFeedback.prepare()

        sysVoice.onAmplitude = { [weak self] amp in
            guard let self, self.state.isSpeaking else { return }
            self.state = .speaking(amplitude: amp)
        }
    }

    // MARK: - Permissions

    func requestPermissions() async {
        isMicAllowed    = await AVAudioApplication.requestRecordPermission()
        isSpeechAllowed = await SpeechPermission.request()
    }

    // MARK: - Listening (voice path)

    func startListening() {
        guard isMicAllowed, isSpeechAllowed else {
            Task { await requestPermissions() }
            return
        }
        pendingText = ""
        transition(to: .listening(level: 0))

        micMonitor.onLevel = { [weak self] level in
            guard let self, self.state.isListening else { return }
            self.state = .listening(level: level)
        }
        micMonitor.start()

        do {
            try AudioSessionManager.shared.activate()
            try transcriber.start(
                onPartial: { [weak self] text in self?.pendingText = text },
                onFinal:   { [weak self] text in self?.finalizeListening(transcript: text) },
                onError:   { [weak self] _    in self?.transition(to: .idle) }
            )
        } catch {
            transition(to: .idle)
        }
    }

    func stopListening() {
        micMonitor.stop()
        transcriber.stop()
    }

    private func finalizeListening(transcript: String) {
        micMonitor.stop()
        transcriber.stop()
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingText = ""
        guard !text.isEmpty else { transition(to: .idle); return }
        transition(to: .thinking)
        sendToBackend(userText: text, snapshot: latestSnapshot)
    }

    // MARK: - Text path (suggestion chips, typed input)

    func send(_ text: String, snapshot: SnapshotPayload? = nil) {
        guard !state.isThinking, !state.isListening else { return }
        transition(to: .thinking)
        sendToBackend(userText: text, snapshot: snapshot ?? latestSnapshot)
    }

    // MARK: - Speaking

    func speak(_ text: String) async {
        await voice.speak(text)
    }

    func stopSpeaking() {
        voice.stop()
        transition(to: .idle)
    }

    // MARK: - Brain

    private func sendToBackend(userText: String, snapshot: SnapshotPayload?) {
        client.send(
            userText:     userText,
            snapshot:     snapshot,
            onState:      { [weak self] s   in self?.state             = s   },
            onToolStatus: { [weak self] msg in self?.toolStatusMessage = msg },
            onSpeak:      { [weak self] text in
                self?.didReceiveFirstToken()
                await self?.speak(text)
            }
        )
    }

    // MARK: - State transitions

    func transition(to newState: VegaState) {
        let previous = state
        state        = newState
        fireHaptic(from: previous, to: newState)
    }

    func didReceiveFirstToken() {
        softImpact.impactOccurred()
        softImpact.prepare()
    }

    // MARK: - Haptics

    private func fireHaptic(from old: VegaState, to new: VegaState) {
        switch (old, new) {
        case (_, .listening):
            lightImpact.impactOccurred();  lightImpact.prepare()
        case (.listening, .thinking):
            softImpact.impactOccurred();   softImpact.prepare()
        case (_, .speaking):
            softImpact.impactOccurred();   softImpact.prepare()
        case (_, .alert):
            notifFeedback.notificationOccurred(.warning); notifFeedback.prepare()
        case (_, .idle):
            lightImpact.impactOccurred(intensity: 0.4); lightImpact.prepare()
        default:
            break
        }
    }
}
