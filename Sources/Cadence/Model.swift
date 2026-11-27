import Foundation
import SwiftUI
import ServiceManagement
import UserNotifications
import CadenceCore

protocol DislodgeAction { func phaseTimeUp(_ phase: Phase) }
/// v1: intentionally does nothing. Future home of the grayscale / overlay / screensaver nudge.
struct NoDislodge: DislodgeAction { func phaseTimeUp(_ phase: Phase) {} }

final class Model: ObservableObject {
    let engine: CadenceEngine
    let store: Store
    let dislodge: DislodgeAction = NoDislodge()

    @Published var tick = Date()
    @Published var prompting = false
    @Published var purpose = ""
    @Published var hoveringClock = false
    @Published private(set) var minutes: [Phase: Int] = [:]
    static let minuteRange = 1...240
    @Published private(set) var launchAtLogin = false
    @Published private(set) var loginNote: String?
    /// Today's recorded pomos, oldest first.
    @Published private(set) var todaySessions: [Session] = []
    var todayCount: Int { todaySessions.count }
    /// The window shows today's list instead of the timer. Changing phase closes it; pausing doesn't.
    @Published var showingToday = false

    /// Finished sessions whose write failed; retried on the next save so nothing is dropped silently.
    private var unsaved: [Session] = []
    private var timer: Timer?
    private var notifiedFor: UUID?

    /// `engine` and `store` are injectable so snapshots can drive the UI with a fake clock and scratch history.
    init(engine: CadenceEngine? = nil, store: Store = Store()) {
        self.store = store
        let scale = Double(ProcessInfo.processInfo.environment["CADENCE_SCALE"] ?? "") ?? 1
        self.engine = engine ?? CadenceEngine(scale: scale)
        self.engine.onSessionFinished = { [weak self] s in
            self?.unsaved.append(s)
            self?.flushUnsaved()
        }
        loadMinutes()
        refreshLogin()
        refreshToday(reportSkipped: true)
        if Bundle.main.bundleIdentifier != nil { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in } }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.onTick() }
    }

    /// Reads the real login-item state, since it can also be changed in System Settings.
    func refreshLogin() {
        guard Bundle.main.bundleIdentifier != nil else { return } // not running as an .app
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled || status == .requiresApproval
        loginNote = status == .requiresApproval ? "Approve Cadence in System Settings → General → Login Items." : nil
    }

    func setLaunchAtLogin(_ on: Bool) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginNote = nil
        } catch {
            loginNote = "Couldn't change the login item: \(error.localizedDescription)"
        }
        let note = loginNote
        refreshLogin()
        if note != nil { loginNote = note }
    }

    private func loadMinutes() {
        for p in Phase.allCases {
            let key = "minutes.\(p.rawValue)"
            // Falls back to settings saved under the former bundle id (Pomo).
            let legacy = UserDefaults(suiteName: "local.abhishek.pomo")?.object(forKey: key) as? Int
            let stored = UserDefaults.standard.object(forKey: key) as? Int ?? legacy
            setMinutes(stored ?? Int(p.nominal / 60), for: p, persist: false)
        }
    }

    func setMinutes(_ value: Int, for phase: Phase, persist: Bool = true) {
        let v = min(max(value, Self.minuteRange.lowerBound), Self.minuteRange.upperBound)
        minutes[phase] = v
        engine.minutes[phase] = v
        if persist { UserDefaults.standard.set(v, forKey: "minutes.\(phase.rawValue)") }
    }

    /// Selects the session log in Finder, or opens its folder if nothing has been saved yet.
    func revealSessions() {
        if FileManager.default.fileExists(atPath: store.url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([store.url])
        } else {
            NSWorkspace.shared.open(store.url.deletingLastPathComponent())
        }
    }

    func resetMinutes() {
        for p in Phase.allCases {
            UserDefaults.standard.removeObject(forKey: "minutes.\(p.rawValue)")
            setMinutes(Int(p.nominal / 60), for: p, persist: false)
        }
    }

    private func flushUnsaved() {
        while let next = unsaved.first {
            do {
                try store.append(next)
                unsaved.removeFirst()
            } catch {
                notify("Couldn't save your pomodoro", body: "\(error.localizedDescription) It will be retried after your next session.")
                break
            }
        }
        refreshToday()
    }

    private func refreshToday(reportSkipped: Bool = false) {
        let loaded = store.load()
        if reportSkipped, loaded.skipped > 0 {
            notify("Some history couldn't be read", body: "\(loaded.skipped) unreadable line(s) in \(store.url.lastPathComponent) were skipped. The file was not changed.")
        }
        let today = (loaded.sessions + unsaved).filter { Calendar.current.isDateInToday($0.startedAt) }
        todaySessions = today.filter(\.completed).sorted { $0.startedAt < $1.startedAt }
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
    func beginFocusPrompt() { showingToday = false; prompting = true }
    func startFocus() {
        prompting = false
        engine.startFocus(purpose: purpose.isEmpty ? "Untitled" : purpose)
        purpose = ""
        tick = Date()
    }
    func startRecall() { showingToday = false; engine.startRecall(); tick = Date() }
    func startRest() { showingToday = false; engine.startRest(); tick = Date() }
    func startBreak() { showingToday = false; prompting = false; engine.startBreak(); tick = Date() }
    func togglePause() { engine.togglePause(); tick = Date() }
    func end() { showingToday = false; prompting = false; engine.endCurrent(); tick = Date() }
}
