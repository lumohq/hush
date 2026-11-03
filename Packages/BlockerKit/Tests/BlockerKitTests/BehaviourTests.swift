import BlockerShared
import Foundation
import Testing

@testable import BlockerKit

private func environment() -> (SharedContainer, ProtectionSettings) {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("BehaviourTests-\(UUID().uuidString)", isDirectory: true)
    let defaults = UserDefaults(suiteName: "BehaviourTests-\(UUID().uuidString)")!
    return (SharedContainer(root: root), ProtectionSettings(defaults: defaults, languageCode: "en"))
}

/// Writes a cached copy of a list so recompiles work without the network.
private func cache(_ rules: String, as filterID: String, in container: SharedContainer) throws {
    try container.createDirectories()
    try rules.write(to: container.filterCacheURL(filterID: filterID), atomically: true, encoding: .utf8)
}

private func actions(_ category: BlockerCategory, in container: SharedContainer) throws -> [String] {
    let data = try Data(contentsOf: container.blockerListURL(for: category))
    let rules = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    return rules.compactMap { ($0["action"] as? [String: Any])?["type"] as? String }
}

/// Fails every request, as with no connection.
private final class OfflineProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }
    override func stopLoading() {}
}

@Suite struct ToggleTests {
    @Test func turningAListOnAndOffChangesTheBlocker() async throws {
        let (container, settings) = environment()
        try cache("||ads-one.example^\n||ads-two.example^", as: "adguard-base", in: container)
        let engine = ProtectionEngine(container: container, settings: settings)
        let base = try #require(FilterCatalog.list(id: "adguard-base"))

        settings.enabledFilterIDs = ["adguard-base"]
        var report = await engine.recompile([.ads])
        #expect(report.stats[.ads]?.safariRules == 2)
        #expect(settings.activeCategories == [.ads])

        settings.setEnabled(false, filter: base)
        report = await engine.recompile([.ads])
        #expect(report.stats[.ads]?.safariRules == 0)
        #expect(settings.activeCategories.isEmpty)
        // An empty blocker still hands Safari a valid single no-op rule.
        #expect(try actions(.ads, in: container) == ["ignore-previous-rules"])
    }

    @Test func customRulesMakeTheCustomBlockerActive() {
        let (_, settings) = environment()
        settings.enabledFilterIDs = []
        #expect(!settings.activeCategories.contains(.custom))
        settings.customRules = "   \n  "
        #expect(!settings.activeCategories.contains(.custom))
        settings.customRules = "||ads.example^"
        #expect(settings.activeCategories == [.custom])
    }

    @Test func allowlistAppliesToEveryBlocker() async throws {
        let (container, settings) = environment()
        try cache("||ads.example^", as: "adguard-base", in: container)
        try cache("||tracker.example^", as: "adguard-tracking", in: container)
        settings.enabledFilterIDs = ["adguard-base", "adguard-tracking"]
        settings.customRules = "##.promo"
        settings.allowlist = ["trusted.example"]

        _ = await ProtectionEngine(container: container, settings: settings).recompile(Set(BlockerCategory.allCases))
        for category in [BlockerCategory.ads, .privacy, .custom] {
            #expect(try actions(category, in: container).last == "ignore-previous-rules", "\(category)")
        }
    }
}

@Suite struct OfflineTests {
    @Test func noConnectionFailsCleanlyAndReportsIt() async throws {
        let (container, settings) = environment()
        settings.enabledFilterIDs = ["adguard-base"]
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OfflineProtocol.self]
        let engine = ProtectionEngine(container: container, settings: settings, session: URLSession(configuration: configuration))

        let started = Date()
        let report = await engine.recompile(Set(BlockerCategory.allCases))
        #expect(Date().timeIntervalSince(started) < 5)
        #expect(report.failed["adguard-base"] != nil)
        #expect(report.stats[.ads]?.safariRules == 0)
        // Nothing was downloaded, so there is no update date to claim.
        #expect(settings.lastUpdated == nil)
    }
}

/// Run with HUSH_LIVE_TESTS=1.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["HUSH_LIVE_TESTS"] == "1"))
struct EveryListLiveTests {
    @Test(.timeLimit(.minutes(10))) func everyListTurnedOnStillFitsSafari() async throws {
        let (container, settings) = environment()
        settings.enabledFilterIDs = Set(FilterCatalog.all.map(\.id))
        let engine = ProtectionEngine(container: container, settings: settings, safariVersion: .safari26,
                                      maxJsonSizeBytes: 19_000_000)

        let report = await engine.recompile(Set(BlockerCategory.allCases))
        #expect(report.failed.isEmpty, "\(report.failed)")
        #expect(settings.lastUpdated != nil)
        for category in [BlockerCategory.ads, .privacy, .annoyances, .regional] {
            let stats = try #require(report.stats[category])
            let size = try FileManager.default.attributesOfItem(atPath: container.blockerListURL(for: category).path)[.size] as? Int ?? 0
            print("\(category.rawValue): \(stats.safariRules) rules, \(stats.discardedRules) discarded, \(size / 1_000_000) MB")
            #expect(stats.safariRules <= 150_000)
            #expect(stats.discardedRules == 0, "\(category) dropped \(stats.discardedRules) rules")
            #expect(size <= 19_000_000)
        }
    }
}
