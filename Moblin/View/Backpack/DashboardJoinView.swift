import SwiftUI

// The box's power button: while this phone waits to connect, a
// double-press on the box finishes it. Never "The box stays on." until that
// is confirmed on both boards.
private struct DashboardPowerButtonView: View {
    let until: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = Int(until.timeIntervalSince(context.date).rounded(.up))
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "power.circle")
                    .font(.system(size: 34))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    if left > 0 {
                        Text("To show you're next to the box, double-press its power button.")
                            .font(.headline)
                        Text(left >= 59 ? String(localized: "You have 1 minute.") : String(localized: "\(left) s left"))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        Text("The minute for the power button is up.")
                            .font(.headline)
                        Text("You can still tap It matches on the dashboard.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

struct DashboardJoinView: View {
    let model: Model
    @ObservedObject var dashboard: DashboardProvider
    @ObservedObject var database: Database

    private func formatted(code: String) -> String {
        guard code.count == 6 else {
            return code
        }
        return "\(code.prefix(3)) \(code.suffix(3))"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                Text(dashboard.joinName)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                switch dashboard.joinState {
                case .none, .connecting:
                    ProgressView()
                    Text("Connecting to the dashboard…")
                        .foregroundStyle(.secondary)
                case let .waiting(code, buttonUntil):
                    if let buttonUntil {
                        Text("Check that the dashboard shows the same code.")
                            .multilineTextAlignment(.center)
                        Text(formatted(code: code))
                            .font(.system(size: 54, weight: .bold, design: .monospaced))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        DashboardPowerButtonView(until: buttonUntil)
                        Text("Or tap It matches on the dashboard.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Check that the dashboard shows the same code, then tap It matches there.")
                            .multilineTextAlignment(.center)
                        Text(formatted(code: code))
                            .font(.system(size: 54, weight: .bold, design: .monospaced))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Waiting for the dashboard…")
                        }
                        .foregroundStyle(.secondary)
                    }
                case .joined:
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .font(.title3.bold())
                        .foregroundStyle(.green)
                    Text("This phone is connected as \(database.appMode.toString()). Settings from the dashboard now arrive by themselves.")
                        .multilineTextAlignment(.center)
                    Button {
                        model.closeDashboardJoin()
                    } label: {
                        Text("Done")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                case let .failed(message):
                    Label(message, systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    Button("Close") {
                        model.closeDashboardJoin()
                    }
                }
                Spacer()
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if dashboard.joinState != .joined {
                        Button("Cancel") {
                            model.closeDashboardJoin()
                        }
                    }
                }
            }
        }
    }
}
