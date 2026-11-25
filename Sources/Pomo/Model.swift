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
    @Published var todayCount = 0
    @Published var todayTotal = 0

    private var timer: Timer?
    private var notifiedFor: Date?

    init() {
        let scale = Double(ProcessInfo.processInfo.environment["POMO_SCALE"] ?? "") ?? 1
        engine = PomoEngine(scale: scale)
        engine.onSessionFinished = { [weak self] s in
            self?.store.append(s)
            self?.refreshToday()
        }
        refreshToday()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.onTick() }
    }

    private func refreshToday() {
        let today = store.load().filter { Calendar.current.isDateInToday($0.startedAt) }
        todayTotal = today.count
        todayCount = today.filter(\.completed).count
    }

    private func onTick() {
        tick = Date()
        guard let a = engine.active, let r = engine.remaining, r <= 0, notifiedFor != a.start else { return }
        notifiedFor = a.start
        notify("\(a.phase.label) time is up", body: a.phase == .rest || a.phase == .rest_break ? "Well done." : "Move to the next step.")
        dislodge.phaseTimeUp(a.phase)
    }

    private func notify(_ title: String, body: String) {
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
    func end() { prompting = false; engine.endCurrent(); tick = Date() }
}
