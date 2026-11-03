import BlockerKit
import BlockerShared
import SwiftUI

/// First-run setup, one question per screen, hosted by the mascot. Answers
/// pick the filter lists; the last steps switch the needed extensions on in
/// Safari and celebrate. Re-runnable from the home screen.
struct OnboardingView: View {
    enum Step: Int {
        case welcome, name, interests, noise, languages, building, plan, safari, celebrate
    }

    @EnvironmentObject private var model: ProtectionModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: Step
    @State private var forward = true
    @State private var name = ""
    @State private var interests: Set<BrowsingInterest> = []
    @State private var noise: Set<NoiseSource> = []
    @State private var noiseStart: Set<NoiseSource> = []
    @State private var recommended: Set<NoiseSource> = []
    @State private var noiseEdited = false
    @State private var languages: Set<String> = []
    @State private var mood: MascotMood = .idle
    @State private var reaction = 0
    @State private var bubble = ""
    @State private var loaded = false
    @State private var hushed = false
    @State private var buildItems: [BuildItem] = []
    @State private var shownProgress: Double = 0
    @State private var creepTask: Task<Void, Never>?
    @State private var buildDone = false
    @State private var buildTask: Task<Void, Never>?
    @State private var showingSafariSteps = false
    /// Set when nothing could be built, usually because there's no connection.
    @State private var buildFailed = false
    @FocusState private var nameFocused: Bool

    private let isPersonalizing: Bool

