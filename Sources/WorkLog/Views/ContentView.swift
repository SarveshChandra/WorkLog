import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            TopBarView(selection: $store.selectedSection)
            Divider()

            Group {
                switch store.selectedSection {
                case .dashboard:
                    DashboardView()
                case .workExperience:
                    WorkExperienceView()
                case .interviewTracker:
                    InterviewTrackerView()
                case .documents:
                    DocumentsView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // With `.windowStyle(.hiddenTitleBar)` the system may reserve a top inset; we want our
        // custom topbar to sit flush to the top.
        .ignoresSafeArea(.container, edges: .top)
        .preferredColorScheme(store.theme.colorScheme)
        .tint(.workLogSkyBlue)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
