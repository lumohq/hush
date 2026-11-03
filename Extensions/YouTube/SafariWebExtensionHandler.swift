import Foundation
import SafariServices

/// Required principal class for a Safari web extension. The YouTube script
/// runs entirely in the page and never messages the native side.
final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        context.completeRequest(returningItems: [], completionHandler: nil)
    }
}
