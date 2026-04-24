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

    /// Target face for the new session. Auto-selects from the bow's type, but
    /// tracks a "user touched" flag so the archer's override isn't clobbered
    /// if they then pick a different bow.
    @State private var selectedFaceType: TargetFaceType = .sixRing
    @State private var userTouchedFace: Bool = false

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
                                .accessibilityIdentifier("session_bow_row_\(bow.id)")
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

                // MARK: Bow Config (compact chip)
                if selectedBow != nil {
                    if isLoadingConfig {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7)
                            Text("Loading config…")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.top, -16)
                    } else if let config = selectedBowConfig {
                        Button { if availableConfigs.count > 1 { showConfigPicker = true } } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text(config.label ?? "Default Config")
                                    .font(.caption).foregroundStyle(.secondary)
                                if availableConfigs.count > 1 {
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(availableConfigs.count <= 1)
                        .padding(.top, -16)
                        .accessibilityIdentifier("session_config_row_\(config.id)")
                    }
                }

                // MARK: Target Face Picker
                if selectedBow != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("Target Face", icon: "scope")
                        Picker("Target face", selection: $selectedFaceType) {
                            ForEach(TargetFaceType.allCases, id: \.self) { face in
                                Text(face.label).tag(face)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedFaceType) { _, _ in
                            userTouchedFace = true
                        }
                        .accessibilityIdentifier("session_face_picker")
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
        // Auto-sync the face type to the bow's default unless the user has
        // explicitly picked one in this setup flow.
        if !userTouchedFace {
            selectedFaceType = TargetFaceType.defaultFor(bow.bowType)
        }
        Task { await loadConfigs(for: bow) }
    }

    private func loadConfigs(for bow: Bow) async {
        isLoadingConfig = true
        do {
            let configs = try await APIClient.shared.fetchConfigurations(bowId: bow.id)
            availableConfigs = configs.sorted { $0.createdAt > $1.createdAt }
            selectedBowConfig = availableConfigs.first ?? BowConfiguration.makeDefault(for: bow)
        } catch {
            configError = error.localizedDescription
            selectedBowConfig = BowConfiguration.makeDefault(for: bow)
        }
        isLoadingConfig = false
    }

    private func startSession() async {
        guard let bow = selectedBow,
              let bowConfig = selectedBowConfig,
              let arrowConfig = selectedArrowConfig else { return }
        isStarting = true
        await viewModel.startSession(
            bow: bow,
            bowConfig: bowConfig,
            arrowConfig: arrowConfig,
            targetFaceType: selectedFaceType
        )
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
                            Text("Draw \(String(format: "%.1f\"", config.drawLength))  ·  Let-Off \(String(format: "%.0f%%", config.letOffPct ?? 0))  ·  Peep \(String(format: "%.2f\"", config.peepHeight ?? 0))")
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
