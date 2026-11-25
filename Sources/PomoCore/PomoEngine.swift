import Foundation

/// Drives the 25 + 5 + 5 pattern. A phase stays active until the user starts the
/// next one (or ends it), so time past its nominal length shows as overflow.
public final class PomoEngine {
    public struct Active {
        public let id = UUID()
        public let phase: Phase
        /// Shifted forward on resume, so paused time never counts.
        public internal(set) var start: Date
    }

    public private(set) var active: Active?
    /// The in-progress pomodoro (focus → recall → rest), if any.
    public private(set) var session: Session?

    public private(set) var pausedAt: Date?
    public var isPaused: Bool { active != nil && pausedAt != nil }

    public var onSessionFinished: ((Session) -> Void)?

    private let now: () -> Date
    /// Divides all durations; lets tests and debug runs compress minutes into seconds.
    public let scale: Double

    public init(scale: Double = 1, now: @escaping () -> Date = Date.init) {
        self.scale = scale
        self.now = now
    }

    public func duration(of phase: Phase) -> TimeInterval { phase.nominal / scale }

    /// Seconds left in the active phase; negative once in overflow.
    public var remaining: TimeInterval? {
        guard let a = active else { return nil }
        return duration(of: a.phase) - (pausedAt ?? now()).timeIntervalSince(a.start)
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

    public func pause() {
        guard active != nil, pausedAt == nil else { return }
        pausedAt = now()
    }

    public func resume() {
        guard active != nil, let p = pausedAt else { return }
        active?.start += now().timeIntervalSince(p)
        pausedAt = nil
    }

    public func togglePause() { isPaused ? resume() : pause() }

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
        pausedAt = nil
        guard let a = active else { return }
        if session != nil, let i = session!.phases.indices.last, session!.phases[i].phase == a.phase {
            session!.phases[i].end = now()
        }
        active = nil
    }

    private func finishSession() {
        guard var s = session else { return }
        s.completed = Self.isSuccessful(s)
        session = nil
        onSessionFinished?(s)
    }

    /// Success: focus, recall and rest all ran, in that order.
    public static func isSuccessful(_ s: Session) -> Bool {
        s.phases.map(\.phase) == [.focus, .recall, .rest]
    }
}
