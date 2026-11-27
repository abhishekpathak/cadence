import Foundation

public enum Phase: String, Codable, CaseIterable {
    case focus, recall, rest, rest_break = "break"

    /// Nominal length in seconds, before any time scaling.
    public var nominal: TimeInterval {
        switch self {
        case .focus: return 25 * 60
        case .recall: return 5 * 60
        case .rest: return 5 * 60
        case .rest_break: return 15 * 60
        }
    }

    public var label: String {
        switch self {
        case .focus: return "Focus"
        case .recall: return "Recall"
        case .rest: return "Rest"
        case .rest_break: return "Break"
        }
    }
}

public struct PhaseRecord: Codable, Equatable {
    public var phase: Phase
    public var start: Date
    public var end: Date?

    public init(phase: Phase, start: Date, end: Date? = nil) {
        self.phase = phase; self.start = start; self.end = end
    }
}

public struct Session: Codable, Equatable, Identifiable {
    public var id = UUID()
    public var purpose: String
    public var phases: [PhaseRecord]
    public var completed = false

    public init(purpose: String, phases: [PhaseRecord], completed: Bool = false) {
        self.purpose = purpose; self.phases = phases; self.completed = completed
    }

    public var startedAt: Date { phases.first?.start ?? Date() }
}
