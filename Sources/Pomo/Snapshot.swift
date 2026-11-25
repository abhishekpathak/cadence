import AppKit
import SwiftUI
import PomoCore

/// `Pomo --snapshot <dir>` renders the UI states to PNGs with a fake clock, then exits.
/// Needs no screen-recording permission, so it works for quick visual checks.
enum Snapshot {
    static func run(into dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        var t = Date(timeIntervalSince1970: 1_000_000)
        let engine = PomoEngine(now: { t })
        let model = Model(engine: engine)
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

        shot("1-idle")
        model.hoveringClock = true; shot("1b-idle-hover"); model.hoveringClock = false
        model.prompting = true; model.purpose = "Write chapter 3"
        shot("2-prompt")
        model.prompting = false; model.purpose = "Write chapter 3"
        model.startFocus(); advance(10)
        shot("3-focus")
        model.hoveringClock = true; shot("3b-focus-hover")
        engine.pause(); shot("3c-paused-hover")
        model.hoveringClock = false; shot("3d-paused")
        engine.resume()
        advance(18)
        shot("4-focus-over")
        engine.startRecall(); advance(2)
        shot("5-recall")
        engine.startRest(); advance(1)
        shot("6-rest")
        engine.startBreak(); advance(1)
        shot("7-break")
        shotSettings()
    }
}
