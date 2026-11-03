import BlockerKit
import BlockerShared
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: ProtectionModel
    @State private var showingSetup = false
    @State private var personalizing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    header
                    StatusHero(showingSetup: $showingSetup, personalizing: $personalizing)

                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle(text: "What Hush quiets")
                        // A plain Grid, not LazyVGrid: with six tiles laziness buys
                        // nothing, and the lazy grid left the last row unbuilt.
                        Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                            GridRow {
                                categoryTile(.ads)
                                categoryTile(.privacy)
                            }
                            GridRow {
                                categoryTile(.annoyances)
                                categoryTile(.regional)
                            }
                            GridRow {
                                NavigationLink {
                                    YouTubeView()
                                } label: {
                                    YouTubeTile()
                                }
                                .buttonStyle(ChunkyCardStyle())
                                NavigationLink {
                                    CustomRulesView()
                                } label: {
                                    CategoryTile(category: .custom)
                                }
                                .buttonStyle(ChunkyCardStyle())
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle(text: "Make it yours")
                        Button {
                            personalizing = true
                        } label: {
                            ActionRow(icon: .fluent("sparkles"), title: "Personalize Hush", subtitle: "Answer the questions again.")
                        }
                        .buttonStyle(ChunkyCardStyle())
                        NavigationLink {
                            AllowlistView()
                        } label: {
                            ActionRow(icon: .fluent("check-mark"), title: "Allowed websites", subtitle: allowlistSubtitle)
                        }
                        .buttonStyle(ChunkyCardStyle())
                        NavigationLink {
                            AboutView()
                        } label: {
                            ActionRow(icon: .fluent("newspaper"), title: "About & licenses", subtitle: "Open source under the GPL.")
                        }
                        .buttonStyle(ChunkyCardStyle())
                    }

                    VStack(spacing: 8) {
                        Button {
                            Task { await model.updateAll() }
                        } label: {
                            HStack(spacing: 8) {
                                if model.isUpdating { ProgressView() }
                                Text(model.isUpdating ? "Updating…" : "Update filters")
                            }
                        }
                        .buttonStyle(ChunkyButtonStyle.secondary)
                        .disabled(model.isUpdating)
                        UpdateFooter()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await model.updateAll() }
            .sheet(isPresented: $showingSetup) {
                SetupGuideView()
                    .environmentObject(model)
            }
            .fullScreenCover(isPresented: $personalizing) {
                OnboardingView(personalizing: true)
                    .environmentObject(model)
            }
            .alert("Something went wrong", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.errorMessage ?? "")
            }
            .task {
                await model.refreshExtensionStates()
                // During onboarding the lists are only prefetched; compiling
                // waits for the user's answers so it happens once.
                if !model.showOnboarding {
                    await model.updateIfStale()
                }
            }
        }
        .fullScreenCover(isPresented: $model.showOnboarding) {
            OnboardingView()
                .environmentObject(model)
        }
    }

    private func categoryTile(_ category: BlockerCategory) -> some View {
        NavigationLink {
            CategoryView(category: category)
        } label: {
            CategoryTile(category: category)
        }
        .buttonStyle(ChunkyCardStyle())
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.hushTitle)
                    .foregroundStyle(Theme.text)
                Text("The internet. Without the noise.")
                    .font(.hushCaption)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 8)
            MascotView(mood: mascotMood, size: 80)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        let name = model.settings.userName
        return name.isEmpty ? part : "\(part), \(name)"
    }

    private var mascotMood: MascotMood {
        if model.requiredBlockers.isEmpty { return .thinking }
        return model.isFullyEnabled ? .happy : .worried
    }

    private var allowlistSubtitle: String {
        let count = model.settings.allowlist.count
        return count == 0 ? "Turn blocking off for specific sites." : "\(count) site\(count == 1 ? "" : "s")"
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }
}

// MARK: - Status

private struct StatusHero: View {
    @EnvironmentObject private var model: ProtectionModel
    @Environment(\.openURL) private var openURL
    @Binding var showingSetup: Bool
    @Binding var personalizing: Bool
    @State private var showingSteps = false

    private enum Status { case on, setup, empty }

    private var state: Status {
        if model.requiredBlockers.isEmpty { return .empty }
        return model.isFullyEnabled ? .on : .setup
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cornerRadius + 8, style: .continuous)
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.hushHeadline)
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(pill)
                    .font(.hushCaption)
                    .foregroundStyle(Color(hex: 0x1C1838))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(tint, in: Capsule())
            }
            Text(detail)
                .font(.hushBody)
                .foregroundStyle(Theme.secondaryText)
            NoiseWave(calm: state == .on, color: tint)
                .frame(height: 48)

            switch state {
            case .on:
                EmptyView()
            case .setup:
                Button("Turn on in Safari") {
                    SafariSettings.openExtensions(model.requiredExtensionIdentifiers, openURL: openURL) {
                        showingSteps = true
                    }
                }
                .buttonStyle(ChunkyButtonStyle(fill: Theme.warning, shade: Theme.warningShade, foreground: Color(hex: 0x1C1838)))
                Button("Show me how") { showingSetup = true }
                    .font(.hushBodyBold)
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            case .empty:
                Button("Personalize Hush") { personalizing = true }
                    .buttonStyle(ChunkyButtonStyle())
            }
        }
        .padding(24)
        .background(shape.fill(tint.opacity(0.12)))
        .background(shape.fill(Theme.surface))
        .overlay(shape.strokeBorder(tint, lineWidth: 2))
        .background(shape.fill(shade).offset(y: Theme.lip))
        .padding(.bottom, Theme.lip)
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $showingSteps) {
            SafariStepsSheet(extensionNames: model.requiredExtensionNames)
        }
    }

    private var tint: Color {
        switch state {
        case .on: return Theme.success
        case .setup: return Theme.warning
        case .empty: return Theme.primary
        }
    }

    private var shade: Color {
        switch state {
        case .on: return Theme.successShade
        case .setup: return Theme.warningShade
        case .empty: return Theme.primaryShade
        }
    }

    private var title: String {
        switch state {
        case .on: return "Hush is on"
        case .setup: return "Finish setting up"
        case .empty: return "Nothing to quiet yet"
        }
    }

    private var pill: String {
        switch state {
        case .on: return "Protected"
        case .setup: return "\(model.enabledSwitchCount) of \(model.requiredSwitchCount) on"
        case .empty: return "Paused"
        }
    }

    private var detail: String {
        switch state {
        case .on:
            let rules = model.requiredBlockers.compactMap { model.stats[$0]?.safariRules }.reduce(0, +)
            return rules > 0 ? "\(rules.counted("rule")) \(rules == 1 ? "is" : "are") quieting Safari." : "Safari is quieter already."
        case .setup:
            var text = "Some Safari switches are still off, so a few things can still get through."
            if model.settings.wantsYouTubeBlocking && model.youTubeEnabled == false {
                text += " Hush for YouTube is off too."
            }
            return text
        case .empty:
            return "Pick what to block and I'll take care of the rest."
        }
    }
}