    init(personalizing: Bool = false) {
        isPersonalizing = personalizing
        _step = State(initialValue: personalizing ? .name : .welcome)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                if step != .welcome && step != .celebrate {
                    topBar
                }
                ScrollView {
                    content
                        .id(step)
                        .transition(stepTransition)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            if step == .celebrate && model.isFullyEnabled {
                ConfettiView().ignoresSafeArea()
            }
        }
        .safeAreaInset(edge: .bottom) { footer }
        .sheet(isPresented: $showingSafariSteps) {
            SafariStepsSheet(extensionNames: model.requiredExtensionNames)
        }
        .onAppear(perform: load)
        .onChange(of: model.enabledExtensionCount) { old, new in
            if new > old { extensionTurnedOn() }
        }
        .onChange(of: model.youTubeEnabled) { old, new in
            if new == true && old != true { extensionTurnedOn() }
        }
        .onChange(of: model.isFullyEnabled) { _, isOn in
            guard isOn, step == .safari else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                if step == .safari { go(.celebrate) }
            }
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: welcome
        case .name: nameStep
        case .interests: interestsStep
        case .noise: noiseStep
        case .languages: languagesStep
        case .building: buildingStep
        case .plan: planStep
        case .safari: safariStep
        case .celebrate: celebrateStep
        }
    }

    private var welcome: some View {
        VStack(spacing: 32) {
            ZStack {
                NoiseOrbit(hushed: hushed)
                MascotView(mood: hushed ? .shush : .idle, size: 160, reaction: reaction)
            }
            .frame(height: 300)
            .padding(.top, 32)

            VStack(spacing: 8) {
                Text("Hush")
                    .font(.hushTitle)
                    .foregroundStyle(Theme.text)
                Text("The internet. Without the noise.")
                    .font(.hushHeadline)
                    .foregroundStyle(Theme.primary)
            }
            Text("Answer a few quick questions and I'll set up Safari just for you.")
                .font(.hushBody)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            mascotHeader
            TextField("Your first name", text: $name)
                .font(.hushHeadline)
                .foregroundStyle(Theme.text)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($nameFocused)
                .onSubmit(primaryAction)
                .onChange(of: name) { _, value in
                    if value.count > 24 { name = String(value.prefix(24)) }
                }
                .padding(16)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .strokeBorder(nameFocused ? Theme.primary : Theme.border, lineWidth: 2)
                )
            Label("Only used to greet you. It never leaves this iPhone.", systemImage: "lock.fill")
                .font(.hushCaption)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private var interestsStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            mascotHeader
            VStack(spacing: 12) {
                ForEach(BrowsingInterest.allCases) { interest in
                    OptionCard(icon: interest.icon, title: interest.title, isSelected: interests.contains(interest)) {
                        toggle(interest, in: &interests)
                        mood = .happy
                        reaction += 1
                    }
                }
            }
        }
    }

    private var noiseStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            mascotHeader
            VStack(spacing: 12) {
                ForEach(NoiseSource.allCases) { source in
                    OptionCard(
                        icon: source.icon,
                        title: source.title,
                        subtitle: source.detail,
                        badge: recommended.contains(source) ? "Recommended for you" : nil,
                        tint: source.tint,
                        isSelected: noise.contains(source)
                    ) {
                        noiseEdited = true
                        let added = toggle(source, in: &noise)
                        bubble = added ? source.reaction : "Okay, I'll leave those alone."
                        mood = added ? .excited : .idle
                        reaction += 1
                    }
                }
            }
        }
    }

    private var languagesStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            mascotHeader
            VStack(spacing: 12) {
                ForEach(FilterCatalog.lists(in: .regional)) { list in
                    OptionCard(
                        icon: RegionalLanguage.icon(for: list.id),
                        title: list.name,
                        tint: Theme.success,
                        isSelected: languages.contains(list.id)
                    ) {
                        toggle(list.id, in: &languages)
                        mood = .happy
                        reaction += 1
                    }
                }
            }
        }
    }

    private var buildingStep: some View {
        VStack(spacing: 24) {
            MascotView(mood: buildFailed ? .worried : buildDone ? .excited : .thinking, size: 140, reaction: reaction)
                .padding(.top, 16)
            SpeechBubble(text: bubble)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(stageText)
                        .font(.hushBodyBold)
                        .foregroundStyle(Theme.text)
                    Spacer(minLength: 8)
                    Text("\(percent)%")
                        .font(.hushBodyBold.monospacedDigit())
                        .foregroundStyle(Theme.success)
                        .contentTransition(.numericText())
                        .animation(.default, value: percent)
                }
                LoadingBar(progress: shownProgress)
            }
            .padding(20)
            .chunkyPanel()

            VStack(alignment: .leading, spacing: 16) {
                ForEach(buildItems) { item in
                    BuildRow(text: item.title, status: status(of: item))
                }
                if buildDone {
                    BuildRow(text: "\(readyRuleCount.counted("blocking rule")) ready", status: .done, highlighted: true)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: buildDone)
        }
        .onChange(of: model.buildProgress) { _, update in
            if let update { advance(to: update) }
        }
    }

    private var planStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            mascotHeader
            VStack(alignment: .leading, spacing: 16) {
                Text(name.isEmpty ? "Your Hush plan" : "\(name)'s Hush plan")
                    .font(.hushHeadline)
                    .foregroundStyle(Theme.text)

                PlanSection(title: "Quieting") {
                    FlowLayout {
                        ForEach(NoiseSource.allCases.filter(noise.contains)) { source in
                            Chip(icon: source.icon, title: source.title)
                        }
                    }
                }

                if noise.contains(.ads) {
                    PlanSection(title: "Reading in") {
                        FlowLayout {
                            Chip(icon: RegionalLanguage.english, title: "English")
                            ForEach(FilterCatalog.lists(in: .regional).filter { languages.contains($0.id) }) { list in
                                Chip(icon: RegionalLanguage.icon(for: list.id), title: list.name)
                            }
                        }
                    }
                }

                Divider().overlay(Theme.border)

                PlanFact(symbol: "switch.2", text: "\(switchCountText) to flip in Safari, about 30 seconds")
                if model.isUpdating {
                    PlanFact(symbol: "arrow.triangle.2.circlepath", text: "Finishing your filters in the background…")
                } else if readyRuleCount > 0 {
                    PlanFact(symbol: "checkmark.shield.fill", text: "\(readyRuleCount.counted("blocking rule")) ready")
                }
            }
            .padding(24)
            .chunkyPanel()
        }
    }

    private var safariStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            mascotHeader
            if !model.requiredExtensionIdentifiers.isEmpty {
                VStack(spacing: 0) {
                    ForEach(model.requiredBlockers) { category in
                        SwitchRow(icon: category.icon, name: "Hush \(category.title)", isOn: model.isExtensionEnabled(category))
                        if category != model.requiredBlockers.last || model.settings.wantsYouTubeBlocking {
                            Divider().overlay(Theme.border).padding(.leading, 64)
                        }
                    }
                    if model.settings.wantsYouTubeBlocking {
                        SwitchRow(icon: .fluent("television"), name: "Hush for YouTube", isOn: model.youTubeEnabled)
                    }
                }
                .chunkyPanel()

                VStack(alignment: .leading, spacing: 8) {
                    Label("In Settings, flip each switch on. I'll tick them off here.", systemImage: "hand.tap.fill")
                    if model.settings.wantsYouTubeBlocking {
                        Label("Then tap Hush for YouTube in Settings. Under Permissions, set youtube.com to Allow so it runs every time.", systemImage: "play.rectangle.fill")
                    }
                }
                .font(.hushCaption)
                .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private var celebrateStep: some View {
        VStack(spacing: 24) {
            MascotView(mood: model.isFullyEnabled ? .shush : .worried, size: 180, reaction: reaction)
                .padding(.top, 64)
            VStack(spacing: 12) {
                Text(celebrateTitle)
                    .font(.hushTitle)
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                Text(celebrateMessage)
                    .font(.hushBody)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            if model.isFullyEnabled {
                NoiseWave(calm: true, color: Theme.success)
                    .frame(height: 40)
                    .padding(.horizontal, 32)
            }
        }
    }

    private var mascotHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            MascotView(mood: mood, size: 96, reaction: reaction)
            SpeechBubble(text: bubble)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack(spacing: 16) {
            Button(action: goBack) {
                Image(systemName: backIsClose ? "xmark" : "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(backIsClose ? "Close" : "Back")
            .opacity(previousStep != nil || backIsClose ? 1 : 0)
            .disabled(previousStep == nil && !backIsClose)
            ProgressTrack(progress: progress)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var footer: some View {
        if step != .building || buildFailed {
            VStack(spacing: 8) {
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(ChunkyButtonStyle())
                    .disabled(step == .noise && noise.isEmpty)
                if let secondary = secondaryTitle {
                    Button(secondary, action: secondaryAction)
                        .font(.hushBodyBold)
                        .foregroundStyle(Theme.primary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .background(Theme.background.opacity(0.96))
        }
    }

    // MARK: - Navigation

    private var progressSteps: [Step] {
        [.name, .interests, .noise] + (noise.contains(.ads) ? [.languages] : []) + [.building, .plan, .safari]
    }

    private var progress: Double {
        guard let index = progressSteps.firstIndex(of: step) else { return 0 }
        return Double(index + 1) / Double(progressSteps.count)
    }

    private var previousStep: Step? {
        switch step {
        case .welcome, .building, .celebrate: return nil
        case .name: return isPersonalizing ? nil : .welcome
        case .interests: return .name
        case .noise: return .interests
        case .languages: return .noise
        case .plan: return noise.contains(.ads) ? .languages : .noise
        case .safari: return .plan
        }
    }

    private var backIsClose: Bool {
        isPersonalizing && previousStep == nil && step != .building
    }

    private var stepTransition: AnyTransition {
        if reduceMotion { return .opacity }
        let insertion: Edge = forward ? .trailing : .leading
        return .asymmetric(
            insertion: .move(edge: insertion).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: return "Get started"
        case .name: return trimmedName.isEmpty ? "Skip" : "Continue"
        case .interests: return interests.isEmpty ? "Skip" : "Continue"
        case .noise, .languages: return "Continue"
        case .building: return buildFailed ? "Try again" : ""
        case .plan: return "Switch Hush on"
        case .safari: return safariDone ? "Continue" : "Open Safari settings"
        case .celebrate: return "Start browsing"
        }
    }

    private var secondaryTitle: String? {
        switch step {
        case .building: return buildFailed ? "Continue anyway" : nil
        case .safari: return safariDone ? nil : "I'll do it later"
        case .celebrate: return model.isFullyEnabled ? "Test it in Safari" : nil
        default: return nil
        }
    }

    private var safariDone: Bool {
        model.isFullyEnabled || model.requiredExtensionIdentifiers.isEmpty
    }

    private func primaryAction() {
        switch step {
        case .welcome:
            Haptics.pop()
            hushed = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: reduceMotion ? 0 : 750_000_000)
                go(.name)
            }
        case .name:
            name = trimmedName
            model.settings.userName = name
            nameFocused = false
            go(.interests)
        case .interests:
            go(.noise)
        case .noise:
            go(noise.contains(.ads) ? .languages : .building)
        case .languages:
            go(.building)
        case .building:
            if buildFailed { startBuilding() }
        case .plan:
            go(.safari)
        case .safari:
            if safariDone {
                go(.celebrate)
            } else {
                SafariSettings.openExtensions(model.requiredExtensionIdentifiers, openURL: openURL) {
                    showingSafariSteps = true
                }
            }
        case .celebrate:
            model.finishOnboarding()
            dismiss()
        }
    }

    private func secondaryAction() {
        switch step {
        case .building:
            buildFailed = false
            go(.plan)
        case .safari:
            go(.celebrate)
        case .celebrate:
            if let url = URL(string: "https://d3ward.github.io/toolz/adblock") {
                openURL(url)
            }
        default:
            break
        }
    }

    private func goBack() {
        if let previous = previousStep {
            go(previous, forward: false)
        } else if backIsClose {
            dismiss()
        }
    }

    private func go(_ next: Step, forward: Bool = true) {
        if step == .building { buildTask?.cancel() }
        self.forward = forward
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.86)) {
            step = next
        }
        enter(next)
    }

    /// Sets what the mascot says and does on arriving at a step.
    private func enter(_ step: Step) {
        switch step {
        case .welcome:
            mood = .idle
        case .name:
            mood = .idle
            bubble = isPersonalizing && !name.isEmpty
                ? "Let's tune things up. Still \(name)?"
                : "First things first. What should I call you?"
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                nameFocused = true
            }
        case .interests:
            mood = .happy
            reaction += 1
            bubble = name.isEmpty
                ? "Nice to meet you! What do you use Safari for?"
                : "Nice to meet you, \(name)! What do you use Safari for?"
        case .noise:
            recommended = interests.reduce(into: Set<NoiseSource>()) { $0.formUnion($1.recommends) }
            if !noiseEdited {
                noise = noiseStart.union(recommended)
            }
            mood = .idle
            bubble = interests.isEmpty
                ? "What drives you up the wall?"
                : "Based on that, I'd quiet these. Change anything you like."
        case .languages:
            mood = .thinking
            bubble = "Which languages do you read? English is always covered."
        case .building:
            startBuilding()
        case .plan:
            mood = .happy
            reaction += 1
            bubble = name.isEmpty ? "Here's your plan!" : "Here's your plan, \(name)!"
        case .safari:
            mood = .excited
            reaction += 1
            bubble = model.requiredExtensionIdentifiers.isEmpty
                ? "You didn't pick anything, so there's nothing to switch on."
                : "Last step! Flip my \(switchCountText) in Safari. I'll wait right here."
        case .celebrate:
            if model.isFullyEnabled { Haptics.success() }
            reaction += 1
        }
    }

    // MARK: - Building

    /// Applies the answers and waits for the real compile, showing its
    /// progress. Stays up at least 1.5 s so the screen can be read.
    private func startBuilding() {
        mood = .thinking
        bubble = "Give me a sec… tuning your filters."
        buildDone = false
        buildFailed = false
        shownProgress = 0
        buildItems = buildChecklist()
        let choice = chosenFilters()

        buildTask?.cancel()
        buildTask = Task { @MainActor in
            let started = Date()
            await model.applyPersonalization(enabledFilterIDs: choice.ids, wantsYouTube: choice.youTube)
            let remaining = 1.5 - Date().timeIntervalSince(started)
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
            if Task.isCancelled { return }
            creepTask?.cancel()
            // Nothing built but the user chose something to block: the lists
            // couldn't be downloaded. Say so instead of claiming success.
            if readyRuleCount == 0 && !model.requiredBlockers.isEmpty && !model.failedLists.isEmpty {
                buildFailed = true
                mood = .worried
                reaction += 1
                bubble = "I couldn't download the filters. Check your internet connection and try again."
                return
            }
            withAnimation(.easeOut(duration: 0.3)) { shownProgress = 1 }
            buildDone = true
            mood = .excited
            reaction += 1
            bubble = model.failedLists.isEmpty
                ? "Done! Your filters are ready."
                : "Done! A few lists couldn't update, but you're covered."
            Haptics.success()
            try? await Task.sleep(nanoseconds: 900_000_000)
            if !Task.isCancelled { go(.plan) }
        }
    }

    /// Moves the bar to the real progress, then eases it towards the end of
    /// the current stage so long stages don't look frozen.
    private func advance(to update: ProtectionProgress) {
        guard step == .building, !buildDone else { return }
        withAnimation(.easeOut(duration: 0.35)) {
            shownProgress = max(shownProgress, update.fraction)
        }
        creepTask?.cancel()
        let target = update.stageEndFraction - 0.01
        guard target > shownProgress else { return }
        creepTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 8)) {
                shownProgress = max(shownProgress, target)
            }
        }
    }

    /// One row per piece of real work, in the order the engine does it.
    private func buildChecklist() -> [BuildItem] {
        var items = [BuildItem(kind: .download, title: "Downloading the latest filter lists")]
        let languageNames = FilterCatalog.lists(in: .regional).filter { languages.contains($0.id) }.map(\.name)
        for category in BlockerCategory.allCases {
            switch category {
            case .ads where noise.contains(.ads):
                items.append(BuildItem(kind: .category(.ads), title: "Picking ad filters"))
            case .privacy where noise.contains(.trackers):
                items.append(BuildItem(kind: .category(.privacy), title: "Blocking trackers"))
            case .annoyances:
                // The phishing list compiles into the Annoyances blocker.
                if noise.contains(.popups) || noise.contains(.chatWidgets) || noise.contains(.socialButtons) {
                    let title = noise.contains(.popups) ? "Hiding cookie prompts & pop-ups" : "Clearing widgets & buttons"
                    items.append(BuildItem(kind: .category(.annoyances), title: title))
                }
                if noise.contains(.scams) {
                    items.append(BuildItem(kind: .category(.annoyances), title: "Watching for scam sites"))
                }
            case .regional where noise.contains(.ads) && !languageNames.isEmpty:
                items.append(BuildItem(kind: .category(.regional),
                                       title: "Adding \(ListFormatter.localizedString(byJoining: languageNames)) filters"))
            case .custom where !model.settings.customRules.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
                items.append(BuildItem(kind: .category(.custom), title: "Applying your custom rules"))
            default:
                break
            }
        }
        if noise.contains(.youtube) {
            items.append(BuildItem(kind: .youtube, title: "Teaching YouTube to skip ads"))
        }
        return items
    }

    private func status(of item: BuildItem) -> BuildRow.Status {
        if buildDone { return .done }
        guard let progress = model.buildProgress else {
            return item.kind == .download ? .active : .pending
        }
        switch item.kind {
        case .download:
            if case .downloading = progress.stage { return .active }
            return .done
        case .category(let category):
            if progress.compiled.contains(category) || progress.stage == .finished { return .done }
            return progress.stage == .compiling(category) ? .active : .pending
        case .youtube:
            return progress.stage == .finished ? .done : .pending
        }
    }

    private var stageText: String {
        switch model.buildProgress?.stage {
        case .downloading(let done, let total)? where total > 0:
            return "Downloading filter lists · \(done) of \(total)"
        case .compiling(let category)?:
            return category.buildingText
        case .reloading?:
            return "Handing filters to Safari…"
        case .finished?:
            return "All done!"
        default:
            return "Getting ready…"
        }
    }

    private var percent: Int {
        buildDone ? 100 : Int(((model.buildProgress?.fraction) ?? 0) * 100)
    }

    // MARK: - Choices

    private func load() {
        guard !loaded else { return }
        loaded = true
        if !isPersonalizing {
            model.prefetchFilters()
        }
        name = model.settings.userName
        let enabled = model.settings.enabledFilterIDs
        if isPersonalizing {
            noiseStart = Set(NoiseSource.allCases.filter { source in
                source == .youtube
                    ? model.settings.wantsYouTubeBlocking
                    : source.filterIDs.allSatisfy(enabled.contains)
            })
        } else {
            noiseStart = NoiseSource.baseline
        }
        noise = noiseStart
        languages = Set(FilterCatalog.lists(in: .regional).map(\.id).filter(enabled.contains))
        enter(step)
    }

    /// The lists the answers turn on. Replaces only the lists onboarding
    /// controls; lists toggled elsewhere are left as they are.
    private func chosenFilters() -> (ids: Set<String>, youTube: Bool) {
        let regional = FilterCatalog.lists(in: .regional).map(\.id)
        let governed = Set(NoiseSource.allCases.flatMap(\.filterIDs) + regional)
        var enabled = model.settings.enabledFilterIDs.subtracting(governed)
        enabled.formUnion(noise.flatMap(\.filterIDs))
        if noise.contains(.ads) {
            enabled.formUnion(languages)
        }
        return (enabled, noise.contains(.youtube))
    }

    private func extensionTurnedOn() {
        guard step == .safari else { return }
        Haptics.success()
        mood = .excited
        reaction += 1
        let remaining = model.requiredBlockers.count - model.enabledExtensionCount
            + (model.settings.wantsYouTubeBlocking && model.youTubeEnabled == false ? 1 : 0)
        bubble = remaining <= 0 ? "That's all of them! 🎉" : "Nice! \(remaining) to go."
    }

    @discardableResult
    private func toggle<Element: Hashable>(_ element: Element, in set: inout Set<Element>) -> Bool {
        if set.contains(element) {
            set.remove(element)
            return false
        }
        set.insert(element)
        return true
    }

    // MARK: - Derived text

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var readyRuleCount: Int {
        model.requiredBlockers.compactMap { model.stats[$0]?.safariRules }.reduce(0, +)
    }

    private var switchCountText: String {
        let count = model.requiredExtensionIdentifiers.count
        return count == 1 ? "1 switch" : "\(count) switches"
    }

    private var celebrateTitle: String {
        guard model.isFullyEnabled else { return "Almost there" }
        return name.isEmpty ? "You're all set!" : "You're all set, \(name)!"
    }

    private var celebrateMessage: String {
        guard model.isFullyEnabled else {
            return "Some switches are still off in Safari. I'll remind you on the home screen."
        }
        let count = readyRuleCount
        return count > 0
            ? "Shh… hear that? Safari just got quieter. \(count.counted("rule")) \(count == 1 ? "is" : "are") standing guard."
            : "Shh… hear that? Safari just got quieter."
    }
}

