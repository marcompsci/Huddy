import SwiftUI

// MARK: - Core state enum

enum VegaState: Equatable {
    case idle
    case listening(level: CGFloat)    // 0…1  microphone RMS
    case thinking
    case speaking(amplitude: CGFloat) // 0…1  TTS output level
    case alert

    // MARK: Conveniences

    var isListening: Bool { if case .listening = self { return true }; return false }
    var isThinking:  Bool { if case .thinking  = self { return true }; return false }
    var isSpeaking:  Bool { if case .speaking  = self { return true }; return false }
    var isAlert:     Bool { if case .alert     = self { return true }; return false }

    // MARK: Visual

    var primaryColor: Color {
        switch self {
        case .alert:           return .hudRed
        case .speaking:        return .hudGold
        default:               return .hudCyan
        }
    }

    var pillLabel: String {
        switch self {
        case .idle:      return "IDLE"
        case .listening: return "LISTENING"
        case .thinking:  return "THINKING"
        case .speaking:  return "SPEAKING"
        case .alert:     return "ALERT"
        }
    }

    // MARK: Accessibility

    var voiceOverLabel: String {
        switch self {
        case .idle:                return "VEGA is idle"
        case .listening(let l):   return "VEGA is listening, level \(Int(l * 100)) percent"
        case .thinking:            return "VEGA is thinking"
        case .speaking(let a):    return "VEGA is speaking, level \(Int(a * 100)) percent"
        case .alert:               return "VEGA alert"
        }
    }
}
