import BlockerShared
import Foundation

/// A downloadable filter list in Adblock/AdGuard syntax.
public struct FilterList: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let summary: String
    public let url: URL
    /// Where the list is shown and toggled.
    public let category: BlockerCategory
    /// The content blocker it is compiled into. Usually `category`, but a
    /// large list can live in a blocker with room to spare, since each one is
    /// capped at 150,000 rules.
    public let blocker: BlockerCategory
    public let enabledByDefault: Bool
    /// ISO 639-1 codes; a regional list is enabled by default when the
    /// device language matches one of them.
    public let languages: [String]

    init(
        id: String,
        name: String,
        summary: String,
        url: String,
        category: BlockerCategory,
        blocker: BlockerCategory? = nil,
        enabledByDefault: Bool = false,
        languages: [String] = []
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.url = URL(string: url)!
        self.category = category
        self.blocker = blocker ?? category
        self.enabledByDefault = enabledByDefault
        self.languages = languages
    }

    public func isEnabledByDefault(languageCode: String?) -> Bool {
        if enabledByDefault { return true }
        guard let languageCode else { return false }
        return languages.contains(languageCode)
    }
}

public enum FilterCatalog {
    /// AdGuard publishes iOS-specific builds of its lists with platform
    /// directives already resolved, which convert cleanly for Safari.
    private static func adguard(_ number: Int) -> String {
        "https://filters.adtidy.org/ios/filters/\(number)_optimized.txt"
    }

    public static let all: [FilterList] = [
        // MARK: Ads
        FilterList(
            id: "adguard-base",
            name: "AdGuard Base",
            summary: "EasyList plus AdGuard's English ad filter. The core of ad blocking.",
            url: adguard(2),
            category: .ads,
            enabledByDefault: true
        ),
        FilterList(
            id: "adguard-mobile",
            name: "AdGuard Mobile Ads",
            summary: "Known mobile ad networks.",
            url: adguard(11),
            category: .ads,
            enabledByDefault: true
        ),

        // MARK: Privacy
        FilterList(
            id: "adguard-tracking",
            name: "AdGuard Tracking Protection",
            summary: "Web analytics, counters and tracking scripts.",
            url: adguard(3),
            category: .privacy,
            enabledByDefault: true
        ),
        FilterList(
            id: "peter-lowe",
            name: "Peter Lowe's Blocklist",
            summary: "Compact list of ad and tracking servers.",
            url: "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=adblockplus&mimetype=plaintext",
            category: .privacy,
            enabledByDefault: true
        ),
        // About 78k rules: in the Privacy blocker it would push tracker
        // protection over Safari's limit, so it compiles into Annoyances.
        FilterList(
            id: "phishing",
            name: "Phishing URL Blocklist",
            summary: "Blocks known phishing pages. Runs in the Eliminate Annoyances blocker, which has room to spare.",
            url: "https://malware-filter.gitlab.io/malware-filter/phishing-filter-ag.txt",
            category: .privacy,
            blocker: .annoyances
        ),

        // MARK: Annoyances
        FilterList(
            id: "adguard-cookies",
            name: "Cookie Notices",
            summary: "Removes cookie consent banners.",
            url: adguard(18),
            category: .annoyances,
            enabledByDefault: true
        ),
        FilterList(
            id: "adguard-popups",
            name: "Pop-ups",
            summary: "In-page pop-ups that are not needed for the site to work.",
            url: adguard(19),
            category: .annoyances,
            enabledByDefault: true
        ),
        FilterList(
            id: "adguard-app-banners",
            name: "Mobile App Banners",
            summary: "\"Open in app\" banners.",
            url: adguard(20),
            category: .annoyances,
            enabledByDefault: true
        ),
        FilterList(
            id: "adguard-other-annoyances",
            name: "Other Annoyances",
            summary: "Irritating elements that fit no other category.",
            url: adguard(21),
            category: .annoyances,
            enabledByDefault: true
        ),
        FilterList(
            id: "adguard-widgets",
            name: "Widgets",
            summary: "Support chats, online assistants and similar widgets.",
            url: adguard(22),
            category: .annoyances
        ),
        FilterList(
            id: "adguard-social",
            name: "Social Media",
            summary: "\"Like\" and \"Share\" buttons. May hide embedded posts.",
            url: adguard(4),
            category: .annoyances
        ),

        // MARK: Regional
        FilterList(id: "adguard-russian", name: "Russian", summary: "Russian-language sites.",
                   url: adguard(1), category: .regional, languages: ["ru", "be", "kk"]),
        FilterList(id: "adguard-german", name: "German", summary: "German-language sites.",
                   url: adguard(6), category: .regional, languages: ["de"]),
        FilterList(id: "adguard-japanese", name: "Japanese", summary: "Japanese-language sites.",
                   url: adguard(7), category: .regional, languages: ["ja"]),
        FilterList(id: "adguard-dutch", name: "Dutch", summary: "Dutch-language sites.",
                   url: adguard(8), category: .regional, languages: ["nl"]),
        FilterList(id: "adguard-spanish", name: "Spanish / Portuguese", summary: "Spanish- and Portuguese-language sites.",
                   url: adguard(9), category: .regional, languages: ["es", "pt"]),
        FilterList(id: "adguard-turkish", name: "Turkish", summary: "Turkish-language sites.",
                   url: adguard(13), category: .regional, languages: ["tr"]),
        FilterList(id: "adguard-french", name: "French", summary: "French-language sites.",
                   url: adguard(16), category: .regional, languages: ["fr"]),
        FilterList(id: "adguard-ukrainian", name: "Ukrainian", summary: "Ukrainian-language sites.",
                   url: adguard(23), category: .regional, languages: ["uk"]),
        FilterList(id: "adguard-chinese", name: "Chinese", summary: "Chinese-language sites.",
                   url: adguard(224), category: .regional, languages: ["zh"]),
    ]

    public static func lists(in category: BlockerCategory) -> [FilterList] {
        all.filter { $0.category == category }
    }

    public static func list(id: String) -> FilterList? {
        all.first { $0.id == id }
    }
}
