import BlockerKit
import SwiftUI

/// Something on the web the user may want quieted. Each maps to filter lists,
/// except YouTube, which is handled by the web extension.
enum NoiseSource: String, CaseIterable, Identifiable {
    case ads, trackers, popups, youtube, chatWidgets, socialButtons, scams

    var id: String { rawValue }

    var icon: AppIcon {
        switch self {
        case .ads: return .fluent("megaphone")
        case .trackers: return .fluent("eyes")
        case .popups: return .fluent("cookie")
        case .youtube: return .fluent("television")
        case .chatWidgets: return .fluent("speech-balloon")
        case .socialButtons: return .fluent("thumbs-up")
        case .scams: return .fluent("fishing-pole")
        }
    }

    var title: String {
        switch self {
        case .ads: return "Ads"
        case .trackers: return "Trackers"
        case .popups: return "Cookie prompts & pop-ups"
        case .youtube: return "YouTube ads"
        case .chatWidgets: return "Chat widgets"
        case .socialButtons: return "Social buttons"
        case .scams: return "Scam sites"
        }
    }

    var detail: String {
        switch self {
        case .ads: return "Banners, pop-up ads and video ads."
        case .trackers: return "Pixels that follow you from site to site."
        case .popups: return "Consent banners, newsletter pop-ups, app bars."
        case .youtube: return "Skips video ads, hides promoted videos."
        case .chatWidgets: return "Support chats and floating assistants."
        case .socialButtons: return "Like and Share buttons. Embeds may vanish too."
        case .scams: return "Known phishing pages that copy real sites."
        }
    }

    var tint: Color {
        switch self {
        case .ads: return Theme.primary
        case .trackers: return Color(hex: 0x5B6CFF)
        case .popups: return Theme.warning
        case .youtube: return Theme.noise
        case .chatWidgets: return Theme.success
        case .socialButtons: return Color(hex: 0xFF6FB5)
        case .scams: return Color(hex: 0x9B59D0)
        }
    }

    /// What the mascot says when this is picked.
    var reaction: String {
        switch self {
        case .ads: return "Ads? Consider them gone."
        case .trackers: return "Nobody likes being followed."
        case .popups: return "Cookie banners. Ugh. Same."
        case .youtube: return "Skip, skip, skip. I've got it."
        case .chatWidgets: return "Bye-bye, chat bubbles."
        case .socialButtons: return "No more Like buttons everywhere."
        case .scams: return "I'll keep an eye out for fakes."
        }
    }

    /// Filter lists from `FilterCatalog` this choice turns on.
    var filterIDs: [String] {
        switch self {
        case .ads: return ["adguard-base", "adguard-mobile"]
        case .trackers: return ["adguard-tracking", "peter-lowe"]
        case .popups: return ["adguard-cookies", "adguard-popups", "adguard-app-banners", "adguard-other-annoyances"]
        case .youtube: return []
        case .chatWidgets: return ["adguard-widgets"]
        case .socialButtons: return ["adguard-social"]
        case .scams: return ["phishing"]
        }
    }

    static let baseline: Set<NoiseSource> = [.ads, .trackers, .popups]
}

/// What the user mostly does in Safari. Only used to recommend noise sources.
enum BrowsingInterest: String, CaseIterable, Identifiable {
    case news, shopping, videos, social, work, recipes

    var id: String { rawValue }

    var icon: AppIcon {
        switch self {
        case .news: return .fluent("newspaper")
        case .shopping: return .fluent("shopping-bags")
        case .videos: return .fluent("clapper-board")
        case .social: return .fluent("mobile-phone")
        case .work: return .fluent("briefcase")
        case .recipes: return .fluent("cooking")
        }
    }

    var title: String {
        switch self {
        case .news: return "News & reading"
        case .shopping: return "Shopping"
        case .videos: return "Videos"
        case .social: return "Social media"
        case .work: return "Work & research"
        case .recipes: return "Recipes & blogs"
        }
    }

    var recommends: Set<NoiseSource> {
        switch self {
        case .news: return [.ads, .popups]
        case .shopping: return [.trackers, .scams]
        case .videos: return [.youtube]
        case .social: return [.trackers]
        case .work: return [.chatWidgets]
        case .recipes: return [.ads, .popups]
        }
    }
}

/// Language codes for regional filters. Fluent Emoji has no flags, and a
/// code is more accurate than a country flag for a language anyway.
enum RegionalLanguage {
    static let english = AppIcon.language("EN")

    static func icon(for filterID: String) -> AppIcon {
        switch filterID {
        case "adguard-russian": return .language("RU")
        case "adguard-german": return .language("DE")
        case "adguard-japanese": return .language("JA")
        case "adguard-dutch": return .language("NL")
        case "adguard-spanish": return .language("ES")
        case "adguard-turkish": return .language("TR")
        case "adguard-french": return .language("FR")
        case "adguard-ukrainian": return .language("UK")
        case "adguard-chinese": return .language("ZH")
        default: return .fluent("globe")
        }
    }
}
