import BlockerKit
import BlockerShared
import SwiftUI

struct CategoryView: View {
    @EnvironmentObject private var model: ProtectionModel
    @State private var showingSetup = false
    let category: BlockerCategory

    var body: some View {
        List {
            Section {
                Text(category.explanation)
                    .foregroundStyle(.secondary)
            }

            // Only worth flagging when this category has something to block.
            if model.requiredBlockers.contains(category) && !model.isExtensionEnabled(category) {
                Section {
                    Button {
                        showingSetup = true
                    } label: {
                        Label("This blocker is turned off in Safari settings.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
                ForEach(FilterCatalog.lists(in: category)) { list in
                    Toggle(isOn: binding(for: list)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(list.name)
                            Text(list.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let failure = model.failedLists[list.id] {
                                Text("Update failed: \(failure)")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            } header: {
                Text("Filter Lists")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    if model.isUpdating {
                        UpdatingNote(text: "Applying your changes…")
                    }
                    StatsFooter(stats: model.stats[category])
                }
            }
        }
        .navigationTitle(category.title)
        .hushListBackground()
        .sheet(isPresented: $showingSetup) {
            SetupGuideView()
        }
    }

    private func binding(for list: FilterList) -> Binding<Bool> {
        Binding(
            get: { model.settings.isEnabled(list) },
            set: { model.setFilter(list, enabled: $0) }
        )
    }
}

struct StatsFooter: View {
    let stats: BlockerStats?
    /// For the user's own rules, unconverted ones are worth pointing out;
    /// in public lists they are expected.
    var showsErrors = false

    var body: some View {
        if let stats, stats.sourceRules > 0 {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(stats.safariRules.counted("Safari rule")) compiled from \(stats.sourceRules.counted("filter rule")). Rules Safari cannot express are skipped.")
                if showsErrors && stats.errors > 0 {
                    Text("\(stats.errors) of your rules couldn't be converted. Check their syntax against the examples below.")
                        .foregroundStyle(.orange)
                }
                if stats.discardedRules > 0 {
                    Text("\(stats.discardedRules.counted("rule")) \(stats.discardedRules == 1 ? "was" : "were") dropped because this blocker exceeded Safari's limits (150,000 rules and a maximum file size). Turn off a list to make room.")
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

/// Small spinner line shown while a change is being applied.
struct UpdatingNote: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text(text)
        }
    }
}
