import Foundation

/// Drives the 25 + 5 + 5 pattern. A phase stays active until the user starts the
/// next one (or ends it), so time past its nominal length is "overflow".
public final class PomoEngine {
    public static let maxOverflow: TimeInterval = 15 * 60

    public struct Active {
        public let phase: Phase
        public let start: Date
    }

    public private(set) var active: Active?
    /// The in-progress pomodoro (focus → recall → rest), if any.
    public private(set) var session: Session?

    public var onSessionFinished: ((Session) -> Void)?

    private let now: () -> Date
    /// Divides all durations; lets tests and debug runs compress minutes into seconds.
    public let scale: Double

    public init(scale: Double = 1, now: @escaping () -> Date = Date.init) {
        self.scale = scale
        self.now = now
    }

    public func duration(of phase: Phase) -> TimeInterval { phase.nominal / scale }
    private var overflowLimit: TimeInterval { Self.maxOverflow / scale }

    /// Seconds left in the active phase; negative once in overflow.
    public var remaining: TimeInterval? {
        guard let a = active else { return nil }
        return duration(of: a.phase) - now().timeIntervalSince(a.start)
    }

    // MARK: Transitions

    public func startFocus(purpose: String) {
        closeActive()
        finishSession()
        let t = now()
        session = Session(purpose: purpose, phases: [PhaseRecord(phase: .focus, start: t)])
        active = Active(phase: .focus, start: t)
    }

    /// Recall/rest only count toward a pomodoro when they follow in order.
    public func startRecall() { startFollowUp(.recall) }
    public func startRest() { startFollowUp(.rest) }

    public func startBreak() {
        closeActive()
        finishSession()
        active = Active(phase: .rest_break, start: now())
    }

    /// Ends the active phase. Ending a rest completes the pomodoro.
    public func endCurrent() {
        closeActive()
        finishSession()
    }

    // MARK: Internals

    private func startFollowUp(_ phase: Phase) {
        let previous = active?.phase
        closeActive()
        let t = now()
        if session != nil, isNext(phase, after: previous) {
            session?.phases.append(PhaseRecord(phase: phase, start: t))
        } else {
            finishSession() // out of order → the pomodoro in progress fails
        }
        active = Active(phase: phase, start: t)
    }

    private func isNext(_ phase: Phase, after previous: Phase?) -> Bool {
        (previous == .focus && phase == .recall) || (previous == .recall && phase == .rest)
    }

    private func closeActive() {
        guard let a = active else { return }
        if session != nil, let i = session!.phases.indices.last, session!.phases[i].phase == a.phase {
            session!.phases[i].end = now()
        }
        active = nil
    }

    private func finishSession() {
        guard var s = session else { return }
        s.completed = Self.isSuccessful(s, scale: scale)
        session = nil
        onSessionFinished?(s)
    }

    /// Success: all three phases ran in order for at least their nominal length,
    /// with total overflow across them within the limit.
    public static func isSuccessful(_ s: Session, scale: Double = 1) -> Bool {
        guard s.phases.map(\.phase) == [.focus, .recall, .rest] else { return false }
        var overflow: TimeInterval = 0
        for r in s.phases {
            guard let end = r.end else { return false }
            let over = end.timeIntervalSince(r.start) - r.phase.nominal / scale
            if over < 0 { return false }
            overflow += over
        }
        return overflow <= maxOverflow / scale
    }
}
