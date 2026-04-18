import SwiftUI

// MARK: - HistoricalSessionsView

struct HistoricalSessionsView: View {
    let sessions: [ShootingSession]
    let bowName: String
    var allConfigs: [BowConfiguration] = []

    @State private var selectedSession: ShootingSession?

    // Group sessions by week bucket.
    private var groupedSessions: [(header: String, sessions: [ShootingSession])] {
        let sorted = sessions.sorted { $0.startedAt > $1.startedAt }
        let dict = Dictionary(grouping: sorted) { session -> String in
            weekBucket(for: session.startedAt)
        }
        // Preserve sorted order of week buckets (most recent first).
        let bucketOrder = sorted.map { weekBucket(for: $0.startedAt) }
            .reduce(into: [String]()) { result, bucket in
                if !result.contains(bucket) { result.append(bucket) }
            }
        return bucketOrder.compactMap { bucket in
            guard let items = dict[bucket] else { return nil }
            return (header: bucket, sessions: items)
        }
    }

    var body: some View {
        Group {
            if sessions.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(groupedSessions, id: \.header) { group in
                        Section {
                            ForEach(group.sessions) { session in
                                SessionRow(session: session)
                                    .onTapGesture { selectedSession = session }
                            }
                        } header: {
                            Text(group.header)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Sessions — \(bowName)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSession) { session in
            SessionDetailSheet(session: session, allConfigs: allConfigs)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 56))
                .foregroundStyle(.quaternary)
            Text("No sessions yet")
                .font(.title3.weight(.semibold))
            Text("Log a session to see your history here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Week bucket label

    private func weekBucket(for date: Date) -> String {
        let cal = Calendar.current
        let now = Date()
        if cal.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            return "This Week"
        }
        let oneWeekAgo = cal.date(byAdding: .weekOfYear, value: -1, to: now)!
        if cal.isDate(date, equalTo: oneWeekAgo, toGranularity: .weekOfYear) {
            return "Last Week"
        }
        // Older: use "Month Year" label
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - SessionRow

private struct SessionRow: View {
    let session: ShootingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(session.arrowCount) arrows")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Feel tags
            if !session.feelTags.isEmpty {
                WrappingTagRow(tags: session.feelTags)
            }

        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - WrappingTagRow

struct WrappingTagRow: View {
    let tags: [String]
    var maxVisible: Int = 4

    var body: some View {
        HStack(spacing: 5) {
            ForEach(tags.prefix(maxVisible), id: \.self) { tag in
                Text(tag)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
            if tags.count > maxVisible {
                Text("+\(tags.count - maxVisible)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(.systemFill), in: Capsule())
            }
        }
    }
}

// MARK: - SessionDetailSheet

struct SessionDetailSheet: View {
    let session: ShootingSession
    var allConfigs: [BowConfiguration] = []
    @Environment(\.dismiss) private var dismiss

    @State private var selectedEnd: SessionEnd?

    private var sessionEnds: [SessionEnd] { session.ends ?? [] }
    private var allArrows: [ArrowPlot] { session.arrows ?? [] }

    private var displayedArrows: [ArrowPlot] {
        guard let end = selectedEnd else { return allArrows }
        return allArrows.filter { $0.endId == end.id }
    }

    private var displayedAvgRing: Double {
        let arrows = displayedArrows
        guard !arrows.isEmpty else { return 0 }
        return Double(arrows.reduce(0) { $0 + min($1.ring, 10) }) / Double(arrows.count)
    }

    private var totalScore: Int { allArrows.reduce(0) { $0 + min($1.ring, 10) } }
    private var avgRing: Double {
        allArrows.isEmpty ? 0 : Double(totalScore) / Double(allArrows.count)
    }
    private var xCount: Int { allArrows.filter { $0.ring == 11 }.count }

    private var configTransitions: [(config: BowConfiguration?, at: Date)] {
        let sorted = allArrows.sorted { $0.shotAt < $1.shotAt }
        var result: [(config: BowConfiguration?, at: Date)] = []
        var lastId = ""
        for arrow in sorted {
            guard arrow.bowConfigId != lastId else { continue }
            lastId = arrow.bowConfigId
            let cfg = allConfigs.first { $0.id == arrow.bowConfigId }
            result.append((config: cfg, at: arrow.shotAt))
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                // Performance summary
                Section("Performance") {
                    DetailRow(label: "Total Arrows", value: "\(session.arrowCount)")
                    if !allArrows.isEmpty {
                        DetailRow(label: "Avg Ring Score", value: String(format: "%.1f", avgRing))
                        if xCount > 0 {
                            DetailRow(label: "X Count", value: "\(xCount)")
                        }
                        DetailRow(label: "10+ Ring Rate", value: String(format: "%.0f%%",
                            Double(allArrows.filter { $0.ring >= 10 }.count) / Double(allArrows.count) * 100))
                    }
                }

                // Shot distribution heatmap
                if !allArrows.isEmpty {
                    Section {
                        VStack(spacing: 8) {
                            SessionHeatMapView(plots: displayedArrows)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .padding(.horizontal, 24)
                                .animation(.easeInOut(duration: 0.25), value: selectedEnd?.id)

                            if let end = selectedEnd {
                                let endArrows = allArrows.filter { $0.endId == end.id }
                                HStack(spacing: 12) {
                                    Text("End \(end.endNumber)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.appAccent)
                                    Text("·")
                                        .foregroundStyle(.tertiary)
                                    Text("\(endArrows.count) arrows")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("·")
                                        .foregroundStyle(.tertiary)
                                    Text(String(format: "%.1f avg", displayedAvgRing))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Show All") {
                                        withAnimation { selectedEnd = nil }
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.appAccent)
                                }
                                .padding(.horizontal, 24)
                                .transition(.opacity)
                            }
                        }
                        .padding(.vertical, 12)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } header: {
                        Text(selectedEnd == nil ? "Shot Distribution" : "End \(selectedEnd!.endNumber)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }

                // Per-end breakdown (tap to filter heatmap)
                if !sessionEnds.isEmpty {
                    Section {
                        ForEach(sessionEnds) { end in
                            let endArrows = allArrows.filter { $0.endId == end.id }
                            let isSelected = selectedEnd?.id == end.id
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedEnd = isSelected ? nil : end
                                }
                            } label: {
                                HStack {
                                    EndRow(end: end, arrows: endArrows, isCurrent: false)
                                    Spacer(minLength: 0)
                                    if isSelected {
                                        Image(systemName: "target")
                                            .font(.caption)
                                            .foregroundStyle(Color.appAccent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(isSelected ? Color.appAccent.opacity(0.08) : Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        Text("\(sessionEnds.count) Ends · Tap to inspect")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }

                // Feel tags
                if !session.feelTags.isEmpty {
                    Section("Feel") {
                        WrappingTagRow(tags: session.feelTags, maxVisible: 20)
                            .padding(.vertical, 4)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }

                // Configuration changes
                if configTransitions.count > 1 {
                    Section("Configuration Changes") {
                        ForEach(Array(configTransitions.enumerated()), id: \.offset) { idx, transition in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(idx == 0 ? "Started with" : "Changed at")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(transition.at.formatted(date: .omitted, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let cfg = transition.config {
                                    Text(cfg.label ?? cfg.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline.weight(.semibold))
                                } else {
                                    Text("Unknown config")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // Time (bottom)
                Section("Time") {
                    DetailRow(label: "Started", value: session.startedAt.formatted(date: .complete, time: .shortened))
                    if let ended = session.endedAt {
                        DetailRow(label: "Ended", value: ended.formatted(date: .complete, time: .shortened))
                        DetailRow(label: "Duration", value: durationString(from: session.startedAt, to: ended))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Session Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func durationString(from start: Date, to end: Date) -> String {
        let secs = Int(end.timeIntervalSince(start))
        let mins = secs / 60
        let hours = mins / 60
        return hours > 0 ? "\(hours)h \(mins % 60)m" : "\(mins)m"
    }
}

// MARK: - SessionHeatMapView

private struct SessionHeatMapView: View {
    let plots: [ArrowPlot]

    var body: some View {
        Image("target_face")
            .resizable()
            .scaledToFit()
            .overlay {
                Canvas { context, size in
                    for (i, plot) in plots.enumerated() {
                        let pt = position(for: plot, jitterIndex: i, in: size)
                        let rect = CGRect(x: pt.x - 22, y: pt.y - 22, width: 44, height: 44)
                        context.fill(Path(ellipseIn: rect), with: .color(Color.appAccent.opacity(0.72)))
                    }
                }
                .drawingGroup()
                .blur(radius: 10)
            }
            .overlay {
                Canvas { context, size in
                    guard let c = centroid(for: plots, in: size) else { return }
                    let r: CGFloat = 12
                    let bw: CGFloat = 2.5
                    let fill = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                    let ring = CGRect(x: c.x - r - bw, y: c.y - r - bw,
                                      width: (r + bw) * 2, height: (r + bw) * 2)
                    context.fill(Path(ellipseIn: fill), with: .color(Color.appAccent))
                    context.stroke(Path(ellipseIn: ring), with: .color(.white.opacity(0.9)), lineWidth: bw)
                }
            }
            .clipShape(Circle())
    }

    private func position(for plot: ArrowPlot, jitterIndex: Int, in size: CGSize) -> CGPoint {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let halfW  = size.width / 2
        let nr: Double
        switch plot.ring {
        case 11: nr = 0.08
        case 10: nr = 0.245
        case 9:  nr = 0.494
        default: nr = 0.83
        }
        let baseAngle: Double
        switch plot.zone {
        case .center: baseAngle = Double(jitterIndex % 6) * .pi / 3
        case .n:      baseAngle =  .pi / 2
        case .ne:     baseAngle =  .pi / 4
        case .e:      baseAngle =  0
        case .se:     baseAngle = -.pi / 4
        case .s:      baseAngle = -.pi / 2
        case .sw:     baseAngle = -.pi * 3 / 4
        case .w:      baseAngle =  .pi
        case .nw:     baseAngle =  .pi * 3 / 4
        }
        let jitter = Double(jitterIndex % 5) * 0.12 - 0.24
        let r = nr * halfW * 0.92
        return CGPoint(x: center.x + r * cos(baseAngle + jitter),
                       y: center.y - r * sin(baseAngle + jitter))
    }

    private func centroid(for plots: [ArrowPlot], in size: CGSize) -> CGPoint? {
        guard !plots.isEmpty else { return nil }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let halfW  = size.width / 2
        var sumX: Double = 0, sumY: Double = 0
        for plot in plots {
            let nr: Double
            switch plot.ring {
            case 11: nr = 0.0
            case 10: nr = 0.245
            case 9:  nr = 0.494
            default: nr = 0.83
            }
            let angle: Double
            switch plot.zone {
            case .center: angle = 0
            case .n:  angle =  .pi / 2
            case .ne: angle =  .pi / 4
            case .e:  angle =  0
            case .se: angle = -.pi / 4
            case .s:  angle = -.pi / 2
            case .sw: angle = -.pi * 3 / 4
            case .w:  angle =  .pi
            case .nw: angle =  .pi * 3 / 4
            }
            let r = nr * halfW * 0.92
            sumX += center.x + r * cos(angle)
            sumY += center.y - r * sin(angle)
        }
        let n = Double(plots.count)
        return CGPoint(x: sumX / n, y: sumY / n)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Mock sessions

extension ShootingSession {

    static let mockSessions: [ShootingSession] = {
        let now = Date()
        func daysAgo(_ n: Int) -> Date { now.addingTimeInterval(-Double(n) * 86_400) }

        let (e1, a1) = mockEnds("ss1", cfg: "c5", rings: [
            [11,11,10,11,10,11], [11,10,11,11,10,11], [11,11,11,10,11,11],
            [10,11,11,10,11,10], [11,10,11,11,11,10], [10,11,10,11,11,11]
        ])
        let (e2, a2) = mockEnds("ss2", cfg: "c5", rings: [
            [9,10,8,10,9,9], [10,9,8,9,10,8], [9,8,10,9,8,9], [8,9,9,10,8,9]
        ])
        let (e3, a3) = mockEnds("ss3", cfg: "c4", rings: [
            [10,9,10,9,11,10], [9,10,9,10,9,10], [10,11,9,10,10,9], [9,10,11,10,9,10],
            [10,9,10,11,10,9], [11,10,9,10,11,10], [10,9,11,10,9,11], [9,10,10,11,10,9]
        ])
        let (e4, a4) = mockEnds("ss4", cfg: "c4", rings: [
            [11,10,11,11,10,11], [10,11,11,10,11,10], [11,11,10,11,10,11]
        ])
        let (e5, a5) = mockEnds("ss5", cfg: "c3", rings: [
            [9,8,9,8,9,8], [8,9,8,9,8,9], [9,8,9,8,9,8], [8,9,8,9,9,8], [9,8,8,9,8,9]
        ])
        let (e6, a6) = mockEnds("ss6", cfg: "c3", rings: [
            [10,9,10,10,9,10], [10,10,9,10,10,9], [11,10,10,9,10,10], [10,11,10,10,9,10],
            [10,10,11,10,10,9], [11,10,10,11,10,10], [10,11,10,10,11,10], [10,10,11,10,10,11],
            [11,10,10,11,10,11], [10,11,11,10,11,10]
        ])
        let (e7, a7) = mockEnds("ss7", cfg: "c2", rings: [
            [8,7,9,8,7,9], [7,8,8,7,9,8], [8,7,8,9,7,8], [9,8,7,8,8,7]
        ])
        let (e8, a8) = mockEnds("ss8", cfg: "c1", rings: [
            [9,10,9,8,10,9], [10,9,8,9,10,9], [9,8,10,9,9,10], [10,9,9,8,10,9],
            [9,10,8,9,9,10], [8,9,10,9,10,9]
        ])

        return [
            ShootingSession(id: "ss1", bowId: "b1", bowConfigId: "c5", arrowConfigId: "a1",
                startedAt: daysAgo(1), endedAt: daysAgo(1).addingTimeInterval(3_600),
                notes: "Best session yet. Felt really locked in at 20 yards.",
                feelTags: ["locked-in", "relaxed", "strong-back"],
                conditions: SessionConditions(windSpeed: 5, tempF: 68, lighting: "Sunny"),
                arrowCount: 36, ends: e1, arrows: a1),
            ShootingSession(id: "ss2", bowId: "b1", bowConfigId: "c5", arrowConfigId: "a1",
                startedAt: daysAgo(3), endedAt: daysAgo(3).addingTimeInterval(2_700),
                notes: "Working on form breakdown at distance.",
                feelTags: ["tense", "inconsistent-grip"],
                conditions: SessionConditions(windSpeed: 12, tempF: 62, lighting: "Overcast"),
                arrowCount: 24, ends: e2, arrows: a2),
            ShootingSession(id: "ss3", bowId: "b1", bowConfigId: "c4", arrowConfigId: "a1",
                startedAt: daysAgo(5), endedAt: daysAgo(5).addingTimeInterval(4_200),
                notes: "Tried adjusting nocking height mid-session.",
                feelTags: ["experimenting", "learning"],
                conditions: nil,
                arrowCount: 48, ends: e3, arrows: a3),
            ShootingSession(id: "ss4", bowId: "b1", bowConfigId: "c4", arrowConfigId: "a1",
                startedAt: daysAgo(8), endedAt: daysAgo(8).addingTimeInterval(3_000),
                notes: "Short practice. Focus on back tension.",
                feelTags: ["relaxed", "back-tension"],
                conditions: SessionConditions(windSpeed: 3, tempF: 72, lighting: "Sunny"),
                arrowCount: 18, ends: e4, arrows: a4),
            ShootingSession(id: "ss5", bowId: "b1", bowConfigId: "c3", arrowConfigId: "a1",
                startedAt: daysAgo(10), endedAt: daysAgo(10).addingTimeInterval(3_600),
                notes: "",
                feelTags: ["tired", "rushed"],
                conditions: nil,
                arrowCount: 30, ends: e5, arrows: a5),
            ShootingSession(id: "ss6", bowId: "b1", bowConfigId: "c3", arrowConfigId: "a1",
                startedAt: daysAgo(14), endedAt: daysAgo(14).addingTimeInterval(5_400),
                notes: "Paper tuning session. Got a clean bullet hole.",
                feelTags: ["focused", "technical"],
                conditions: SessionConditions(windSpeed: 0, tempF: 65, lighting: "Indoor"),
                arrowCount: 60, ends: e6, arrows: a6),
            ShootingSession(id: "ss7", bowId: "b1", bowConfigId: "c2", arrowConfigId: "a1",
                startedAt: daysAgo(18), endedAt: daysAgo(18).addingTimeInterval(2_400),
                notes: "Early morning. Cold fingers affected grip.",
                feelTags: ["cold", "stiff"],
                conditions: SessionConditions(windSpeed: 8, tempF: 42, lighting: "Dawn"),
                arrowCount: 24, ends: e7, arrows: a7),
            ShootingSession(id: "ss8", bowId: "b1", bowConfigId: "c1", arrowConfigId: "a1",
                startedAt: daysAgo(24), endedAt: daysAgo(24).addingTimeInterval(3_600),
                notes: "First session with this config. Getting baseline numbers.",
                feelTags: ["baseline", "learning"],
                conditions: SessionConditions(windSpeed: 6, tempF: 70, lighting: "Sunny"),
                arrowCount: 36, ends: e8, arrows: a8),
        ]
    }()

    // Generates SessionEnd + ArrowPlot arrays from a ring-per-arrow matrix.
    private static func mockEnds(
        _ sessionId: String,
        cfg: String,
        rings: [[Int]]
    ) -> ([SessionEnd], [ArrowPlot]) {
        var ends: [SessionEnd] = []
        var arrows: [ArrowPlot] = []
        let zones: [ArrowPlot.Zone] = [.center, .n, .ne, .e, .nw, .n]
        let outerZones: [ArrowPlot.Zone] = [.nw, .w, .sw, .n, .ne]

        for (endIdx, endRings) in rings.enumerated() {
            let endNum = endIdx + 1
            let endId = "\(sessionId)_e\(endNum)"
            ends.append(SessionEnd(
                id: endId, sessionId: sessionId, endNumber: endNum,
                notes: nil, completedAt: Date()
            ))
            for (i, ring) in endRings.enumerated() {
                let zone: ArrowPlot.Zone = ring >= 10
                    ? zones[i % zones.count]
                    : outerZones[i % outerZones.count]
                arrows.append(ArrowPlot(
                    id: "\(endId)_a\(i+1)", sessionId: sessionId,
                    bowConfigId: cfg, arrowConfigId: "a1",
                    ring: ring, zone: zone, endId: endId,
                    shotAt: Date(), excluded: false, notes: nil
                ))
            }
        }
        return (ends, arrows)
    }
}

// MARK: - Previews

#Preview("With sessions") {
    NavigationStack {
        HistoricalSessionsView(
            sessions: ShootingSession.mockSessions,
            bowName: "Hoyt RX7"
        )
    }
}

#Preview("Empty") {
    NavigationStack {
        HistoricalSessionsView(sessions: [], bowName: "Hoyt RX7")
    }
}
