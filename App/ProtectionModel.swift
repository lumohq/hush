import BlockerKit
import BlockerShared
import SafariServices
import SwiftUI

@MainActor
final class ProtectionModel: ObservableObject {
    static let shared = ProtectionModel()

    /// Categories shown as content blockers. Every case has an extension.
    static let blockers = BlockerCategory.allCases

    @Published private(set) var extensionStates: [BlockerCategory: Bool] = [:]
    /// `nil` when iOS cannot report it (before iOS 26.2).
    @Published private(set) var youTubeEnabled: Bool?
    @Published private(set) var stats: [BlockerCategory: BlockerStats]
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isUpdating = false
    @Published private(set) var failedLists: [String: String] = [:]
    @Published var errorMessage: String?
    @Published var showOnboarding: Bool
    /// Progress of the compile started by `applyPersonalization`.
    @Published private(set) var buildProgress: ProtectionProgress?
    /// Bumped on every settings change so views that read `settings` refresh.
    @Published private(set) var settingsRevision = 0

    let settings: ProtectionSettings
    private let engine: ProtectionEngine?
    private let appBundleIdentifier: String
    private var pendingCategories: Set<BlockerCategory> = []
    /// Blockers whose on/off state iOS could not report on the last check.
    private var unknownStates: Set<BlockerCategory> = []
    private var recompileTask: Task<Void, Never>?
    /// Several jobs can overlap (full update, recompile after a toggle,
    /// onboarding); `isUpdating` stays true until the last one ends.
    private var activeJobs = 0

    private init() {
        appBundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        let groupID = Bundle.main.object(forInfoDictionaryKey: SharedContainer.appGroupInfoKey) as? String
        settings = ProtectionSettings(defaults: groupID.flatMap(UserDefaults.init(suiteName:)) ?? .standard)
        stats = settings.stats
        lastUpdated = settings.lastUpdated
        showOnboarding = !settings.hasCompletedOnboarding

        if let container = SharedContainer.appGroup() {
            engine = ProtectionEngine(container: container, settings: settings)
        } else {
            engine = nil
            errorMessage = "The App Group is not available. Check that the app and its extensions share the App Group capability."
        }
    }

    /// Blockers the user's choices need switched on in Safari.
    var requiredBlockers: [BlockerCategory] {
        settings.activeCategories
    }

    var enabledExtensionCount: Int {
        requiredBlockers.filter(isExtensionEnabled).count
    }

    /// Every Safari switch the user's choices need, YouTube included when iOS
    /// can report its state, so counts match the onboarding checklist.
    var requiredSwitchCount: Int {
        requiredBlockers.count + (settings.wantsYouTubeBlocking && youTubeEnabled != nil ? 1 : 0)
    }

    var enabledSwitchCount: Int {
        enabledExtensionCount + (settings.wantsYouTubeBlocking && youTubeEnabled == true ? 1 : 0)
    }

    var isFullyEnabled: Bool {
        let blockersOn = !requiredBlockers.isEmpty && enabledExtensionCount == requiredBlockers.count
        // An unknown YouTube state does not count against the user.
        let youTubeOn = !settings.wantsYouTubeBlocking || youTubeEnabled != false
        return blockersOn && youTubeOn
    }

    func isExtensionEnabled(_ category: BlockerCategory) -> Bool {
        extensionStates[category] ?? false
    }

    var youTubeExtensionIdentifier: String {
        "\(appBundleIdentifier).youtube"
    }

    /// The Safari extensions the user's choices need: the active content
    /// blockers plus the YouTube web extension if they want it.
    var requiredExtensionIdentifiers: [String] {
        requiredBlockers.map { $0.extensionIdentifier(appBundleIdentifier: appBundleIdentifier) }
            + (settings.wantsYouTubeBlocking ? [youTubeExtensionIdentifier] : [])
    }

    /// Display names of `requiredExtensionIdentifiers`, as Settings shows them.
    var requiredExtensionNames: [String] {
        requiredBlockers.map { "Hush \($0.title)" }
            + (settings.wantsYouTubeBlocking ? ["Hush for YouTube"] : [])
    }

    // MARK: - Safari state

