import AppKit
import SwiftUI
import CadenceCore

/// `Cadence --snapshot <dir>` renders the UI states to PNGs with a fake clock, then exits.
/// Needs no screen-recording permission, so it works for quick visual checks.
enum Snapshot {
    static func run(into dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        var t = Date(timeIntervalSince1970: 1_000_000)
        let engine = CadenceEngine(now: { t })
        // Scratch history, so snapshots never touch the real sessions file. Dated today, so the list shows them.
        let history = URL(fileURLWithPath: dir).appendingPathComponent("sessions.jsonl")
        try? FileManager.default.removeItem(at: history)
        let store = Store(url: history)
        let today = Calendar.current.startOfDay(for: Date())
        for (h, purpose) in [(9.0, "Inbox zero"), (9.75, "Write chapter 2 outline"), (11.0, "Review the pull request for the new sessions log format"),
                             (13.5, "Reading: spaced repetition paper"), (14.25, "Refactor engine"), (15.0, "Plan next week"),
                             (16.0, "Email follow-ups"), (17.0, "Sketch onboarding")] {
            let start = today.addingTimeInterval(h * 3600)
            var s = Session(purpose: purpose, phases: [PhaseRecord(phase: .focus, start: start, end: start.addingTimeInterval(1500))])
            s.completed = true
            try? store.append(s)
        }
        let model = Model(engine: engine, store: store)
        model.tick = t

        func shot(_ name: String) {
            for scheme in [ColorScheme.light] {
                model.tick = t
                let root = ZStack {
                    (scheme == .dark ? Color(white: 0.16) : Color(white: 0.82))
                    TimerView(model: model).padding(20)
                }
                .environment(\.colorScheme, scheme)
                let host = NSHostingView(rootView: root)
                host.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                host.frame = NSRect(origin: .zero, size: host.fittingSize)
                host.layoutSubtreeIfNeeded()
                guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
                host.cacheDisplay(in: host.bounds, to: rep)
                let png = rep.representation(using: .png, properties: [:])
                try? png?.write(to: URL(fileURLWithPath: "\(dir)/\(name)-\(scheme == .dark ? "dark" : "light").png"))
            }
        }
        func shotSettings() {
            let host = NSHostingView(rootView: SettingsView(model: model))
            host.frame = NSRect(origin: .zero, size: host.fittingSize)
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/8-settings.png"))
        }
        func advance(_ m: Double) { t = t.addingTimeInterval(m * 60) }
        let savedStyle = model.clockStyle
        func discShot(_ name: String) {
            model.clockStyle = .disc; shot(name); model.clockStyle = .ring
        }
        defer { model.clockStyle = savedStyle }
        model.clockStyle = .ring

        shot("1-idle")
        discShot("d1-idle")
        model.hoveringClock = true; shot("1b-idle-hover"); model.hoveringClock = false
        model.prompting = true; model.purpose = "Write chapter 3"
        shot("2-prompt")
        model.prompting = false; model.purpose = "Write chapter 3"
        model.startFocus(); advance(10)
        shot("3-focus")
        discShot("d3-focus")
        model.hoveringClock = true; shot("3b-focus-hover"); discShot("d3b-focus-hover")
        engine.pause(); shot("3c-paused-hover"); discShot("d3c-paused-hover")
        model.hoveringClock = false; shot("3d-paused")
        discShot("d3d-paused")
        engine.resume()
        model.showingToday = true; shot("3e-today-live"); model.showingToday = false
        advance(18)
        shot("4-focus-over")
        discShot("d4-focus-over")
        engine.startRecall(); advance(2)
        shot("5-recall")
        discShot("d5-recall")
        engine.startRest(); advance(1)
        shot("6-rest")
        discShot("d6-rest")
        engine.startBreak(); advance(1)
        shot("7-break")
        discShot("d7-break")
        model.showingToday = true; shot("7b-today-break"); model.showingToday = false
        shotSettings()
    }
}
