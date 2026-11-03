import Foundation

/// File layout inside the App Group container shared by the app and its
/// extensions. The app writes compiled rule lists here; each content blocker
/// hands its file to Safari.
public struct SharedContainer: Sendable {
    /// Info.plist key that holds the App Group identifier in every target.
    public static let appGroupInfoKey = "AppGroupIdentifier"

    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    /// The App Group container for the running process, or `nil` when the
    /// entitlement is missing (for example in an unsigned build).
    public static func appGroup(bundle: Bundle = .main) -> SharedContainer? {
        guard
            let groupID = bundle.object(forInfoDictionaryKey: appGroupInfoKey) as? String,
            let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
        else {
            return nil
        }
        return SharedContainer(root: url)
    }

    public var filtersDirectory: URL { root.appendingPathComponent("filters", isDirectory: true) }
    public var blockersDirectory: URL { root.appendingPathComponent("blockers", isDirectory: true) }

    /// Raw downloaded filter list text.
    public func filterCacheURL(filterID: String) -> URL {
        filtersDirectory.appendingPathComponent("\(filterID).txt")
    }

    /// Compiled Safari content blocker JSON for a category.
    public func blockerListURL(for category: BlockerCategory) -> URL {
        blockersDirectory.appendingPathComponent("\(category.rawValue).json")
    }

    public func createDirectories() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: filtersDirectory, withIntermediateDirectories: true)
        try fm.createDirectory(at: blockersDirectory, withIntermediateDirectories: true)
    }
}
