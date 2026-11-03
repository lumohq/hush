import SwiftUI

/// Copyright, license and credits. GPLv3 section 5(d) asks an interactive
/// program to show its copyright, that there is no warranty, and where the
/// license is; this screen is that notice.
struct AboutView: View {
    static let sourceURL = URL(string: "https://github.com/lumohq/hush")!

    private struct Credit: Identifiable {
        let name: String
        let author: String
        let license: String
        let url: String
        var id: String { name }
    }

    private let credits = [
        Credit(name: "SafariConverterLib", author: "AdGuard", license: "GPL-3.0",
               url: "https://github.com/AdguardTeam/SafariConverterLib"),
        Credit(name: "PunycodeSwift", author: "Gumob", license: "MIT",
               url: "https://github.com/gumob/PunycodeSwift"),
        Credit(name: "swift-psl", author: "Andrey Meshkov", license: "MIT",
               url: "https://github.com/ameshkov/swift-psl"),
        Credit(name: "Public Suffix List", author: "Mozilla", license: "MPL-2.0",
               url: "https://publicsuffix.org"),
        Credit(name: "Fluent Emoji", author: "Microsoft", license: "MIT",
               url: "https://github.com/microsoft/fluentui-emoji"),
    ]

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hush \(version)")
                        .font(.hushHeadline)
                    Text("Copyright © 2026 Lumo")
                    Text("Hush is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License, version 3 or later. It comes with ABSOLUTELY NO WARRANTY.")
                        .font(.hushCaption)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.vertical, 4)
                Link(destination: Self.sourceURL) {
                    Label("Source code", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                NavigationLink {
                    LicenseTextView(title: "GNU GPL v3", resource: "LICENSE", fileExtension: nil)
                } label: {
                    Label("License", systemImage: "doc.text")
                }
            }

            Section {
                ForEach(credits) { credit in
                    Link(destination: URL(string: credit.url)!) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(credit.name)
                                .foregroundStyle(Theme.text)
                            Text("\(credit.author) · \(credit.license)")
                                .font(.hushCaption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
                NavigationLink {
                    LicenseTextView(title: "Notices", resource: "THIRD_PARTY_NOTICES", fileExtension: "md")
                } label: {
                    Label("Full notices", systemImage: "doc.text")
                }
            } header: {
                Text("Built with")
            } footer: {
                Text("Filter lists are downloaded from their publishers (AdGuard, EasyList, Peter Lowe and others) and stay under their own licenses.")
            }
        }
        .navigationTitle("About & Licenses")
        .hushListBackground()
    }
}

/// A plain-text license file bundled with the app.
private struct LicenseTextView: View {
    let title: String
    let resource: String
    let fileExtension: String?

    private var text: String {
        guard let url = Bundle.main.url(forResource: resource, withExtension: fileExtension),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "The license text is missing from this build. See \(AboutView.sourceURL.absoluteString)." }
        return text
    }

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.background.ignoresSafeArea())
    }
}
