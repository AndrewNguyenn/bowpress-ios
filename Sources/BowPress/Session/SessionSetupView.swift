import SwiftUI

struct SessionSetupView: View {
    var appState: AppState
    @Bindable var viewModel: SessionViewModel

    @State private var selectedBow: Bow?
    @State private var selectedBowConfig: BowConfiguration?
    @State private var availableConfigs: [BowConfiguration] = []
    @State private var isLoadingConfig = false
    @State private var configError: String?
    @State private var showConfigPicker = false
    @State private var selectedArrowConfig: ArrowConfiguration?
    @State private var isStarting = false

    var canStart: Bool {
        selectedBow != nil && selectedArrowConfig != nil && selectedBowConfig != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: Header
                VStack(spacing: 4) {
                    Image(systemName: "scope")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.accentColor)
                    Text("New Session")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Choose your equipment to begin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)

                // MARK: Bow Picker
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("Bow", icon: "arrow.forward")

                    if appState.bows.isEmpty {
                        emptyStateCard(
                            message: "No bows configured.",
                            detail: "Go to the Configure tab to add your first bow."
                        )
                    } else {
                        VStack(spacing: 0) {
                            ForEach(appState.bows) { bow in
                                BowRow(
                                    bow: bow,
                                    isSelected: selectedBow?.id == bow.id
                                ) {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        selectBow(bow)
                                    }
                                }
                                if bow.id != appState.bows.last?.id {
                                    Divider().padding(.leading, 56)
                                }
                            }
                        }
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.separator, lineWidth: 0.5)
                        )
                    }
                }

                // MARK: Bow Config Summary
                if let bow = selectedBow {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("Bow Configuration", icon: "slider.horizontal.3")

                        if isLoadingConfig {
                            loadingCard()
                        } else if let config = selectedBowConfig {
                            BowConfigSummaryCard(config: config, bowName: bow.name)
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        showConfigPicker = true
                                    } label: {
                                        Text("Change")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Color.accentColor)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.accentColor.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                    .padding(12)
                                }
                        } else if let err = configError {
                            errorCard(err)
                        } else {
                            emptyStateCard(
                                message: "No configurations found.",
                                detail: "A default configuration will be created."
                            )
                        }
                    }
                }

                // MARK: Arrow Picker
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("Arrows", icon: "arrow.right")

                    if appState.arrowConfigs.isEmpty {
                        emptyStateCard(
                            message: "No arrow configurations.",
                            detail: "Go to Configure to add your arrows."
                        )
                    } else {
                        VStack(spacing: 0) {
                            ForEach(appState.arrowConfigs) { arrow in
                                ArrowRow(
                                    arrow: arrow,
                                    isSelected: selectedArrowConfig?.id == arrow.id
                                ) {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        selectedArrowConfig = arrow
                                    }
                                }
                                if arrow.id != appState.arrowConfigs.last?.id {
                                    Divider().padding(.leading, 56)
                                }
                            }
                        }
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.separator, lineWidth: 0.5)
                        )
                    }
                }

                // MARK: Start Button
                Button {
                    Task { await startSession() }
                } label: {
                    HStack {
                        if isStarting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .scaleEffect(0.85)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(isStarting ? "Starting…" : "Start Session")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canStart || isStarting)
                .opacity(canStart ? 1 : 0.5)

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
        }
        .navigationTitle("New Session")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showConfigPicker) {
            if let bow = selectedBow {
                ConfigPickerSheet(
                    configs: availableConfigs,
                    bowName: bow.name,
                    selected: $selectedBowConfig
                )
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    @ViewBuilder
    private func emptyStateCard(message: String, detail: String) -> some View {
        VStack(spacing: 6) {
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.quaternary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func loadingCard() -> some View {
        HStack {
            ProgressView()
            Text("Loading configurations…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.quaternary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func errorCard(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.quaternary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func selectBow(_ bow: Bow) {
        selectedBow = bow
        selectedBowConfig = nil
        availableConfigs = []
        configError = nil
        Task { await loadConfigs(for: bow) }
    }

    private func loadConfigs(for bow: Bow) async {
        isLoadingConfig = true
        do {
            let configs = try await APIClient.shared.fetchConfigurations(bowId: bow.id)
            availableConfigs = configs.sorted { $0.createdAt > $1.createdAt }
            selectedBowConfig = availableConfigs.first ?? BowConfiguration.makeDefault(for: bow.id)
        } catch {
            configError = error.localizedDescription
            selectedBowConfig = BowConfiguration.makeDefault(for: bow.id)
        }
        isLoadingConfig = false
    }

    private func startSession() async {
        guard let bow = selectedBow,
              let bowConfig = selectedBowConfig,
              let arrowConfig = selectedArrowConfig else { return }
        isStarting = true
        await viewModel.startSession(bow: bow, bowConfig: bowConfig, arrowConfig: arrowConfig)
        isStarting = false
    }
}

// MARK: - Bow Row

private struct BowRow: View {
    var bow: Bow
    var isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                        .frame(width: 36, height: 36)
                    Image(systemName: "arrow.forward")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(bow.name)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("\(bow.brand) \(bow.model)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Arrow Row

private struct ArrowRow: View {
    var arrow: ArrowConfiguration
    var isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                        .frame(width: 36, height: 36)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(arrow.label)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(arrowDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var arrowDetail: String {
        var parts: [String] = []
        parts.append(String(format: "%.2f\"", arrow.length))
        parts.append("\(arrow.pointWeight)gr point")
        parts.append(arrow.fletchingType.rawValue)
        return parts.joined(separator: " · ")
    }
}

// MARK: - Bow Config Summary Card

private struct BowConfigSummaryCard: View {
    var config: BowConfiguration
    var bowName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(config.label ?? "Configuration")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Created \(config.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 60)
            }

            Divider()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ConfigParam(label: "Draw Length", value: String(format: "%.1f\"", config.drawLength))
                ConfigParam(label: "Let-Off", value: String(format: "%.0f%%", config.letOffPct))
                ConfigParam(label: "Peep Height", value: String(format: "%.2f\"", config.peepHeight))
                ConfigParam(label: "D-Loop", value: String(format: "%.2f\"", config.dLoopLength))
                ConfigParam(label: "Rest Vert", value: "\(config.restVertical >= 0 ? "+" : "")\(config.restVertical)/16\"")
                ConfigParam(label: "Nocking Ht", value: "\(config.nockingHeight >= 0 ? "+" : "")\(config.nockingHeight)/16\"")
            }
        }
        .padding(14)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }
}

private struct ConfigParam: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Config Picker Sheet

private struct ConfigPickerSheet: View {
    var configs: [BowConfiguration]
    var bowName: String
    @Binding var selected: BowConfiguration?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(configs) { config in
                Button {
                    selected = config
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(config.label ?? "Configuration")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Text(config.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Draw \(String(format: "%.1f\"", config.drawLength))  ·  Let-Off \(String(format: "%.0f%%", config.letOffPct))  ·  Peep \(String(format: "%.2f\"", config.peepHeight))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        if selected?.id == config.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Select Config")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("With Bows") {
    let appState = AppState()
    appState.bows = [
        Bow(id: "b1", userId: "u1", name: "My Hoyt", brand: "Hoyt", model: "Carbon RX-8", createdAt: Date()),
        Bow(id: "b2", userId: "u1", name: "Training Bow", brand: "Mathews", model: "Phase4 29", createdAt: Date())
    ]
    appState.arrowConfigs = [
        ArrowConfiguration(
            id: "a1", userId: "u1", label: "Match Arrows",
            brand: "Easton", model: "X10",
            length: 28.5, pointWeight: 110,
            fletchingType: .vane, fletchingLength: 2.0, fletchingOffset: 1.5
        ),
        ArrowConfiguration(
            id: "a2", userId: "u1", label: "Practice",
            brand: "Gold Tip", model: "Hunter XT",
            length: 29.0, pointWeight: 100,
            fletchingType: .vane, fletchingLength: 2.25, fletchingOffset: 2.0
        )
    ]
    return NavigationStack {
        SessionSetupView(appState: appState, viewModel: SessionViewModel())
    }
}

#Preview("Empty State") {
    NavigationStack {
        SessionSetupView(appState: AppState(), viewModel: SessionViewModel())
    }
}
