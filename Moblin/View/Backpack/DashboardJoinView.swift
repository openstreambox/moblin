import SwiftUI

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
                case let .waiting(code):
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
