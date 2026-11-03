import BlockerShared
import OSLog
import SafariServices
import SwiftUI

/// Apps cannot turn on Safari extensions themselves, so this walks the user
/// through Settings and shows live status for each content blocker.
struct SetupGuideView: View {
    @EnvironmentObject private var model: ProtectionModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingSteps = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if SafariSettings.canOpenExtensions {
                        SetupStep(number: 1, text: "Tap Open Safari Extensions below.")
                        SetupStep(number: 2, text: "Turn on every Hush extension, then come back here.")
                    } else {
                        SetupStep(number: 1, text: "Tap Open Settings below. It opens Hush's own page in Settings.")
                        SetupStep(number: 2, text: "Tap \(SafariSettings.backButton) at the top left.")
                        SetupStep(number: 3, text: "Tap Safari, then Extensions.")
                        SetupStep(number: 4, text: "Turn on every Hush extension listed below, then come back here.")
                    }
                    Button(SafariSettings.canOpenExtensions ? "Open Safari Extensions" : "Open Settings") {
                        SafariSettings.openExtensions(model.requiredExtensionIdentifiers, openURL: openURL) {
                            showingSteps = true
                        }
                    }
                } header: {
                    Text("Turn On in Safari")
                } footer: {
                    if !SafariSettings.canOpenExtensions {
                        Text("Before iOS 26.2, apps can only open their own settings page, so the last steps are manual.")
                    }
                }

                Section {
                    ForEach(model.requiredBlockers) { category in
                        StatusRow(name: "Hush \(category.title)", isOn: model.isExtensionEnabled(category))
                    }
                    if model.settings.wantsYouTubeBlocking {
                        StatusRow(name: "Hush for YouTube", isOn: model.youTubeEnabled)
                    }
                } header: {
                    Text("Needed for Your Choices")
                } footer: {
                    if model.settings.wantsYouTubeBlocking {
                        Text("For Hush for YouTube, tap it in Settings and set youtube.com to Allow under Permissions, so it runs every time.")
                    }
                }
            }
            .navigationTitle("Setup")
            .hushListBackground()
            .sheet(isPresented: $showingSteps) {
                SafariStepsSheet(extensionNames: model.requiredExtensionNames)
            }
            .toolbar {
                Button("Done") { dismiss() }
            }
            .task { await model.refreshExtensionStates() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await model.refreshExtensionStates() }
                }
            }
        }
    }
}

/// Opening Safari's extension settings from an app.
enum SafariSettings {
    private static let log = Logger(subsystem: "com.talhaarshad.hush", category: "SafariSettings")

    /// `SFSafariSettings.openExtensionsSettings` is public API from iOS 26.2.
    static var canOpenExtensions: Bool {
        if #available(iOS 26.2, *) { return true }
        return false
    }

    /// iOS 18 moved app settings, Safari included, under Settings › Apps.
    static var hasAppsMenu: Bool {
        if #available(iOS 18, *) { return true }
        return false
    }

    /// Back button shown on the app's own settings page.
    static var backButton: String { hasAppsMenu ? "‹ Apps" : "‹ Settings" }

    static var extensionsPath: String {
        hasAppsMenu ? "Settings › Apps › Safari › Extensions" : "Settings › Safari › Extensions"
    }

    /// One identifier opens that extension's page; several open the
    /// Extensions list with them highlighted.
    ///
    /// iOS limits how often an app may do this and then refuses with
    /// `SFErrorMaximumAttemptsExceeded` (seen after two attempts), and it is
    /// unavailable before iOS 26.2. In either case `onRefused` runs so the
    /// screen can show the manual path; without it, the app's own settings
    /// page opens.
    @MainActor
    static func openExtensions(_ identifiers: [String], openURL: OpenURLAction, onRefused: (() -> Void)? = nil) {
        let fallBack = {
            if let onRefused {
                onRefused()
            } else {
                openAppSettings(openURL)
            }
        }
        if #available(iOS 26.2, *) {
            SFSafariSettings.openExtensionsSettings(forIdentifiers: identifiers) { error in
                guard let error else { return }
                log.error("openExtensionsSettings failed for \(identifiers, privacy: .public): \(String(describing: error), privacy: .public)")
                fallBack()
            }
        } else {
            fallBack()
        }
    }

    static func openAppSettings(_ openURL: OpenURLAction) {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

/// The manual way to Safari's extension settings, for when iOS won't open
/// them directly.
struct SafariStepsSheet: View {
    let extensionNames: [String]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    MascotView(mood: .thinking, size: 72)
                    Text("Let's take the scenic route")
                        .font(.hushHeadline)
                        .foregroundStyle(Theme.text)
                }
                Text("iOS only lets apps jump straight to Safari's extensions a couple of times. It's three quick taps from here:")
                    .font(.hushBody)
                    .foregroundStyle(Theme.secondaryText)
                VStack(alignment: .leading, spacing: 16) {
                    ChunkyStep(number: 1, text: "Tap Open Settings below.")
                    ChunkyStep(number: 2, text: "Tap \(SafariSettings.backButton) at the top left.")
                    ChunkyStep(number: 3, text: "Tap Safari, then Extensions.")
                    ChunkyStep(number: 4, text: "Turn on \(ListFormatter.localizedString(byJoining: extensionNames)).")
                    if extensionNames.contains("Hush for YouTube") {
                        ChunkyStep(number: 5, text: "Tap Hush for YouTube. Under Permissions, set youtube.com to Allow so it always runs.")
                    }
                }
                .padding(20)
                .chunkyPanel()
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button("Open Settings") {
                    SafariSettings.openAppSettings(openURL)
                    dismiss()
                }
                .buttonStyle(ChunkyButtonStyle())
                Button("Close") { dismiss() }
                    .font(.hushBodyBold)
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Theme.background)
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.large])
    }
}