// MARK: - Pieces

/// Noise icons orbiting the mascot on the welcome screen. They pop when the
/// user taps Get Started and the mascot shushes them.
private struct NoiseOrbit: View {
    let hushed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let items = ["megaphone", "cookie", "eyes", "bell", "collision", "television"]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || hushed)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(items.indices, id: \.self) { index in
                    IconGlyph(icon: .fluent(items[index]), size: 34)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Theme.surface))
                        .overlay(Circle().strokeBorder(Theme.border, lineWidth: 2))
                        .offset(position(index: index, t: t))
                        .scaleEffect(hushed ? 0.01 : 1)
                        .opacity(hushed ? 0 : 1)
                        .animation(.spring(response: 0.35, dampingFraction: 0.55).delay(Double(index) * 0.06), value: hushed)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func position(index: Int, t: Double) -> CGSize {
        let angle = Double(index) / Double(items.count) * 2 * .pi + t * 0.35
        let wobble = sin(t * 2 + Double(index)) * 6
        return CGSize(width: CGFloat(cos(angle) * 125), height: CGFloat(sin(angle) * 105 + wobble))
    }
}

private struct BuildItem: Identifiable {
    enum Kind: Equatable {
        case download
        case category(BlockerCategory)
        case youtube
    }

    let kind: Kind
    let title: String
    var id: String { title }
}

