import SwiftUI
import CadenceCore

extension Phase {
    var color: Color {
        switch self {
        case .focus: return Color(red: 0.92, green: 0.34, blue: 0.28)
        case .recall: return Color(red: 0.25, green: 0.52, blue: 0.96)
        case .rest: return Color(red: 0.20, green: 0.70, blue: 0.45)
        case .rest_break: return Color(red: 0.55, green: 0.45, blue: 0.88)
        }
    }
}

extension Font {
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// Capsule button: tinted fill, solid when prominent. No hover state (the @State macro
/// isn't available in this toolchain), so feedback is the pressed state only.
struct PillButtonStyle: ButtonStyle {
    var tint: Color
    var prominent = false
    var wide = false
    var width: CGFloat?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(15, .semibold))
            .lineLimit(1)
            .frame(width: width)
            .frame(maxWidth: wide ? .infinity : nil)
            .padding(.horizontal, wide ? 6 : 16).padding(.vertical, 9)
            .foregroundStyle(prominent ? Color.white : tint)
            .background(Capsule().fill(prominent ? tint : tint.opacity(0.12)))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct TimerView: View {
    @ObservedObject var model: Model
    @FocusState private var focused: Bool

    static let width: CGFloat = 280
    /// One size for every state, matching the running layout.
    static let height: CGFloat = 373
    private static let overflowColor = Color.orange
    private static let ink = Color(white: 0.12)
    private static let subtle = Color(white: 0.45)
    private static let radius: CGFloat = 22

    var body: some View {
        VStack(spacing: 12) {
            if model.prompting {
                prompt
            } else if model.showingToday {
                todayList
            } else if let a = model.engine.active, let r = model.engine.remaining {
                running(a.phase, remaining: r)
            } else {
                idle
            }
        }
        .padding(20)
        .frame(width: Self.width, height: Self.height)
        .background {
            RoundedRectangle(cornerRadius: Self.radius).fill(Color.white)
            if let r = model.engine.remaining, r < 0, !model.prompting {
                RoundedRectangle(cornerRadius: Self.radius).fill(Self.overflowColor.opacity(0.10 * pulse))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: Self.radius).stroke(Color.black.opacity(0.08), lineWidth: 1))
        .environment(\.colorScheme, .light) // deliberately white in both system appearances
        .animation(.easeInOut(duration: 0.25), value: pulse)
    }

    /// 0.5...1, slow breathing keyed off the model's tick.
    private var pulse: Double {
        0.75 + 0.25 * cos(model.tick.timeIntervalSinceReferenceDate * 2 * .pi / 1.6)
    }

    // MARK: States

    private var prompt: some View {
        VStack(spacing: 12) {
            Text("What is this pomodoro for?")
                .font(.rounded(16, .semibold)).foregroundStyle(Self.ink)
            TextField("Purpose", text: $model.purpose)
                .textFieldStyle(.roundedBorder).font(.rounded(15)).controlSize(.large)
                .focused($focused)
                .onSubmit { model.startFocus() }
                .onAppear { focused = true }
            primary("Start focus", Phase.focus.color, model.startFocus)
            textButton("Cancel") { model.prompting = false }
        }
    }

    private var idle: some View {
        VStack(spacing: 12) {
            Text("READY").font(.rounded(13, .bold)).tracking(1.8).foregroundStyle(Self.subtle)
            clock(progress: 0, accent: Phase.focus.color, timeColor: Self.ink.opacity(0.5),
                  time: format(model.engine.duration(of: .focus)), icon: "play.fill",
                  action: model.beginFocusPrompt)
            purposeLine(nil)
            todayText
            primary("Start focus", Phase.focus.color, model.beginFocusPrompt)
            textButton("Take a break", model.startBreak)
        }
    }

    /// The ring + time. Hovering hides the time and shows a centred glyph.
    private func clock(progress: Double, accent: Color, timeColor: Color, time: String, icon: String,
                       dim: Bool = false, pulseRing: Bool = false, action: @escaping () -> Void) -> some View {
        ZStack {
            Circle().stroke(Color.black.opacity(0.06), lineWidth: 9)
            Circle().trim(from: 0, to: progress)
                .stroke(accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(pulseRing ? pulse : 1)
                .animation(.linear(duration: 0.25), value: progress)
            Text(time)
                .font(.system(size: 42, weight: .light, design: .rounded).monospacedDigit())
                .foregroundStyle(timeColor)
                .opacity(model.hoveringClock ? 0 : (dim ? 0.5 : 1))
            if model.hoveringClock {
                Image(systemName: icon)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(accent)
                    .transition(.opacity)
            }
        }
        .frame(width: 160, height: 160)
        .contentShape(Circle())
        .onHover { model.hoveringClock = $0 }
        .onTapGesture(perform: action)
        .animation(.easeOut(duration: 0.15), value: model.hoveringClock)
    }

    /// Opens today's list.
    private var todayText: some View {
        Button { model.showingToday = true } label: {
            Text("\(model.todayCount) \(model.todayCount == 1 ? "pomo" : "pomos") today")
                .font(.rounded(16, .medium)).foregroundStyle(Self.subtle)
        }
        .buttonStyle(.plain)
        .help("Show today's pomos")
    }

    private static let timeFormat: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short; return f
    }()

    /// Today's pomos, swapped in place of the timer at the same window size.
    private var todayList: some View {
        VStack(spacing: 12) {
            ZStack {
                Text("TODAY").font(.rounded(13, .bold)).tracking(1.8).foregroundStyle(Self.subtle)
                HStack {
                    Button { model.showingToday = false } label: {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Self.subtle).frame(width: 28, height: 22).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).help("Back to the timer")
                    Spacer()
                }
            }
            if model.todaySessions.isEmpty {
                Text("No pomos yet today").font(.rounded(15)).foregroundStyle(Self.subtle)
                    .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(model.todaySessions) { s in
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text(Self.timeFormat.string(from: s.startedAt))
                                        .font(.rounded(14).monospacedDigit()).foregroundStyle(Self.subtle)
                                        .frame(width: 66, alignment: .leading)
                                    Text(s.purpose).font(.rounded(15)).foregroundStyle(Self.ink)
                                        .lineLimit(1).truncationMode(.tail)
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 7)
                                .help(s.purpose)
                                .id(s.id)
                            }
                        }
                    }
                    .onAppear { if let last = model.todaySessions.last { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
                .frame(maxHeight: .infinity)
            }
            if let a = model.engine.active, let r = model.engine.remaining {
                liveStrip(a.phase, remaining: r)
            }
        }
    }

    /// A quiet reminder of the running timer while the list is open; tapping it goes back.
    private func liveStrip(_ phase: Phase, remaining r: TimeInterval) -> some View {
        let paused = model.engine.isPaused
        let color = paused ? Self.subtle : (r < 0 ? Self.overflowColor : phase.color)
        return Button { model.showingToday = false } label: {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 8, height: 8)
                    .opacity(r < 0 && !paused ? pulse : 1)
                Text(phase.label + (paused ? " · paused" : ""))
                    .font(.rounded(14, .medium)).foregroundStyle(Self.subtle)
                Spacer()
                Text(format(r)).font(.rounded(14, .medium).monospacedDigit()).foregroundStyle(color)
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(Capsule().fill(Color.black.opacity(0.04)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Back to the timer")
    }

    private func running(_ phase: Phase, remaining r: TimeInterval) -> some View {
        let over = r < 0
        let accent = over ? Self.overflowColor : phase.color
        let paused = model.engine.isPaused
        let shown = paused ? Self.subtle : accent
        let total = model.engine.active?.duration ?? model.engine.duration(of: phase)
        let progress = min(max(1 - r / total, 0), 1)
        let finishing = phase == .rest || phase == .rest_break
        return VStack(spacing: 12) {
            Text(phase.label.uppercased() + (paused ? " · PAUSED" : over ? " · OVER" : ""))
                .font(.rounded(13, .bold)).tracking(1.8).foregroundStyle(shown)
            clock(progress: progress, accent: shown, timeColor: over ? accent : Self.ink,
                  time: format(r), icon: paused ? "play.fill" : "pause.fill",
                  dim: paused, pulseRing: over && !paused, action: model.togglePause)
            purposeLine(model.engine.session?.purpose)
            todayText
            switch phase {
            case .focus: primary("Recall", Phase.recall.color, model.startRecall)
            case .recall: primary("Rest", Phase.rest.color, model.startRest)
            default: primary("Done", accent, model.end)
            }
            if finishing {
                Color.clear.frame(height: 17) // keeps the layout identical to the other phases
            } else {
                textButton("Stop", model.end)
            }
        }
    }

    /// The running session's purpose; an empty line of the same height otherwise,
    /// so the today line and buttons sit in the same place on every screen.
    private func purposeLine(_ purpose: String?) -> some View {
        Text(purpose ?? " ").font(.rounded(16, .medium)).foregroundStyle(Self.ink)
            .lineLimit(1).truncationMode(.tail)
            .help(purpose ?? "")
    }

    private func textButton(_ t: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.rounded(14, .medium)).foregroundStyle(Self.subtle)
        }
        .buttonStyle(.plain)
    }

    private func pill(_ t: String, _ tint: Color, prominent: Bool = false, wide: Bool = false,
                      _ action: @escaping () -> Void) -> some View {
        Button(t, action: action).buttonStyle(PillButtonStyle(tint: tint, prominent: prominent, wide: wide))
    }

    /// The one main action per screen: same width everywhere, centred.
    private func primary(_ t: String, _ tint: Color, _ action: @escaping () -> Void) -> some View {
        Button(t, action: action).buttonStyle(PillButtonStyle(tint: tint, prominent: true, width: 150))
    }

    private func format(_ s: TimeInterval) -> String {
        let n = Int(abs(s).rounded(.up))
        return String(format: "%@%d:%02d", s < 0 ? "+" : "", n / 60, n % 60)
    }
}
