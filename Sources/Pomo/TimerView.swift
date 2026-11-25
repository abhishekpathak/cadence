import SwiftUI
import PomoCore

extension Phase {
    var color: Color {
        switch self {
        case .focus: return Color(red: 0.92, green: 0.36, blue: 0.30)
        case .recall: return Color(red: 0.30, green: 0.56, blue: 0.95)
        case .rest: return Color(red: 0.35, green: 0.75, blue: 0.50)
        case .rest_break: return Color(red: 0.55, green: 0.50, blue: 0.85)
        }
    }
}

struct TimerView: View {
    @ObservedObject var model: Model
    @FocusState private var focused: Bool

    private static let overflowColor = Color.orange

    var body: some View {
        VStack(spacing: 8) {
            if model.prompting {
                prompt
            } else if let a = model.engine.active, let r = model.engine.remaining {
                running(a.phase, remaining: r)
            } else {
                idle
            }
        }
        .padding(12)
        .frame(width: 220)
        .background {
            RoundedRectangle(cornerRadius: 14).fill(.regularMaterial)
            if let r = model.engine.remaining, r < 0, !model.prompting {
                RoundedRectangle(cornerRadius: 14).fill(Self.overflowColor.opacity(0.18 * pulse))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: pulse)
    }

    /// 0.5...1, slow breathing keyed off the model's tick.
    private var pulse: Double {
        0.75 + 0.25 * cos(model.tick.timeIntervalSinceReferenceDate * 2 * .pi / 1.6)
    }

    // MARK: States

    private var prompt: some View {
        VStack(spacing: 8) {
            Text("What is this pomodoro for?").font(.caption).foregroundStyle(.secondary)
            TextField("Purpose", text: $model.purpose)
                .textFieldStyle(.roundedBorder).focused($focused)
                .onSubmit { model.startFocus() }
                .onAppear { focused = true }
            HStack {
                small("Start", model.startFocus)
                small("Cancel") { model.prompting = false }
            }
        }
    }

    private var idle: some View {
        VStack(spacing: 8) {
            Text("\(model.todayCount)/\(model.todayTotal) pomos today").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                small("Focus", model.beginFocusPrompt)
                small("Recall", model.startRecall)
                small("Rest", model.startRest)
                small("Break", model.startBreak)
            }
        }
    }

    private func running(_ phase: Phase, remaining r: TimeInterval) -> some View {
        let over = r < 0
        let accent = over ? Self.overflowColor : phase.color
        let total = model.engine.duration(of: phase)
        let progress = min(max(1 - r / total, 0), 1)
        return VStack(spacing: 8) {
            Text(phase.label.uppercased() + (over ? " · OVER" : ""))
                .font(.caption2.weight(.semibold)).foregroundStyle(accent)
            ZStack {
                Circle().stroke(accent.opacity(0.18), lineWidth: 6)
                Circle().trim(from: 0, to: progress)
                    .stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .opacity(over ? pulse : 1)
                    .animation(.linear(duration: 0.25), value: progress)
                Text(format(r))
                    .font(.system(size: 26, weight: .light, design: .rounded).monospacedDigit())
                    .foregroundStyle(over ? accent : .primary)
            }
            .frame(width: 104, height: 104)
            if let s = model.engine.session {
                Text(s.purpose).font(.caption).lineLimit(1)
                dots(for: s)
            }
            HStack(spacing: 6) {
                switch phase {
                case .focus: small("Recall", model.startRecall)
                case .recall: small("Rest", model.startRest)
                default: EmptyView()
                }
                small(phase == .rest || phase == .rest_break ? "Done" : "Stop", model.end)
            }
        }
    }

    /// Focus → recall → rest: filled = done, coloured = current, hollow = upcoming.
    private func dots(for s: Session) -> some View {
        let steps: [Phase] = [.focus, .recall, .rest]
        let reached = s.phases.count
        return HStack(spacing: 6) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, p in
                ZStack {
                    Circle().stroke(p.color.opacity(0.5), lineWidth: 1.5)
                    if i < reached - 1 { Circle().fill(p.color) }
                    else if i == reached - 1 { Circle().fill(p.color).padding(2.5) }
                }
                .frame(width: 10, height: 10)
            }
        }
    }

    private func small(_ t: String, _ action: @escaping () -> Void) -> some View {
        Button(t, action: action).buttonStyle(.bordered).controlSize(.small)
    }

    private func format(_ s: TimeInterval) -> String {
        let n = Int(abs(s).rounded(.up))
        return String(format: "%@%d:%02d", s < 0 ? "+" : "", n / 60, n % 60)
    }
}
