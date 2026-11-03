import BlockerShared
import ContentBlockerConverter
import Foundation

public struct UpdateReport: Sendable {
    public var downloaded: [String] = []
    /// Filter ID → failure reason. A failed list keeps its previous cached copy.
    public var failed: [String: String] = [:]
    public var stats: [BlockerCategory: BlockerStats] = [:]
    public var compiledCategories: Set<BlockerCategory> = []
}

/// Progress of a download-and-compile run, for a loading screen.
public struct ProtectionProgress: Sendable, Equatable {
    public enum Stage: Sendable, Equatable {
        case downloading(done: Int, total: Int)
        case compiling(BlockerCategory)
        /// Reported by the app, not the engine: Safari reloading the
        /// compiled blockers, which it compiles again on its side.
        case reloading(done: Int, total: Int)
        case finished
    }

    public var stage: Stage
    /// Work completed, 0...1. Compiling is weighted by each category's
    /// filter size, since that is what the time depends on.
    public var fraction: Double
    /// Where `fraction` will be when the current stage ends, so a UI can ease
    /// towards it while a long stage runs.
    public var stageEndFraction: Double
    /// Categories fully compiled so far.
    public var compiled: Set<BlockerCategory>

    public init(stage: Stage, fraction: Double, stageEndFraction: Double, compiled: Set<BlockerCategory>) {
        self.stage = stage
        self.fraction = fraction
        self.stageEndFraction = stageEndFraction
        self.compiled = compiled
    }
}

public typealias ProgressHandler = @Sendable (ProtectionProgress) -> Void

public enum ProtectionEngineError: LocalizedError {
    case badResponse(Int)
    case notAFilterList

    public var errorDescription: String? {
        switch self {
        case .badResponse(let status): return "Server responded with HTTP \(status)."
        case .notAFilterList: return "The download was not a filter list."
        }
    }
}

