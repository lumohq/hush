import BlockerShared
import Foundation

/// Rule counts reported by the converter for one compiled content blocker.
public struct BlockerStats: Codable, Equatable, Sendable {
    public var safariRules: Int
    public var sourceRules: Int
    /// Rules dropped because the category exceeded Safari's rule or size limit.
    public var discardedRules: Int
    public var errors: Int
    public var compiledAt: Date

    public init(safariRules: Int, sourceRules: Int, discardedRules: Int, errors: Int, compiledAt: Date) {
        self.safariRules = safariRules
        self.sourceRules = sourceRules
        self.discardedRules = discardedRules
        self.errors = errors
        self.compiledAt = compiledAt
    }
}

/// User choices, persisted in the App Group's `UserDefaults` suite.
public final class ProtectionSettings: @unchecked Sendable {
    private enum Key {
        static let enabledFilters = "enabledFilterIDs"
        static let customRules = "customRules"
        static let allowlist = "allowlistDomains"
        static let lastUpdated = "lastFilterUpdate"
        static let stats = "blockerStats"
        static let onboarded = "hasCompletedOnboarding"
        static let wantsYouTube = "wantsYouTubeBlocking"
        static let userName = "userName"
    }

    private let defaults: UserDefaults
    private let languageCode: String?

    public init(defaults: UserDefaults, languageCode: String? = Locale.current.language.languageCode?.identifier) {
        self.defaults = defaults
        self.languageCode = languageCode
    }

    public var enabledFilterIDs: Set<String> {
        get {
            if let stored = defaults.stringArray(forKey: Key.enabledFilters) {
                return Set(stored)
            }
            return Set(FilterCatalog.all.filter { $0.isEnabledByDefault(languageCode: languageCode) }.map(\.id))
        }
        set { defaults.set(newValue.sorted(), forKey: Key.enabledFilters) }
    }

    public func isEnabled(_ filter: FilterList) -> Bool {
        enabledFilterIDs.contains(filter.id)
    }

    public func setEnabled(_ enabled: Bool, filter: FilterList) {
        var ids = enabledFilterIDs
        if enabled { ids.insert(filter.id) } else { ids.remove(filter.id) }
        enabledFilterIDs = ids
    }

    /// Enabled lists shown under `category`.
    public func enabledLists(in category: BlockerCategory) -> [FilterList] {
        let ids = enabledFilterIDs
        return FilterCatalog.lists(in: category).filter { ids.contains($0.id) }
    }

    /// Enabled lists compiled into `blocker`.
    public func enabledLists(compiledInto blocker: BlockerCategory) -> [FilterList] {
        let ids = enabledFilterIDs
        return FilterCatalog.all.filter { $0.blocker == blocker && ids.contains($0.id) }
    }

    public var customRules: String {
        get { defaults.string(forKey: Key.customRules) ?? "" }
        set { defaults.set(newValue, forKey: Key.customRules) }
    }

    /// Domains on which every content blocker is disabled.
    public var allowlist: [String] {
        get { defaults.stringArray(forKey: Key.allowlist) ?? [] }
        set { defaults.set(newValue, forKey: Key.allowlist) }
    }

    /// First name given during onboarding, used only for greetings. Stays on
    /// the device.
    public var userName: String {
        get { defaults.string(forKey: Key.userName) ?? "" }
        set { defaults.set(newValue, forKey: Key.userName) }
    }

    public var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.onboarded) }
        set { defaults.set(newValue, forKey: Key.onboarded) }
    }

    /// Whether the user wants the YouTube web extension. It has no filter
    /// lists, so this is the only record of the choice.
    public var wantsYouTubeBlocking: Bool {
        get { defaults.object(forKey: Key.wantsYouTube) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.wantsYouTube) }
    }

    /// Categories with something to block, whose Safari extension therefore
    /// needs to be on. The others can stay off without losing anything.
    public var activeCategories: [BlockerCategory] {
        BlockerCategory.allCases.filter { category in
            if category == .custom {
                return !customRules.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return !enabledLists(compiledInto: category).isEmpty
        }
    }

    public var lastUpdated: Date? {
        get { defaults.object(forKey: Key.lastUpdated) as? Date }
        set { defaults.set(newValue, forKey: Key.lastUpdated) }
    }

    public var stats: [BlockerCategory: BlockerStats] {
        get {
            guard
                let data = defaults.data(forKey: Key.stats),
                let decoded = try? JSONDecoder().decode([String: BlockerStats].self, from: data)
            else { return [:] }
            return Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
                BlockerCategory(rawValue: key).map { ($0, value) }
            })
        }
        set {
            let encodable = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.rawValue, $0.value) })
            defaults.set(try? JSONEncoder().encode(encodable), forKey: Key.stats)
        }
    }

    /// Normalises user input such as "https://www.Example.com/page" to
    /// "example.com". Returns `nil` when nothing domain-like remains.
    public static func normalizedDomain(_ input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let range = text.range(of: "://") {
            text = String(text[range.upperBound...])
        }
        text = String(text.prefix { $0 != "/" && $0 != "?" && $0 != "#" && $0 != ":" })
        if text.hasPrefix("www.") {
            text.removeFirst(4)
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
        guard
            text.contains("."),
            !text.hasPrefix("."), !text.hasSuffix("."),
            text.unicodeScalars.allSatisfy(allowed.contains)
        else { return nil }
        return text
    }
}
