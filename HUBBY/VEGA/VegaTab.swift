import SwiftUI

// MARK: - Full VEGA tab: hero core + transcript + input

struct VegaTab: View {
    @Environment(VegaStore.self)      private var vega
    @Environment(DashboardStore.self) private var store

    @State private var scrollProxy: ScrollViewProxy?
    @State private var inputText: String = ""

    var body: some View {
        ZStack {
            Color.void.ignoresSafeArea()
            HUDBackground()

            VStack(spacing: 0) {
                headerBar
                coreHero
                // Tool status chip (visible while VEGA is calling a backend tool)
                if let status = vega.toolStatusMessage, vega.state.isThinking {
                    toolStatusChip(status)
                }
                transcriptArea
                inputRow
            }
        }
        .onAppear {
            if !vega.isMicAllowed || !vega.isSpeechAllowed {
                Task { await vega.requestPermissions() }
            }
        }
        .task {
            // Seed on first appear, then onChange handles updates
            vega.latestSnapshot = store.snapshot.flatMap { SnapshotPayload(snapshot: $0) }
        }
        .onChange(of: store.snapshotRefreshedAt) { _, _ in
            vega.latestSnapshot = store.snapshot.flatMap { SnapshotPayload(snapshot: $0) }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text("VEGA")
                .font(HUDFont.display(18, weight: .bold))
                .foregroundStyle(Color.hudCyan)
                .kerning(4)
            Spacer()
            statePill
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var statePill: some View {
        Text(vega.state.pillLabel)
            .font(HUDFont.mono(9, weight: .medium))
            .foregroundStyle(vega.state.primaryColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(vega.state.primaryColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Hero

    private var coreHero: some View {
        VStack(spacing: 18) {
            VegaCoreView(state: vega.state, diameter: 200)
                .padding(.top, 16)
            primaryButton
        }
    }

    private var primaryButton: some View {
        Button { handlePrimaryTap() } label: {
            Text(primaryButtonLabel)
                .font(HUDFont.display(13, weight: .semibold))
                .foregroundStyle(vega.state.primaryColor)
                .padding(.horizontal, 28)
                .padding(.vertical, 10)
                .background(vega.state.primaryColor.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(vega.state.primaryColor.opacity(0.35), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(vega.state.isThinking)
    }

    private var primaryButtonLabel: String {
        switch vega.state {
        case .idle:      return "TAP TO TALK"
        case .listening: return "LISTENING  ●"
        case .thinking:  return "THINKING…"
        case .speaking:  return "TAP TO STOP"
        case .alert:     return "TAP TO RESPOND"
        }
    }

    // MARK: - Transcript

    private var transcriptArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if vega.turns.isEmpty && !vega.state.isListening {
                        emptyPlaceholder
                    }

                    ForEach(vega.turns) { turn in
                        TurnBubble(turn: turn)
                            .id(turn.id)
                    }

                    // Partial transcript while listening
                    if vega.state.isListening, !vega.pendingText.isEmpty {
                        partialBubble
                            .id("partial")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .onChange(of: vega.turns.count) { _, _ in
                    withAnimation { proxy.scrollTo(vega.turns.last?.id, anchor: .bottom) }
                }
                .onChange(of: vega.pendingText) { _, _ in
                    withAnimation { proxy.scrollTo("partial", anchor: .bottom) }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(Color.faint)
            Text("Ask VEGA anything about your money,\nalerts or job leads.")
                .font(HUDFont.mono(12))
                .foregroundStyle(Color.dim)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    private var partialBubble: some View {
        Text(vega.pendingText)
            .font(HUDFont.mono(13))
            .foregroundStyle(Color.hudText.opacity(0.65))
            .padding(10)
            .background(Color.panel2)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.hudCyan.opacity(0.2), lineWidth: 1)
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Tool status chip

    private func toolStatusChip(_ message: String) -> some View {
        HStack(spacing: 6) {
            ProgressView().scaleEffect(0.65).tint(Color.faint)
            Text(message)
                .font(HUDFont.mono(10))
                .foregroundStyle(Color.faint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.bottom, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.2), value: vega.toolStatusMessage)
    }

    // MARK: - Input row

    private var inputRow: some View {
        VStack(spacing: 0) {
            Divider().background(Color.line)
            // Suggestion chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { chip in
                        suggestionChip(chip)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
            Divider().background(Color.line.opacity(0.4))
            // Text input
            HStack(spacing: 8) {
                TextField("Ask VEGA…", text: $inputText)
                    .font(HUDFont.mono(12))
                    .foregroundStyle(Color.hudText)
                    .tint(Color.hudCyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.panel2)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.line, lineWidth: 1))
                    .onSubmit { submitInput() }
                Button { submitInput() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(canSubmit ? Color.hudCyan : Color.faint)
                }
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(Color.panel)
    }

    private var canSubmit: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !vega.state.isThinking
        && !vega.state.isListening
    }

    private func submitInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        sendText(text)
    }

    private let suggestions = ["Brief me", "Any alerts?", "Best lead?", "My balance?", "Cash flow?"]

    private func suggestionChip(_ text: String) -> some View {
        Button {
            sendText(text)
        } label: {
            Text(text)
                .font(HUDFont.mono(11))
                .foregroundStyle(Color.dim)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.panel2)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.faint.opacity(0.4), lineWidth: 1))
        }
        .disabled(vega.state.isThinking || vega.state.isListening)
    }

    // MARK: - Actions

    private func handlePrimaryTap() {
        switch vega.state {
        case .idle, .alert:   vega.startListening()
        case .listening:      vega.stopListening()
        case .speaking:       vega.stopSpeaking()
        case .thinking:       break
        }
    }

    private func sendText(_ text: String) {
        vega.send(text)
    }
}

// MARK: - Turn bubble

private struct TurnBubble: View {
    let turn: VegaTurn

    var body: some View {
        VStack(alignment: turn.role == .user ? .trailing : .leading, spacing: 8) {
            Text(turn.text)
                .font(HUDFont.mono(13))
                .foregroundStyle(turn.role == .user ? Color.hudText.opacity(0.7) : Color.hudText)
                .padding(10)
                .background(turn.role == .user ? Color.panel2 : Color.panel)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            turn.role == .user
                                ? Color.hudCyan.opacity(0.15)
                                : Color.line,
                            lineWidth: 1
                        )
                )
                .frame(maxWidth: .infinity, alignment: turn.role == .user ? .trailing : .leading)

            // Render cards for assistant turns
            if turn.role == .assistant {
                ForEach(turn.cards) { card in
                    AssistantCardView(card: card)
                }
            }
        }
    }
}
