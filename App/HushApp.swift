import BackgroundTasks
import SwiftUI

@main
struct HushApp: App {
    @StateObject private var model = ProtectionModel.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(model)
                .fontDesign(.rounded)
                .tint(Theme.primary)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // The user may have just toggled extensions in Settings.
                Task { await model.refreshExtensionStates() }
            case .background:
                BackgroundRefresh.schedule()
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            BackgroundRefresh.schedule()
            await ProtectionModel.shared.updateAll()
        }
    }
}

/// Keeps filter lists fresh while the app is closed. iOS decides when the task
/// actually runs; the identifier is listed in Info.plist.
enum BackgroundRefresh {
    static let identifier = (Bundle.main.bundleIdentifier ?? "") + ".refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
