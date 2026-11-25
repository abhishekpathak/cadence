import Foundation
import SwiftUI
import UserNotifications
import PomoCore

protocol DislodgeAction { func phaseTimeUp(_ phase: Phase) }
/// v1: intentionally does nothing. Future home of the grayscale / overlay / screensaver nudge.
struct NoDislodge: DislodgeAction { func phaseTimeUp(_ phase: Phase) {} }

final class Model: ObservableObject {
    let engine: PomoEngine
    let store = Store()
    let dislodge: DislodgeAction = NoDislodge()

    @Published var tick = Date()
    @Published var prompting = false
    @Published var purpose = ""
    @Published var hoveringClock = false
    @Published private(set) var minutes: [Phase: Int] = [:]
    static let minuteRange = 1...240
    @Published var todayCount = 0
    @Published var todayTotal = 0

    private var timer: Timer?
    private var notifiedFor: UUID?

    /// `engine` is injectable so snapshots can drive the UI with a fake clock.
    init(engine: PomoEngine? = nil) {
        let scale = Double(ProcessInfo.processInfo.environment["POMO_SCALE"] ?? "") ?? 1
        self.engine = engine ?? PomoEngine(scale: scale)
        self.engine.onSessionFinished = { [weak self] s in
            self?.store.append(s)
            self?.refreshToday()
        }
        loadMinutes()
        refreshToday()
        if Bundle.main.bundleIdentifier != nil { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in } }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.onTick() }
    }

    private func loadMinutes() {
        for p in Phase.allCases {
            let stored = UserDefaults.standard.object(forKey: "minutes.\(p.rawValue)") as? Int
            setMinutes(stored ?? Int(p.nominal / 60), for: p, persist: false)
        }
    }

    func setMinutes(_ value: Int, for phase: Phase, persist: Bool = true) {
        let v = min(max(value, Self.minuteRange.lowerBound), Self.minuteRange.upperBound)
        minutes[phase] = v
        engine.minutes[phase] = v
        if persist { UserDefaults.standard.set(v, forKey: "minutes.\(phase.rawValue)") }
    }

    func resetMinutes() {
        for p in Phase.allCases {
            UserDefaults.standard.removeObject(forKey: "minutes.\(p.rawValue)")
            setMinutes(Int(p.nominal / 60), for: p, persist: false)
        }
    }

    private func refreshToday() {
        let today = store.load().filter { Calendar.current.isDateInToday($0.startedAt) }
        todayTotal = today.count
        todayCount = today.filter(\.completed).count
    }

    private func onTick() {
        tick = Date()
        guard let a = engine.active, let r = engine.remaining, r <= 0, notifiedFor != a.id else { return }
        notifiedFor = a.id
        notify("\(a.phase.label) time is up", body: a.phase == .rest || a.phase == .rest_break ? "Well done." : "Move to the next step.")
        dislodge.phaseTimeUp(a.phase)
    }

    private func notify(_ title: String, body: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let c = UNMutableNotificationContent()
        c.title = title; c.body = body; c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }

    // Actions
    func beginFocusPrompt() { prompting = true }
    func startFocus() {
        prompting = false
        engine.startFocus(purpose: purpose.isEmpty ? "Untitled" : purpose)
        purpose = ""
        tick = Date()
    }
    func startRecall() { engine.startRecall(); tick = Date() }
    func startRest() { engine.startRest(); tick = Date() }
    func startBreak() { prompting = false; engine.startBreak(); tick = Date() }
    func togglePause() { engine.togglePause(); tick = Date() }
    func end() { prompting = false; engine.endCurrent(); tick = Date() }
}