/// Downloads filter lists and compiles them into Safari content blocker JSON.
///
/// The engine only writes files; telling Safari to reload them is the app's
/// job (`SFContentBlockerManager` is not available to unit tests on macOS).
public actor ProtectionEngine {
    private let container: SharedContainer
    private let settings: ProtectionSettings
    private let session: URLSession
    private let safariVersion: SafariVersion
    private let maxJsonSizeBytes: Int?

    public init(
        container: SharedContainer,
        settings: ProtectionSettings,
        session: URLSession = .shared,
        safariVersion: SafariVersion = .autodetect(),
        maxJsonSizeBytes: Int? = ProtectionEngine.recommendedMaxJsonSizeBytes
    ) {
        self.container = container
        self.settings = settings
        self.session = session
        self.safariVersion = safariVersion
        self.maxJsonSizeBytes = maxJsonSizeBytes
    }

    /// Since iOS 17 the content blocker process crashes when Safari compiles a
    /// JSON file that is too large, regardless of the 150k rule limit. These
    /// are the limits AdGuard ships (Apple Feedback FB13282146).
    public static var recommendedMaxJsonSizeBytes: Int? {
        #if os(iOS)
        if #available(iOS 17.2, *) {
            return 19_000_000
        } else if #available(iOS 17.0, *) {
            return 10_000_000
        }
        #endif
        return nil
    }

    /// Re-downloads every enabled list, then recompiles every category.
    public func updateAll() async -> UpdateReport {
        var report = UpdateReport()
        let lists = FilterCatalog.all.filter(settings.isEnabled)
        await download(lists, into: &report)
        if report.failed.count < lists.count {
            settings.lastUpdated = Date()
        }
        compile(Set(BlockerCategory.allCases), into: &report)
        return report
    }

    /// Recompiles the given categories after a settings change, downloading
    /// only enabled lists that have never been fetched.
    public func recompile(_ categories: Set<BlockerCategory>, progress: ProgressHandler? = nil) async -> UpdateReport {
        var report = UpdateReport()
        let missing = FilterCatalog.all.filter {
            categories.contains($0.blocker)
                && settings.isEnabled($0)
                && !FileManager.default.fileExists(atPath: container.filterCacheURL(filterID: $0.id).path)
        }
        // Downloads get a quarter of the bar when there are any.
        let downloadShare = missing.isEmpty ? 0 : 0.25
        if !missing.isEmpty {
            progress?(ProtectionProgress(stage: .downloading(done: 0, total: missing.count),
                                         fraction: 0, stageEndFraction: downloadShare, compiled: []))
        }
        let total = missing.count
        await download(missing, into: &report) { done in
            progress?(ProtectionProgress(stage: .downloading(done: done, total: total),
                                         fraction: downloadShare * Double(done) / Double(total),
                                         stageEndFraction: downloadShare, compiled: []))
        }
        recordFirstDownload(report)
        compile(categories, into: &report, progress: progress, startingAt: downloadShare)
        progress?(ProtectionProgress(stage: .finished, fraction: 1, stageEndFraction: 1, compiled: report.compiledCategories))
        return report
    }

    /// Downloads lists that have never been fetched, without compiling, so a
    /// later `recompile` only has to convert.
    public func prefetch(_ lists: [FilterList]) async {
        var report = UpdateReport()
        let missing = lists.filter {
            !FileManager.default.fileExists(atPath: container.filterCacheURL(filterID: $0.id).path)
        }
        await download(missing, into: &report)
        recordFirstDownload(report)
    }

    /// Lists fetched for the first time count as the first update, so the app
    /// doesn't claim filters were never downloaded. Later dates come only from
    /// full updates, which refresh every list.
    private func recordFirstDownload(_ report: UpdateReport) {
        if settings.lastUpdated == nil && !report.downloaded.isEmpty {
            settings.lastUpdated = Date()
        }
    }

    // MARK: - Download

    private func download(
        _ lists: [FilterList],
        into report: inout UpdateReport,
        onEach: (@Sendable (Int) -> Void)? = nil
    ) async {
        guard !lists.isEmpty else { return }
        try? container.createDirectories()

        let results = await withTaskGroup(of: (String, Error?).self) { group in
            for list in lists {
                group.addTask { [session, container] in
                    do {
                        let text = try await Self.fetch(list.url, session: session)
                        try text.write(to: container.filterCacheURL(filterID: list.id), atomically: true, encoding: .utf8)
                        return (list.id, nil)
                    } catch {
                        return (list.id, error)
                    }
                }
            }
            var collected: [(String, Error?)] = []
            for await result in group {
                collected.append(result)
                onEach?(collected.count)
            }
            return collected
        }

        for (id, error) in results {
            if let error {
                report.failed[id] = error.localizedDescription
            } else {
                report.downloaded.append(id)
            }
        }
    }

    private static func fetch(_ url: URL, session: URLSession) async throws -> String {
        // Short enough that a dead connection fails within the loading screen
        // rather than leaving it waiting for a minute.
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw ProtectionEngineError.badResponse(http.statusCode)
        }
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            throw ProtectionEngineError.notAFilterList
        }
        // Captive portals and error pages return HTML with a 200 status.
        let head = text.prefix(512).lowercased()
        if head.contains("<html") || head.contains("<!doctype") {
            throw ProtectionEngineError.notAFilterList
        }
        return text
    }

    // MARK: - Compile

    private func compile(
        _ categories: Set<BlockerCategory>,
        into report: inout UpdateReport,
        progress: ProgressHandler? = nil,
        startingAt base: Double = 0
    ) {
        try? container.createDirectories()
        var allStats = settings.stats
        let ordered = BlockerCategory.allCases.filter(categories.contains)
        let weights = ordered.map { max(compileWeight(of: $0), 1) }
        let totalWeight = Double(weights.reduce(0, +))
        let share = 1 - base
        var doneWeight = 0
        // Sequential on purpose: large lists are memory-hungry to convert.
        for (index, category) in ordered.enumerated() {
            let start = base + share * Double(doneWeight) / totalWeight
            let end = base + share * Double(doneWeight + weights[index]) / totalWeight
            progress?(ProtectionProgress(stage: .compiling(category), fraction: start,
                                         stageEndFraction: end, compiled: report.compiledCategories))
            do {
                let stats = try compile(category)
                allStats[category] = stats
                report.stats[category] = stats
                report.compiledCategories.insert(category)
            } catch {
                report.failed["compile.\(category.rawValue)"] = error.localizedDescription
            }
            doneWeight += weights[index]
        }
        settings.stats = allStats
    }

    /// Bytes of filter text a category will convert; time scales with it.
    private func compileWeight(of category: BlockerCategory) -> Int {
        let listBytes = settings.enabledLists(compiledInto: category).reduce(0) { total, list in
            let path = container.filterCacheURL(filterID: list.id).path
            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
            return total + size
        }
        return listBytes + (category == .custom ? settings.customRules.utf8.count : 0)
    }

    private func compile(_ category: BlockerCategory) throws -> BlockerStats {
        let rules = sourceRules(for: category)
        let output = container.blockerListURL(for: category)

        guard rules.contains(where: Self.isRule) else {
            try ConversionResult.EMPTY_RESULT_JSON.write(to: output, atomically: true, encoding: .utf8)
            return BlockerStats(safariRules: 0, sourceRules: 0, discardedRules: 0, errors: 0, compiledAt: Date())
        }

        // Allowlist rules turn the whole category off on those sites. They are
        // added after content rules; the converter orders them last in the JSON.
        let allowlist = settings.allowlist.map(ContentBlockerConverter.createAllowlistRule)

        let result = ContentBlockerConverter().convertArray(
            rules: rules + allowlist,
            safariVersion: safariVersion,
            advancedBlocking: false,
            maxJsonSizeBytes: maxJsonSizeBytes
        )
        let json = result.safariRulesCount > 0 ? result.safariRulesJSON : ConversionResult.EMPTY_RESULT_JSON
        try json.write(to: output, atomically: true, encoding: .utf8)

        return BlockerStats(
            safariRules: result.safariRulesCount,
            sourceRules: result.sourceRulesCount,
            discardedRules: result.discardedSafariRules,
            errors: result.errorsCount,
            compiledAt: Date()
        )
    }

    private func sourceRules(for category: BlockerCategory) -> [String] {
        var lines: [String] = []
        for list in settings.enabledLists(compiledInto: category) {
            let url = container.filterCacheURL(filterID: list.id)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            lines.append(contentsOf: text.split(whereSeparator: \.isNewline).map(String.init))
        }
        if category == .custom {
            lines.append(contentsOf: settings.customRules.split(whereSeparator: \.isNewline).map(String.init))
        }
        return lines
    }

    /// Comments start with "!"; "[Adblock Plus 2.0]"-style headers with "[".
    /// "#" is not a comment marker here because "##" starts cosmetic rules.
    private static func isRule(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && !trimmed.hasPrefix("!") && !trimmed.hasPrefix("[")
    }
}
