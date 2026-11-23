import SwiftUI

private let minimumLevel: Float = -70

private struct FindMicLevelView: View {
    @ObservedObject var findMic: FindMic

    private func trendText() -> String {
        switch findMic.trend {
        case .hotter:
            String(localized: "Hotter")
        case .colder:
            String(localized: "Colder")
        case .steady:
            String(localized: "Steady")
        }
    }

    private func trendImage() -> String {
        switch findMic.trend {
        case .hotter:
            "flame.fill"
        case .colder:
            "snowflake"
        case .steady:
            "equal"
        }
    }

    private func trendColor() -> Color {
        switch findMic.trend {
        case .hotter:
            .red
        case .colder:
            .blue
        case .steady:
            .secondary
        }
    }

    var body: some View {
        if let level = findMic.level, level.isHeard {
            VStack(spacing: 10) {
                Text("\(formatOneDecimal(level.level)) dB")
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                ProgressView(value: Double((level.level - minimumLevel) / -minimumLevel).clamped(to: 0 ... 1))
                    .tint(trendColor())
                Label(trendText(), systemImage: trendImage())
                    .font(.title3)
                    .foregroundStyle(trendColor())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        } else {
            Text(findMic.level == nil ? "Listening…" : "Not heard")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
    }
}

struct FindMicSettingsView: View {
    let model: Model
    @ObservedObject var findMic: FindMic

    var body: some View {
        let candidates = model.findMicCandidates()
        Form {
            Section {
                Picker("Mic", selection: $findMic.micId) {
                    ForEach(candidates) { candidate in
                        Text(candidate.name)
                            .tag(candidate.id as String?)
                    }
                }
                .onChange(of: findMic.micId) { _ in
                    if findMic.isFinding {
                        model.startFindMic()
                    }
                }
                Button {
                    if findMic.isFinding {
                        model.stopFindMic()
                    } else {
                        model.startFindMic()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text(findMic.isFinding ? "Stop" : "Find mic")
                        Spacer()
                    }
                }
                if findMic.isFinding {
                    FindMicLevelView(findMic: findMic)
                }
            } footer: {
                Text("""
                Plays a chirp on the speaker twice a second and shows how loud the mic hears it. Walk \
                around with the phone: hotter means closer. Viewers hear the chirp if you are live.
                """)
            }
            Section {
                Button {
                    if findMic.isPinging {
                        model.stopFindMic()
                    } else {
                        model.pingFindMic()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text(findMic.isPinging ? "Stop" : "Ping")
                        Spacer()
                    }
                }
            } footer: {
                Text("Plays the chirp on the connected headphones or speaker, so you can find them by ear.")
            }
            if let message = findMic.message {
                Section {
                    Text(message)
                }
            }
        }
        .navigationTitle("Find mic")
        .onAppear {
            if findMic.micId == nil || !candidates.contains(where: { $0.id == findMic.micId }) {
                findMic.micId = candidates.first?.id
            }
        }
        .onDisappear {
            model.stopFindMic()
        }
    }
}
