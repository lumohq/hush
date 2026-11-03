import BlockerShared
import Foundation
import Testing

@testable import BlockerKit

private func makeEnvironment(languageCode: String? = "en") -> (SharedContainer, ProtectionSettings) {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("BlockerKitTests-\(UUID().uuidString)", isDirectory: true)
    let defaults = UserDefaults(suiteName: "BlockerKitTests-\(UUID().uuidString)")!
    return (SharedContainer(root: root), ProtectionSettings(defaults: defaults, languageCode: languageCode))
}

private func loadRules(_ url: URL) throws -> [[String: Any]] {
    let data = try Data(contentsOf: url)
    return try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
}

@Suite struct DomainNormalizationTests {
    @Test(arguments: [
        ("example.com", "example.com"),
        ("https://www.Example.com/path?q=1", "example.com"),
        ("  news.bbc.co.uk  ", "news.bbc.co.uk"),
        ("http://localhost:8080", nil),
        ("not a domain", nil),
        ("", nil),
    ] as [(String, String?)])
    func normalizes(input: String, expected: String?) {
        #expect(ProtectionSettings.normalizedDomain(input) == expected)
    }
}

@Suite struct DefaultSettingsTests {
    @Test func regionalListFollowsDeviceLanguage() {
        let (_, german) = makeEnvironment(languageCode: "de")
        let (_, english) = makeEnvironment(languageCode: "en")
        #expect(german.enabledFilterIDs.contains("adguard-german"))
        #expect(!english.enabledFilterIDs.contains("adguard-german"))
        #expect(english.enabledFilterIDs.contains("adguard-base"))
    }
}

@Suite struct CompilationTests {
    @Test func customRulesConvertToSafariJSON() async throws {
        let (container, settings) = makeEnvironment()
        settings.customRules = """
        ! comment
        ||ads.example.com^
        example.org##.sponsored-banner
        """
        settings.allowlist = ["trusted.com"]

        let report = await ProtectionEngine(container: container, settings: settings).recompile([.custom])
        #expect(report.failed.isEmpty)
        #expect(report.stats[.custom]?.safariRules == 3)

        let rules = try loadRules(container.blockerListURL(for: .custom))
        let actions = rules.compactMap { ($0["action"] as? [String: Any])?["type"] as? String }
        #expect(actions.contains("block"))
        #expect(actions.contains("css-display-none"))
        // The allowlist exception must come last so it overrides everything.
        #expect(actions.last == "ignore-previous-rules")

        let selectors = rules.compactMap { ($0["action"] as? [String: Any])?["selector"] as? String }
        #expect(selectors.contains(".sponsored-banner"))
    }

    @Test func progressMovesForwardAndFinishes() async throws {
        let (container, settings) = makeEnvironment()
        settings.enabledFilterIDs = []
        settings.customRules = "||ads.example.com^"

        final class Recorder: @unchecked Sendable {
            private let lock = NSLock()
            private var items: [ProtectionProgress] = []
            func add(_ item: ProtectionProgress) { lock.lock(); items.append(item); lock.unlock() }
            var all: [ProtectionProgress] { lock.lock(); defer { lock.unlock() }; return items }
        }
        let recorder = Recorder()

        _ = await ProtectionEngine(container: container, settings: settings)
            .recompile(Set(BlockerCategory.allCases), progress: recorder.add)

        let updates = recorder.all
        #expect(updates.last?.stage == .finished)
        #expect(updates.last?.fraction == 1)
        #expect(zip(updates, updates.dropFirst()).allSatisfy { $0.fraction <= $1.fraction })
        #expect(updates.allSatisfy { $0.fraction <= $0.stageEndFraction })
        #expect(updates.contains { $0.stage == .compiling(.custom) })
    }

    @Test func emptyCategoryStillProducesValidList() async throws {
        let (container, settings) = makeEnvironment()
        settings.allowlist = ["trusted.com"]

        let report = await ProtectionEngine(container: container, settings: settings).recompile([.custom])
        #expect(report.stats[.custom]?.safariRules == 0)

        // Safari rejects an empty array, so a single no-op rule is written.
        let rules = try loadRules(container.blockerListURL(for: .custom))
        #expect(rules.count == 1)
    }
}

/// Downloads the real default lists. Run with:
///   HUSH_LIVE_TESTS=1 swift test --filter LiveFilterTests
@Suite(.enabled(if: ProcessInfo.processInfo.environment["HUSH_LIVE_TESTS"] == "1"))
struct LiveFilterTests {
    @Test(.timeLimit(.minutes(5))) func defaultListsDownloadAndFitSafariLimits() async throws {
        let (container, settings) = makeEnvironment(languageCode: "de")
        let report = await ProtectionEngine(container: container, settings: settings, safariVersion: .safari16_4).updateAll()

        #expect(report.failed.isEmpty, "\(report.failed)")
        for category in [BlockerCategory.ads, .privacy, .annoyances, .regional] {
            let stats = try #require(report.stats[category])
            print("\(category.rawValue): \(stats.safariRules) Safari rules from \(stats.sourceRules) source rules, \(stats.discardedRules) discarded, \(stats.errors) errors")
            #expect(stats.safariRules > 0)
            #expect(stats.safariRules <= 150_000)
            #expect(stats.discardedRules == 0)
            _ = try loadRules(container.blockerListURL(for: category))
        }
    }
}
