import BlockerKit
import SwiftUI

struct AllowlistView: View {
    @EnvironmentObject private var model: ProtectionModel
    @State private var newDomain = ""
    @State private var invalidInput = false

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("example.com", text: $newDomain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .submitLabel(.done)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } footer: {
                if invalidInput {
                    Text("Enter a domain such as example.com.")
                        .foregroundStyle(.red)
                } else {
                    Text("Nothing is blocked on these sites or their subdomains.")
                }
            }

            if !model.settings.allowlist.isEmpty {
                Section("Allowed") {
                    ForEach(model.settings.allowlist, id: \.self) { domain in
                        Text(domain)
                    }
                    .onDelete(perform: model.removeAllowlistDomains)
                }
            }
        }
        .navigationTitle("Allowed Websites")
        .hushListBackground()
        .toolbar {
            if !model.settings.allowlist.isEmpty {
                EditButton()
            }
        }
    }

    private func add() {
        invalidInput = !model.addAllowlistDomain(newDomain)
        if !invalidInput {
            newDomain = ""
        }
    }
}

struct CustomRulesView: View {
    @EnvironmentObject private var model: ProtectionModel
    @State private var text = ""
    @State private var loaded = false
    @State private var justSaved = false
    @FocusState private var editing: Bool

    var body: some View {
        List {
            Section {
                TextEditor(text: $text)
                    .font(.system(.footnote, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .frame(minHeight: 220)
                    .focused($editing)
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    if justSaved {
                        if model.isUpdating {
                            UpdatingNote(text: "Applying your rules…")
                        } else {
                            Label("Saved and active", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    StatsFooter(stats: model.stats[.custom], showsErrors: true)
                }
            }

            Section("Examples") {
                ExampleRule(rule: "||ads.example.com^", meaning: "Block every request to ads.example.com.")
                ExampleRule(rule: "example.com##.promo", meaning: "Hide elements with class \"promo\" on example.com.")
                ExampleRule(rule: "##.newsletter-popup", meaning: "Hide that element on every site.")
                ExampleRule(rule: "@@||example.com^$document", meaning: "Disable this blocker on example.com.")
            }
        }
        .navigationTitle("Custom Rules")
        .hushListBackground()
        .toolbar {
            Button("Save") {
                model.saveCustomRules(text)
                editing = false
                justSaved = true
            }
            .disabled(text == model.settings.customRules)
        }
        .onAppear {
            guard !loaded else { return }
            text = model.settings.customRules
            loaded = true
        }
        .onChange(of: text) { _, _ in
            justSaved = false
        }
    }
}

private struct ExampleRule: View {
    let rule: String
    let meaning: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rule)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
            Text(meaning)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
