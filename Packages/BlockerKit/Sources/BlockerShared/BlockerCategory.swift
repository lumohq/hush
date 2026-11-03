import Foundation

/// One Safari content blocker extension per category.
///
/// Safari caps every content blocker at 150,000 rules, so lists are spread
/// across several extensions instead of being merged into one.
public enum BlockerCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case ads
    case privacy
    case annoyances
    case regional
    case custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ads: return "Block Ads"
        case .privacy: return "Preserve Privacy"
        case .annoyances: return "Eliminate Annoyances"
        case .regional: return "Regional Ads"
        case .custom: return "Custom Rules"
        }
    }

    public var summary: String {
        switch self {
        case .ads:
            return "Pop-ups, banners, video ads and ad networks."
        case .privacy:
            return "Analytics, tracking pixels and fingerprinting scripts."
        case .annoyances:
            return "Cookie prompts, newsletter pop-ups, app banners and chat widgets."
        case .regional:
            return "Ads on sites in languages other than English."
        case .custom:
            return "Your own rules in Adblock syntax."
        }
    }

    public var symbolName: String {
        switch self {
        case .ads: return "rectangle.slash"
        case .privacy: return "eye.slash"
        case .annoyances: return "hand.raised"
        case .regional: return "globe"
        case .custom: return "slider.horizontal.3"
        }
    }

    /// Bundle identifier of the content blocker extension, derived from the
    /// containing app's identifier so the project only defines it once.
    public func extensionIdentifier(appBundleIdentifier: String) -> String {
        "\(appBundleIdentifier).blocker.\(rawValue)"
    }
}