/// A checklist row that follows real work: waiting, in progress, done.
private struct BuildRow: View {
    enum Status { case pending, active, done }

    let text: String
    let status: Status
    var highlighted = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                switch status {
                case .pending:
                    Circle().strokeBorder(Theme.border, lineWidth: 2)
                case .active:
                    ProgressView().tint(Theme.primary)
                case .done:
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .foregroundStyle(Theme.success)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 24, height: 24)
            .accessibilityHidden(true)
            Text(text)
                .font(highlighted || status == .active ? .hushBodyBold : .hushBody)
                .foregroundStyle(status == .pending ? Theme.secondaryText : Theme.text)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: status)
        .accessibilityElement(children: .combine)
        .accessibilityValue(status == .done ? "Done" : status == .active ? "In progress" : "Waiting")
    }
}

/// Thick progress bar for the loading screen. It has no animation of its
/// own; the screen animates it so long stages can ease forward.
private struct LoadingBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.border)
                Capsule()
                    .fill(Theme.success)
                    .frame(width: max(20, geometry.size.width * min(progress, 1)))
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(.white.opacity(0.35))
                            .frame(height: 5)
                            .padding(.horizontal, 10)
                            .padding(.top, 4)
                    }
            }
        }
        .frame(height: 20)
        .accessibilityElement()
        .accessibilityLabel("Setting up filters")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

