import SwiftUI

struct AboutSettingsView: View {
    @State var presentingVersionHistory: Bool = false

    var body: some View {
        Form {
            Section {
                TextItemLocalizedView(name: "Version", value: appVersion())
                NavigationLink {
                    AboutAttributionsSettingsView()
                } label: {
                    Text("Attributions")
                }
            }
            #if !MOBLIN_HIDE_MOBLIN_SERVICES
            Section {
                TextButtonView("Version history") {
                    presentingVersionHistory = true
                }
                .sheet(isPresented: $presentingVersionHistory) {
                    ZStack {
                        AboutVersionHistorySettingsView()
                        CloseButtonTopRightView {
                            presentingVersionHistory = false
                        }
                    }
                }
            }
            ExternalUrlButtonView(url: "https://moblin.app") {
                Text("Website")
            }
            ExternalUrlButtonView(url: "https://eerimoq.github.io/moblin/privacy-policy/en.html") {
                Text("Privacy policy")
            }
            #endif
            ExternalUrlButtonView(url: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                Text("End-user license agreement (EULA)")
            }
        }
        .navigationTitle("About")
    }
}
