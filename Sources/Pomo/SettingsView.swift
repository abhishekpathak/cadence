import SwiftUI
import PomoCore

/// Whole-minute durations for each phase. Edits apply from the next phase that starts.
struct SettingsView: View {
    @ObservedObject var model: Model

    private static let ink = Color(white: 0.12)
    private static let subtle = Color(white: 0.45)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Durations")
                .font(.rounded(18, .semibold)).foregroundStyle(Self.ink)
            VStack(spacing: 12) {
                row(.focus)
                row(.recall)
                row(.rest)
                row(.rest_break)
            }
            Text("Whole minutes, \(Model.minuteRange.lowerBound)–\(Model.minuteRange.upperBound). Changes apply from the next phase you start.")
                .font(.rounded(12)).foregroundStyle(Self.subtle)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(action: model.resetMinutes) {
                    Text("Reset to defaults").font(.rounded(14, .medium)).foregroundStyle(Self.subtle)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(width: 320)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private func row(_ phase: Phase) -> some View {
        HStack(spacing: 8) {
            Text(phase.label).font(.rounded(15, .medium)).foregroundStyle(Self.ink)
            Spacer()
            TextField("", value: Binding(get: { model.minutes[phase] ?? 0 },
                                         set: { model.setMinutes($0, for: phase) }),
                      format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder).font(.rounded(15))
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
            Text("min").font(.rounded(14)).foregroundStyle(Self.subtle).frame(width: 30, alignment: .leading)
        }
    }
}