// MARK: - Tiles and rows

private struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.hushHeadline)
            .foregroundStyle(Theme.text)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct CategoryTile: View {
    @EnvironmentObject private var model: ProtectionModel
    let category: BlockerCategory

    var body: some View {
        TileContent(icon: category.icon, tint: category.tint, title: category.shortTitle, subtitle: subtitle, warning: offInSafari)
    }

    private var offInSafari: Bool {
        model.requiredBlockers.contains(category) && !model.isExtensionEnabled(category)
    }

    private var subtitle: String {
        let rules = model.stats[category]?.safariRules ?? 0
        if !model.requiredBlockers.contains(category) { return "Not in use" }
        if offInSafari { return "Off in Safari" }
        return rules > 0 ? rules.counted("rule") : "Getting ready…"
    }
}

private struct YouTubeTile: View {
    @EnvironmentObject private var model: ProtectionModel

    var body: some View {
        TileContent(icon: .fluent("television"), tint: Theme.noise, title: "YouTube", subtitle: subtitle, warning: isOff)
    }

    private var isOff: Bool {
        model.settings.wantsYouTubeBlocking && model.youTubeEnabled == false
    }

    private var subtitle: String {
        if !model.settings.wantsYouTubeBlocking { return "Not in use" }
        return isOff ? "Off in Safari" : "Skips video ads"
    }
}

private struct TileContent: View {
    let icon: AppIcon
    let tint: Color
    let title: String
    let subtitle: String
    let warning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                IconBadge(icon: icon, tint: tint)
                Spacer()
                if warning {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.warning)
                        .accessibilityHidden(true)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.hushBodyBold)
                    .foregroundStyle(Theme.text)
                Text(subtitle)
                    .font(.hushCaption)
                    .foregroundStyle(warning ? Theme.warningShade : Theme.secondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

private struct ActionRow: View {
    let icon: AppIcon
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            IconBadge(icon: icon, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.hushBodyBold)
                    .foregroundStyle(Theme.text)
                Text(subtitle)
                    .font(.hushCaption)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }
}

private struct UpdateFooter: View {
    @EnvironmentObject private var model: ProtectionModel

    var body: some View {
        VStack(spacing: 4) {
            if let date = model.lastUpdated {
                Text("Filters updated \(date.formatted(.relative(presentation: .named))).")
            } else {
                Text("Filters haven't been downloaded yet.")
            }
            if !model.failedLists.isEmpty {
                Text("\(model.failedLists.count.counted("list")) couldn't update. Hush keeps using the last good copy.")
                    .foregroundStyle(Theme.warningShade)
            }
        }
        .font(.hushCaption)
        .foregroundStyle(Theme.secondaryText)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Category presentation

extension BlockerCategory {
    var icon: AppIcon {
        switch self {
        case .ads: return .fluent("megaphone")
        case .privacy: return .fluent("eyes")
        case .annoyances: return .fluent("cookie")
        case .regional: return .fluent("globe")
        case .custom: return .fluent("pencil")
        }
    }

    /// Compact name for tiles.
    var shortTitle: String {
        switch self {
        case .ads: return "Ads"
        case .privacy: return "Trackers"
        case .annoyances: return "Annoyances"
        case .regional: return "Languages"
        case .custom: return "Custom rules"
        }
    }

    var tint: Color {
        switch self {
        case .ads: return Theme.primary
        case .privacy: return Color(hex: 0x5B6CFF)
        case .annoyances: return Theme.warning
        case .regional: return Theme.success
        case .custom: return Color(hex: 0x8E8AA8)
        }
    }

    /// Plain-language explanation shown on the category screen.
    var explanation: String {
        switch self {
        case .ads:
            return "Ad scripts, banners and video ad servers are blocked before they download. Leftover empty ad boxes are hidden."
        case .privacy:
            return "Requests to analytics and tracking services are blocked, so they never see your visit."
        case .annoyances:
            return "Cookie consent prompts, newsletter pop-ups, \"open in app\" banners and chat widgets are hidden."
        case .regional:
            return "Extra lists for ads on sites in other languages."
        case .custom:
            return "Rules you write yourself in Adblock syntax."
        }
    }
}