private struct ChunkyStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.hushBodyBold)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Theme.primary, in: Circle())
            Text(text)
                .font(.hushBody)
                .foregroundStyle(Theme.text)
        }
    }
}

private struct SetupStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor, in: Circle())
            Text(text)
        }
    }
}

struct YouTubeView: View {
    @EnvironmentObject private var model: ProtectionModel
    @Environment(\.openURL) private var openURL
    @State private var showingSteps = false

    var body: some View {
        List {
            Section {
                Text("YouTube serves ads from its own servers, so blocking network requests is not enough. A separate Safari extension, Hush for YouTube, runs on youtube.com instead.")
                    .foregroundStyle(.secondary)
                Toggle("Use Hush for YouTube", isOn: Binding(
                    get: { model.settings.wantsYouTubeBlocking },
                    set: { model.setWantsYouTube($0) }
                ))
                if model.settings.wantsYouTubeBlocking {
                    StatusRow(name: "Hush for YouTube in Safari", isOn: model.youTubeEnabled)
                }
            }

            if model.settings.wantsYouTubeBlocking {
                Section {
                    if SafariSettings.canOpenExtensions {
                        SetupStep(number: 1, text: "Tap Open Hush for YouTube below.")
                    } else {
                        SetupStep(number: 1, text: "Open \(SafariSettings.extensionsPath) › Hush for YouTube.")
                    }
                    SetupStep(number: 2, text: "Turn on the switch at the top.")
                    SetupStep(number: 3, text: "Under Permissions, tap youtube.com and choose Allow. This lets it run every time without asking.")
                    Button(SafariSettings.canOpenExtensions ? "Open Hush for YouTube" : "Open Settings") {
                        SafariSettings.openExtensions([model.youTubeExtensionIdentifier], openURL: openURL) {
                            showingSteps = true
                        }
                    }
                } header: {
                    Text("Turn It On and Always Allow")
                } footer: {
                    Text("If youtube.com isn't listed yet, open YouTube in Safari once, then come back. Choosing Allow for Other Websites also works, but Hush only ever runs on YouTube.")
                }

                Section {
                    SetupStep(number: 1, text: "Open youtube.com in Safari.")
                    SetupStep(number: 2, text: "Tap the page menu at the left of the address bar.")
                    SetupStep(number: 3, text: "Tap Hush for YouTube, then Always Allow… › Always Allow on This Website.")
                } header: {
                    Text("Or Allow It From Safari")
                }
            }

            Section("What It Does") {
                Label("Hides ad slots in feeds, search and the watch page", systemImage: "eye.slash")
                Label("Mutes and fast-forwards video ads, then taps Skip", systemImage: "forward.end")
                Label("Dismisses the \"ad blockers are not allowed\" dialog", systemImage: "xmark.circle")
            }

            Section {
                Text("YouTube changes its page often, so this can stop working until the app is updated.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("YouTube Ads")
        .hushListBackground()
        .sheet(isPresented: $showingSteps) {
            SafariStepsSheet(extensionNames: ["Hush for YouTube"])
        }
        .task { await model.refreshExtensionStates() }
    }
}

/// One extension's state in the setup guide. `isOn == nil` means iOS can't
/// report it, so the row says so instead of guessing.
private struct StatusRow: View {
    let name: String
    let isOn: Bool?

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Image(systemName: isOn == true ? "checkmark.circle.fill" : isOn == false ? "circle" : "questionmark.circle")
                .foregroundStyle(isOn == true ? .green : .secondary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isOn == true ? "On" : isOn == false ? "Off" : "Unknown")
    }
}
