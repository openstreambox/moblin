import SwiftUI

private struct StreamButtonText: View {
    @ObservedObject var database: Database
    let text: String

    var body: some View {
        Text(text)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(.white)
            .frame(minWidth: 60)
            .padding(5)
            .background(database.streamButtonColorColor)
            .cornerRadius(10)
    }
}

private struct EndButtonView: View {
    @EnvironmentObject var model: Model
    @Binding var presentingGoLiveNotificationConfirm: Bool
    @State private var presentingStopConfirm = false

    var body: some View {
        // To the rig's hub, ending this phone's stream only disconnects it:
        // the hub holds the platform output.
        StreamButtonText(database: model.database,
                         text: model.isCurrentStreamHub() ? String(localized: "Disconnect") : String(localized: "End"))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white)
            )
            .onTapGesture {
                presentingStopConfirm = true
            }
            .onLongPressGesture {
                model.toggleShowingPanel(type: nil, panel: .streamingButtonSettings)
            }
            .confirmationDialog("", isPresented: $presentingGoLiveNotificationConfirm) {
                Button("Send Go live notification") {
                    model.sendGoLiveNotification()
                }
            }
            .confirmationDialog(model.isCurrentStreamHub() && model.hubProgramIsThisPhone()
                ? String(localized: "Viewers see this phone right now. If it disconnects, the hub shows its standby picture and stays live.")
                : "",
                isPresented: $presentingStopConfirm,
                titleVisibility: model.isCurrentStreamHub() && model.hubProgramIsThisPhone() ? .visible : .hidden)
            {
                if model.isCurrentStreamHub() {
                    Button("Disconnect this phone") {
                        _ = model.stopStream()
                    }
                } else if model.stream.obsAutoStopStream, model.stream.obsAutoStopRecording {
                    Button("End but leave OBS streaming and recording") {
                        _ = model.stopStream(stopObsStreamIfEnabled: false, stopObsRecordingIfEnabled: false)
                    }
                } else if model.stream.obsAutoStopStream {
                    Button("End but leave OBS streaming") {
                        _ = model.stopStream(stopObsStreamIfEnabled: false)
                    }
                } else if model.stream.obsAutoStopRecording {
                    Button("End but leave OBS recording") {
                        _ = model.stopStream(stopObsRecordingIfEnabled: false)
                    }
                }
                if !model.isCurrentStreamHub() {
                    Button("End") {
                        _ = model.stopStream()
                    }
                }
            }
    }
}

private struct GoLiveButtonView: View {
    @EnvironmentObject var model: Model
    @Binding var presentingGoLiveNotificationConfirm: Bool
    @State private var presentingGoLiveConfirm = false

    var body: some View {
        StreamButtonText(database: model.database,
                         text: model.isCurrentStreamHub() ? String(localized: "Connect") : String(localized: "Go Live"))
            .onTapGesture {
                if model.isCurrentStreamHub() {
                    // Connecting to the rig's hub isn't going live: viewers see nothing new.
                    model.hubConnect()
                } else {
                    presentingGoLiveConfirm = true
                }
            }
            .onLongPressGesture {
                model.toggleShowingPanel(type: nil, panel: .streamingButtonSettings)
            }
            .confirmationDialog("You are about to go live to '\(model.stream.name)'!",
                                isPresented: $presentingGoLiveConfirm,
                                titleVisibility: .visible)
            {
                Button("Go Live") {
                    model.startStream()
                    if model.isGoLiveNotificationConfigured() {
                        presentingGoLiveNotificationConfirm = true
                    }
                }
            }
    }
}

private struct SetupButtonView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some View {
        StreamButtonText(database: model.database, text: String(localized: "Setup"))
            .onTapGesture {
                model.resetWizard()
                createStreamWizard.presentingSetup = true
            }
            .onLongPressGesture {
                model.toggleShowingPanel(type: nil, panel: .streamingButtonSettings)
            }
            .sheet(isPresented: $createStreamWizard.presentingSetup) {
                NavigationStack {
                    StreamWizardSettingsView(model: model, createStreamWizard: createStreamWizard)
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
    }
}

// To the rig's hub the button follows what the hub reports about this
// phone, so it never says Connect while the status says connected.
private struct HubStreamButtonView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var hub: HubProvider
    @Binding var presentingGoLiveNotificationConfirm: Bool

    var body: some View {
        switch model.hubControlList().feed {
        case .disconnecting:
            StreamButtonText(database: model.database, text: String(localized: "Disconnecting…"))
                .opacity(0.6)
        case .connected:
            EndButtonView(presentingGoLiveNotificationConfirm: $presentingGoLiveNotificationConfirm)
        case .connecting:
            if model.isLive {
                EndButtonView(presentingGoLiveNotificationConfirm: $presentingGoLiveNotificationConfirm)
            } else {
                StreamButtonText(database: model.database, text: String(localized: "Connecting…"))
                    .opacity(0.6)
            }
        case .connect, nil:
            if model.isLive {
                EndButtonView(presentingGoLiveNotificationConfirm: $presentingGoLiveNotificationConfirm)
            } else {
                GoLiveButtonView(presentingGoLiveNotificationConfirm: $presentingGoLiveNotificationConfirm)
            }
        }
    }
}

struct StreamButton: View {
    @EnvironmentObject var model: Model
    @ObservedObject var show: Show
    @State private var presentingGoLiveNotificationConfirm = false

    var body: some View {
        if model.isCurrentStreamHub() {
            HubStreamButtonView(hub: model.hub,
                                presentingGoLiveNotificationConfirm: $presentingGoLiveNotificationConfirm)
                .disabled(show.chatPhone)
                .opacity(show.chatPhone ? 0.5 : 1)
        } else if model.isLive {
            EndButtonView(presentingGoLiveNotificationConfirm: $presentingGoLiveNotificationConfirm)
                .disabled(show.chatPhone)
                .opacity(show.chatPhone ? 0.5 : 1)
        } else if model.isStreamConfigured() {
            GoLiveButtonView(presentingGoLiveNotificationConfirm: $presentingGoLiveNotificationConfirm)
                .disabled(show.chatPhone)
                .opacity(show.chatPhone ? 0.5 : 1)
        } else {
            SetupButtonView(createStreamWizard: model.createStreamWizard)
        }
    }
}
