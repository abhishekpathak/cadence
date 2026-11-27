import Foundation

public enum Phase: String, Codable, CaseIterable {
    /// Raw values are what's stored in history and settings, so `review` keeps its old name, "recall".
    case focus, review = "recall", rest

    /// Nominal length in seconds, before any time scaling.
    public var nominal: TimeInterval {
        switch self {
        case .focus: return 25 * 60
        case .review: return 5 * 60
        case .rest: return 5 * 60
        }
    }

    public var label: String {
        switch self {
        case .focus: return "Focus"
        case .review: return "Review"
        case .rest: return "Rest"
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
