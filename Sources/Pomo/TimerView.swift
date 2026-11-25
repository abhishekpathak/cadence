import SwiftUI
import PomoCore

struct TimerView: View {
    @ObservedObject var model: Model
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 8) {
            if model.prompting {
                Text("What is this pomodoro for?").font(.caption).foregroundStyle(.secondary)
                TextField("Purpose", text: $model.purpose)
                    .textFieldStyle(.roundedBorder).focused($focused)
                    .onSubmit { model.startFocus() }
                    .onAppear { focused = true }
                HStack {
                    Button("Start") { model.startFocus() }
                    Button("Cancel") { model.prompting = false }
                }
            } else if let a = model.engine.active, let r = model.engine.remaining {
                Text(a.phase.label.uppercased()).font(.caption2).foregroundStyle(.secondary)
                Text(format(r)).font(.system(size: 34, weight: .light, design: .monospaced))
                    .foregroundStyle(r < 0 ? .orange : .primary)
                if let s = model.engine.session { Text(s.purpose).font(.caption).lineLimit(1) }
                HStack(spacing: 6) {
                    switch a.phase {
                    case .focus: small("Recall", model.startRecall)
                    case .recall: small("Rest", model.startRest)
                    default: EmptyView()
                    }
                    small(a.phase == .rest || a.phase == .rest_break ? "Done" : "Stop", model.end)
                }
            } else {
                Text("\(model.todayCount)/\(model.todayTotal) pomos today").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    small("Focus", model.beginFocusPrompt)
                    small("Recall", model.startRecall)
                    small("Rest", model.startRest)
                    small("Break", model.startBreak)
                }
            }
        }
        .padding(12)
        .frame(width: 220)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func small(_ t: String, _ action: @escaping () -> Void) -> some View {
        Button(t, action: action).buttonStyle(.bordered).controlSize(.small)
    }

    private func format(_ s: TimeInterval) -> String {
        let n = Int(abs(s).rounded(.up))
        return String(format: "%@%d:%02d", s < 0 ? "+" : "", n / 60, n % 60)
    }
}