private extension BlockerCategory {
    var buildingText: String {
        switch self {
        case .ads: return "Building ad filters…"
        case .privacy: return "Building tracker protection…"
        case .annoyances: return "Building pop-up & cookie filters…"
        case .regional: return "Adding language filters…"
        case .custom: return "Applying your custom rules…"
        }
    }
}

private struct PlanSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.hushCaption)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)
            content
        }
    }
}

private struct PlanFact: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text).foregroundStyle(Theme.text)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Theme.primary)
        }
        .font(.hushBody)
    }
}

/// One Safari extension, with a little switch that shows what to do.
private struct SwitchRow: View {
    let icon: AppIcon
    let name: String
    let isOn: Bool?

    var body: some View {
        HStack(spacing: 16) {
            IconGlyph(icon: icon, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.hushBodyBold)
                    .foregroundStyle(Theme.text)
                Text(status)
                    .font(.hushCaption)
                    .foregroundStyle(isOn == true ? Theme.success : Theme.secondaryText)
            }
            Spacer()
            MiniSwitch(isOn: isOn == true)
                .opacity(isOn == nil ? 0.5 : 1)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    private var status: String {
        switch isOn {
        case true?: return "On"
        case false?: return "Off"
        case nil: return "Check this one in Settings"
        }
    }
}

private struct MiniSwitch: View {
    let isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? Theme.success : Theme.border)
            .frame(width: 51, height: 31)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .padding(2)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isOn)
            .accessibilityHidden(true)
    }
}

extension View {
    /// Static card with the same chunky edge as the buttons.
    func chunkyPanel() -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
        return background(shape.fill(Theme.surface))
            .overlay(shape.strokeBorder(Theme.border, lineWidth: 2))
            .background(shape.fill(Theme.borderShade).offset(y: Theme.lip))
            .padding(.bottom, Theme.lip)
    }
}
