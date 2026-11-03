import BlockerShared
import Foundation

/// Shared by every content blocker target. Each target's Info.plist names its
/// category under `BlockerCategory`; the handler gives Safari the JSON the app
/// compiled into the App Group, or the bundled no-op list before the first
/// compile.
final class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let item = NSExtensionItem()
        if let provider = NSItemProvider(contentsOf: blockerListURL()) {
            item.attachments = [provider]
        }
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }

    private func blockerListURL() -> URL {
        let bundled = Bundle.main.url(forResource: "blockerList", withExtension: "json")!
        guard
            let rawCategory = Bundle.main.object(forInfoDictionaryKey: "BlockerCategory") as? String,
            let category = BlockerCategory(rawValue: rawCategory),
            let container = SharedContainer.appGroup()
        else {
            return bundled
        }
        let compiled = container.blockerListURL(for: category)
        return FileManager.default.fileExists(atPath: compiled.path) ? compiled : bundled
    }
}
