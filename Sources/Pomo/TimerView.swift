import SwiftUI
import PomoCore

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

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(15, .semibold))
            .lineLimit(1)
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
    private static let overflowColor = Color.orange
    private static let ink = Color(white: 0.12)
    private static let subtle = Color(white: 0.45)
    private static let radius: CGFloat = 22

    var body: some View {
        VStack(spacing: 14) {
            if model.prompting {
                prompt
            } else if let a = model.engine.active, let r = model.engine.remaining {
                running(a.phase, remaining: r)
            } else {
                idle
            }
        }
        .padding(20)
        .frame(width: Self.width)
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
        VStack(spacing: 14) {
            Text("What is this pomodoro for?")
                .font(.rounded(16, .semibold)).foregroundStyle(Self.ink)
            TextField("Purpose", text: $model.purpose)
                .textFieldStyle(.roundedBorder).font(.rounded(15)).controlSize(.large)
                .focused($focused)
                .onSubmit { model.startFocus() }
                .onAppear { focused = true }
            HStack(spacing: 8) {
                pill("Cancel", Self.subtle) { model.prompting = false }
                pill("Start focus", Phase.focus.color, prominent: true, wide: true, model.startFocus)
            }
        }
    }

    private var idle: some View {
        VStack(spacing: 14) {
            Text("\(model.todayCount) of \(model.todayTotal) pomos today")
                .font(.rounded(14, .medium)).foregroundStyle(Self.subtle)
            pill("Start focus", Phase.focus.color, prominent: true, wide: true, model.beginFocusPrompt)
            HStack(spacing: 8) {
                pill("Recall", Phase.recall.color, wide: true, model.startRecall)
                pill("Rest", Phase.rest.color, wide: true, model.startRest)
                pill("Break", Phase.rest_break.color, wide: true, model.startBreak)
            }
        }
    }

    private func running(_ phase: Phase, remaining r: TimeInterval) -> some View {
        let over = r < 0
        let accent = over ? Self.overflowColor : phase.color
        let total = model.engine.duration(of: phase)
        let progress = min(max(1 - r / total, 0), 1)
        let finishing = phase == .rest || phase == .rest_break
        return VStack(spacing: 14) {
            Text(phase.label.uppercased() + (over ? " · OVER" : ""))
                .font(.rounded(13, .bold)).tracking(1.8).foregroundStyle(accent)
            ZStack {
                Circle().stroke(Color.black.opacity(0.06), lineWidth: 9)
                Circle().trim(from: 0, to: progress)
                    .stroke(accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .opacity(over ? pulse : 1)
                    .animation(.linear(duration: 0.25), value: progress)
                Text(format(r))
                    .font(.system(size: 46, weight: .light, design: .rounded).monospacedDigit())
                    .foregroundStyle(over ? accent : Self.ink)
            }
            .frame(width: 176, height: 176)
            .padding(.vertical, 4)
            if let s = model.engine.session {
                Text(s.purpose).font(.rounded(16, .medium)).foregroundStyle(Self.ink).lineLimit(1)
                dots(for: s)
            }
            HStack(spacing: 8) {
                pill(finishing ? "Done" : "Stop", finishing ? accent : Self.subtle,
                     prominent: finishing, wide: finishing, model.end)
                switch phase {
                case .focus: pill("Recall", Phase.recall.color, prominent: true, wide: true, model.startRecall)
                case .recall: pill("Rest", Phase.rest.color, prominent: true, wide: true, model.startRest)
                default: EmptyView()
                }
            }
        }
    }

    /// Focus → recall → rest: filled = done, coloured = current, hollow = upcoming.
    private func dots(for s: Session) -> some View {
        let steps: [Phase] = [.focus, .recall, .rest]
        let reached = s.phases.count
        return HStack(spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, p in
                ZStack {
                    Circle().stroke(p.color.opacity(0.45), lineWidth: 2)
                    if i < reached - 1 { Circle().fill(p.color) }
                    else if i == reached - 1 { Circle().fill(p.color).padding(3) }
                }
                .frame(width: 14, height: 14)
            }
        }
    }

    private func pill(_ t: String, _ tint: Color, prominent: Bool = false, wide: Bool = false,
                      _ action: @escaping () -> Void) -> some View {
        Button(t, action: action).buttonStyle(PillButtonStyle(tint: tint, prominent: prominent, wide: wide))
    }

    private func format(_ s: TimeInterval) -> String {
        let n = Int(abs(s).rounded(.up))
        return String(format: "%@%d:%02d", s < 0 ? "+" : "", n / 60, n % 60)
    }
}
