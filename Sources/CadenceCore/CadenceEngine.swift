import Foundation

/// Drives the 25 + 5 + 5 pattern. A phase stays active until the user starts the
/// next one (or ends it), so time past its nominal length shows as overflow.
public final class CadenceEngine {
    public struct Active {
        public let id = UUID()
        public let phase: Phase
        /// Shifted forward on resume, so paused time never counts.
        public internal(set) var start: Date
        /// Fixed when the phase starts, so changing settings mid-phase doesn't move the goalposts.
        public let duration: TimeInterval
    }

    public private(set) var active: Active?
    /// The in-progress session (focus, optionally followed by recall → rest), if any.
    public private(set) var session: Session?

    public private(set) var pausedAt: Date?
    public var isPaused: Bool { active != nil && pausedAt != nil }

    public var onSessionFinished: ((Session) -> Void)?

    /// Focus at least this long (paused time excluded) earns a pomodoro; shorter sessions aren't recorded.
    public static let minimumFocus: TimeInterval = 10 * 60
    /// Unpaused time spent in the current session's focus phase.
    private var focusedTime: TimeInterval = 0

    private let now: () -> Date
    /// Divides all durations; lets tests and debug runs compress minutes into seconds.
    public let scale: Double

    public init(scale: Double = 1, now: @escaping () -> Date = Date.init) {
        self.scale = scale
        self.now = now
    }

    /// Configured length of each phase in whole minutes; defaults to the classic 25/5/5/15.
    public var minutes: [Phase: Int] = Dictionary(uniqueKeysWithValues: Phase.allCases.map { ($0, Int($0.nominal / 60)) })

    public func duration(of phase: Phase) -> TimeInterval {
        Double(minutes[phase] ?? Int(phase.nominal / 60)) * 60 / scale
    }

    /// Seconds left in the active phase; negative once in overflow.
    public var remaining: TimeInterval? {
        guard let a = active else { return nil }
        return a.duration - (pausedAt ?? now()).timeIntervalSince(a.start)
    }

    // MARK: Transitions

    public func startFocus(purpose: String) {
        closeActive()
        finishSession()
        let t = now()
        session = Session(purpose: purpose, phases: [PhaseRecord(phase: .focus, start: t)])
        focusedTime = 0
        active = Active(phase: .focus, start: t, duration: duration(of: .focus))
    }

    /// Recall/rest are recorded in the session only when they follow in order.
    public func startRecall() { startFollowUp(.recall) }
    public func startRest() { startFollowUp(.rest) }

    public func startBreak() {
        closeActive()
        finishSession()
        active = Active(phase: .rest_break, start: now(), duration: duration(of: .rest_break))
    }

    /// Ends the active phase and finishes the session in progress.
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
            finishSession() // out of order → the session in progress ends here
        }
        active = Active(phase: phase, start: t, duration: duration(of: phase))
    }

    private func isNext(_ phase: Phase, after previous: Phase?) -> Bool {
        (previous == .focus && phase == .recall) || (previous == .recall && phase == .rest)
    }

    private func closeActive() {
        defer { pausedAt = nil }
        guard let a = active else { return }
        if a.phase == .focus, session != nil {
            focusedTime = (pausedAt ?? now()).timeIntervalSince(a.start)
        }
        if session != nil, let i = session!.phases.indices.last, session!.phases[i].phase == a.phase {
            session!.phases[i].end = now()
        }
        active = nil
    }

    private func finishSession() {
        guard var s = session else { return }
        session = nil
        guard focusedTime >= Self.minimumFocus / scale else { return } // too short: not recorded
        s.completed = true
        onSessionFinished?(s)
    }
}
