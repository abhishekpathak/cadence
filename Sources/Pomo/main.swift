import AppKit
import SwiftUI
import Carbon.HIToolbox
import Combine

/// Borderless panel that can still take keyboard input (for the purpose field).
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = Model()
    var panel: FloatingPanel!
    var statusItem: NSStatusItem!
    var host: NSHostingView<TimerView>!
    var settingsWindow: NSWindow?
    var sizeSub: AnyCancellable?

    func applicationDidFinishLaunching(_ n: Notification) {
        host = NSHostingView(rootView: TimerView(model: model))
        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: TimerView.width, height: TimerView.height),
                              styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = host
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.appearance = NSAppearance(named: .aqua)
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setFrameAutosaveName("PomoPanel")
        if !panel.setFrameUsingName("PomoPanel"), let s = NSScreen.main {
            panel.setFrameTopLeftPoint(NSPoint(x: s.visibleFrame.maxX - TimerView.width - 20, y: s.visibleFrame.maxY - 20))
        }
        host.postsFrameChangedNotifications = true
        panel.orderFrontRegardless()

        // Grow/shrink with content, keeping the top-left corner fixed.
        sizeSub = model.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.fitToContent() }
        }
        fitToContent()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "🍅"
        let menu = NSMenu()
        menu.addItem(withTitle: "Show / Hide", action: #selector(toggle), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Pomo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        // ⌃⌥ + P / R / E / B / X
        Hotkeys.register(key: kVK_ANSI_P, id: 1) { [self] in
            panel.orderFrontRegardless(); NSApp.activate(ignoringOtherApps: true); panel.makeKey()
            model.beginFocusPrompt()
        }
        Hotkeys.register(key: kVK_ANSI_R, id: 2) { [self] in model.startRecall() }
        Hotkeys.register(key: kVK_ANSI_E, id: 3) { [self] in model.startRest() }
        Hotkeys.register(key: kVK_ANSI_B, id: 4) { [self] in model.startBreak() }
        Hotkeys.register(key: kVK_ANSI_X, id: 5) { [self] in model.end() }
        Hotkeys.register(key: kVK_Space, id: 6) { [self] in model.togglePause() }
    }

    func fitToContent() {
        let size = host.fittingSize
        guard abs(size.height - panel.frame.height) > 0.5 || abs(size.width - panel.frame.width) > 0.5 else { return }
        var f = panel.frame
        f.origin.y += f.height - size.height
        f.size = size
        panel.setFrame(f, display: true)
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let host = NSHostingView(rootView: SettingsView(model: model))
            let w = NSWindow(contentRect: NSRect(origin: .zero, size: host.fittingSize),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Pomo Settings"
            w.contentView = host
            w.appearance = NSAppearance(named: .aqua)
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func toggle() {
        panel.isVisible ? panel.orderOut(nil) : panel.orderFrontRegardless()
    }
}

let app = NSApplication.shared
if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
    Snapshot.run(into: CommandLine.arguments[i + 1])
    exit(0)
}
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
