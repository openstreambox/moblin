import SwiftUI

struct BackpackSettingsView: View {
    let model: Model
    @ObservedObject var backpack: SettingsBackpack

    var body: some View {
        Form {
            Section {
                Text("""
                Shows a streaming backpack's status: links, battery, heat, the handover from your phone, \
                privacy modes and messages from your helpers.
                """)
            }
            Section {
                Toggle("Enabled", isOn: $backpack.enabled)
                    .onChange(of: backpack.enabled) { _ in
                        model.reloadBackpack()
                    }
                TextEditNavigationView(
                    title: String(localized: "URL"),
                    value: backpack.url,
                    onChange: isValidWebSocketUrl,
                    onSubmit: {
                        backpack.url = $0
                        model.reloadBackpack()
                    },
                    footers: [String(localized: "Leave empty to find a backpack on the local network.")],
                    placeholder: "ws://192.168.1.10:8796/ws"
                )
            }
            Section {
                Toggle("Read helper messages aloud", isOn: $backpack.readAloud)
            } footer: {
                Text("Urgent messages vibrate and are read aloud again every 20 seconds until you reply.")
            }
            Section {
                if backpack.dashboardToken.isEmpty {
                    Text("Not connected. On the dashboard, choose Connect a phone and scan its code with the Camera app.")
                } else {
                    LabeledContent("Dashboard", value: backpack.dashboardName)
                    Button(role: .destructive) {
                        model.leaveDashboard()
                    } label: {
                        Text("Disconnect from the dashboard")
                    }
                }
            } header: {
                Text("Dashboard")
            } footer: {
                Text("A dashboard keeps this phone's settings in step with the show. You can still change things " +
                    "here, and the dashboard sees what you changed.")
            }
        }
        .navigationTitle("Backpack")
    }
}