    func refreshExtensionStates() async {
        var states: [BlockerCategory: Bool] = [:]
        var unknown: Set<BlockerCategory> = []
        for category in Self.blockers {
            let identifier = category.extensionIdentifier(appBundleIdentifier: appBundleIdentifier)
            do {
                states[category] = try await SFContentBlockerManager.stateOfContentBlocker(withIdentifier: identifier).isEnabled
            } catch {
                states[category] = false
                unknown.insert(category)
            }
        }
        extensionStates = states
        unknownStates = unknown

        if #available(iOS 26.2, *) {
            let state = try? await SFSafariExtensionManager.stateOfExtension(withIdentifier: youTubeExtensionIdentifier)
            youTubeEnabled = state?.isEnabled
        }
    }

    // MARK: - Updating

    /// Downloads every enabled list and recompiles all blockers.
    func updateAll() async {
        guard let engine, !isUpdating else { return }
        beginJob()
        defer { endJob() }

        let report = await engine.updateAll()
        await apply(report)
    }

    /// Downloads, without compiling, the lists onboarding is likely to pick,
    /// so the single compile after the user's answers starts straight away.
    func prefetchFilters() {
        guard let engine else { return }
        let likely = FilterCatalog.all.filter { $0.category != .regional || settings.isEnabled($0) }
        Task { await engine.prefetch(likely) }
    }

    /// Updates on first launch and when lists are more than three days old.
    func updateIfStale() async {
        let staleAfter: TimeInterval = 3 * 24 * 60 * 60
        if stats.isEmpty || lastUpdated.map({ Date().timeIntervalSince($0) > staleAfter }) ?? true {
            await updateAll()
        }
    }

    private func apply(_ report: UpdateReport, onReloadStep: ((Int, Int) -> Void)? = nil) async {
        stats = settings.stats
        lastUpdated = settings.lastUpdated
        failedLists = report.failed
        await reload(report.compiledCategories, onStep: onReloadStep)
    }

    /// Asks Safari to reload blockers, which it recompiles on its side and can
    /// take seconds each. Safari reads the latest file whenever a blocker is
    /// switched on, so blockers that are off are skipped; ones whose state iOS
    /// couldn't report are reloaded to be safe.
    private func reload(_ categories: Set<BlockerCategory>, onStep: ((Int, Int) -> Void)? = nil) async {
        await refreshExtensionStates()
        let targets = Self.blockers.filter {
            categories.contains($0) && (isExtensionEnabled($0) || unknownStates.contains($0))
        }
        for (index, category) in targets.enumerated() {
            onStep?(index, targets.count)
            let identifier = category.extensionIdentifier(appBundleIdentifier: appBundleIdentifier)
            do {
                try await SFContentBlockerManager.reloadContentBlocker(withIdentifier: identifier)
            } catch where isExtensionEnabled(category) {
                errorMessage = "Safari could not load \(category.title): \(error.localizedDescription)"
            } catch {}
        }
    }

    // MARK: - Settings changes

    func setFilter(_ list: FilterList, enabled: Bool) {
        settings.setEnabled(enabled, filter: list)
        settingsChanged(affecting: [list.blocker])
    }

    /// Applies the onboarding choices and compiles straight away, publishing
    /// `buildProgress` as it goes. Returns once Safari has been told to reload.
    func applyPersonalization(enabledFilterIDs: Set<String>, wantsYouTube: Bool) async {
        settings.enabledFilterIDs = enabledFilterIDs
        settings.wantsYouTubeBlocking = wantsYouTube
        settingsRevision += 1
        recompileTask?.cancel()
        pendingCategories.removeAll()
        guard let engine else { return }

        beginJob()
        defer { endJob() }
        buildProgress = ProtectionProgress(stage: .downloading(done: 0, total: 0), fraction: 0,
                                           stageEndFraction: 0.05, compiled: [])
        // Compiling fills 90% of the bar; handing the blockers to Safari, the
        // last 10%, so the bar never sits at 100% while work continues.
        let compileShare = 0.9
        let report = await engine.recompile(Set(Self.blockers)) { [weak self] update in
            Task { @MainActor in self?.receive(Self.scaled(update, into: compileShare)) }
        }
        await apply(report) { [weak self] done, total in
            let step = (1 - compileShare) / Double(total)
            self?.receive(ProtectionProgress(stage: .reloading(done: done, total: total),
                                             fraction: compileShare + step * Double(done),
                                             stageEndFraction: compileShare + step * Double(done + 1),
                                             compiled: report.compiledCategories))
        }
        receive(ProtectionProgress(stage: .finished, fraction: 1, stageEndFraction: 1,
                                   compiled: report.compiledCategories))
    }

    private func beginJob() {
        activeJobs += 1
        isUpdating = true
    }

    private func endJob() {
        activeJobs = max(0, activeJobs - 1)
        isUpdating = activeJobs > 0
    }

    /// Maps engine progress into the first `share` of the bar. The engine's
    /// own "finished" becomes the start of the Safari step.
    private static func scaled(_ update: ProtectionProgress, into share: Double) -> ProtectionProgress {
        if update.stage == .finished {
            return ProtectionProgress(stage: .reloading(done: 0, total: 0), fraction: share,
                                      stageEndFraction: 1, compiled: update.compiled)
        }
        return ProtectionProgress(stage: update.stage, fraction: update.fraction * share,
                                  stageEndFraction: update.stageEndFraction * share, compiled: update.compiled)
    }

    /// Updates hop to the main actor separately, so drop any that arrive out
    /// of order.
    private func receive(_ update: ProtectionProgress) {
        if let current = buildProgress, update.fraction < current.fraction { return }
        buildProgress = update
    }

    func finishOnboarding() {
        settings.hasCompletedOnboarding = true
        showOnboarding = false
    }

    /// YouTube needs no filter lists, so this only records the choice; the
    /// status and setup screens follow it.
    func setWantsYouTube(_ wants: Bool) {
        settings.wantsYouTubeBlocking = wants
        settingsRevision += 1
    }

    func saveCustomRules(_ text: String) {
        settings.customRules = text
        settingsChanged(affecting: [.custom])
    }

    func addAllowlistDomain(_ input: String) -> Bool {
        guard let domain = ProtectionSettings.normalizedDomain(input) else { return false }
        var domains = settings.allowlist
        guard !domains.contains(domain) else { return true }
        domains.append(domain)
        settings.allowlist = domains.sorted()
        settingsChanged(affecting: Set(Self.blockers))
        return true
    }

    func removeAllowlistDomains(at offsets: IndexSet) {
        var domains = settings.allowlist
        domains.remove(atOffsets: offsets)
        settings.allowlist = domains
        settingsChanged(affecting: Set(Self.blockers))
    }

    /// Debounced so flipping several toggles triggers one recompile.
    private func settingsChanged(affecting categories: Set<BlockerCategory>) {
        settingsRevision += 1
        pendingCategories.formUnion(categories)
        recompileTask?.cancel()
        recompileTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled, let self, let engine = self.engine else { return }
            let categories = self.pendingCategories
            self.pendingCategories.removeAll()
            self.beginJob()
            let report = await engine.recompile(categories)
            await self.apply(report)
            self.endJob()
        }
    }
}
