import SwiftUI

// MARK: - HistoricalSessionsView

struct HistoricalSessionsView: View {
    let sessions: [ShootingSession]
    let bowName: String

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
            SessionDetailSheet(session: session)
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

            // Notes preview
            if !session.notes.isEmpty {
                Text(session.notes)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Time") {
                    DetailRow(label: "Started", value: session.startedAt.formatted(date: .complete, time: .shortened))
                    if let ended = session.endedAt {
                        DetailRow(label: "Ended", value: ended.formatted(date: .complete, time: .shortened))
                        DetailRow(label: "Duration", value: durationString(from: session.startedAt, to: ended))
                    }
                }

                Section("Performance") {
                    DetailRow(label: "Arrows", value: "\(session.arrowCount)")
                }

                if !session.feelTags.isEmpty {
                    Section("Feel Tags") {
                        WrappingTagRow(tags: session.feelTags, maxVisible: 20)
                            .padding(.vertical, 4)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }

                if !session.notes.isEmpty {
                    Section("Notes") {
                        Text(session.notes)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }

                if let conditions = session.conditions {
                    Section("Conditions") {
                        if let temp = conditions.tempF {
                            DetailRow(label: "Temperature", value: "\(Int(temp))°F")
                        }
                        if let wind = conditions.windSpeed {
                            DetailRow(
                                label: "Wind",
                                value: "\(Int(wind)) mph"
                            )
                        }
                        if let lighting = conditions.lighting {
                            DetailRow(label: "Lighting", value: lighting)
                        }
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
        if hours > 0 {
            return "\(hours)h \(mins % 60)m"
        }
        return "\(mins)m"
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

        return [
            ShootingSession(
                id: "ss1", bowId: "b1", bowConfigId: "c5", arrowConfigId: "a1",
                startedAt: daysAgo(1),
                endedAt: daysAgo(1).addingTimeInterval(3_600),
                notes: "Best session yet. Felt really locked in at 20 yards.",
                feelTags: ["locked-in", "relaxed", "strong-back"],
                conditions: SessionConditions(windSpeed: 5, tempF: 68, lighting: "Sunny"),
                arrowCount: 36
            ),
            ShootingSession(
                id: "ss2", bowId: "b1", bowConfigId: "c5", arrowConfigId: "a1",
                startedAt: daysAgo(3),
                endedAt: daysAgo(3).addingTimeInterval(2_700),
                notes: "Working on form breakdown at distance.",
                feelTags: ["tense", "inconsistent-grip"],
                conditions: SessionConditions(windSpeed: 12, tempF: 62, lighting: "Overcast"),
                arrowCount: 24
            ),
            ShootingSession(
                id: "ss3", bowId: "b1", bowConfigId: "c4", arrowConfigId: "a1",
                startedAt: daysAgo(5),
                endedAt: daysAgo(5).addingTimeInterval(4_200),
                notes: "Tried adjusting nocking height mid-session.",
                feelTags: ["experimenting", "learning"],
                conditions: nil,
                arrowCount: 48
            ),
            ShootingSession(
                id: "ss4", bowId: "b1", bowConfigId: "c4", arrowConfigId: "a1",
                startedAt: daysAgo(8),
                endedAt: daysAgo(8).addingTimeInterval(3_000),
                notes: "Short practice. Focus on back tension.",
                feelTags: ["relaxed", "back-tension"],
                conditions: SessionConditions(windSpeed: 3, tempF: 72, lighting: "Sunny"),
                arrowCount: 18
            ),
            ShootingSession(
                id: "ss5", bowId: "b1", bowConfigId: "c3", arrowConfigId: "a1",
                startedAt: daysAgo(10),
                endedAt: daysAgo(10).addingTimeInterval(3_600),
                notes: "",
                feelTags: ["tired", "rushed"],
                conditions: nil,
                arrowCount: 30
            ),
            ShootingSession(
                id: "ss6", bowId: "b1", bowConfigId: "c3", arrowConfigId: "a1",
                startedAt: daysAgo(14),
                endedAt: daysAgo(14).addingTimeInterval(5_400),
                notes: "Paper tuning session. Got a clean bullet hole.",
                feelTags: ["focused", "technical"],
                conditions: SessionConditions(windSpeed: 0, tempF: 65, lighting: "Indoor"),
                arrowCount: 60
            ),
            ShootingSession(
                id: "ss7", bowId: "b1", bowConfigId: "c2", arrowConfigId: "a1",
                startedAt: daysAgo(18),
                endedAt: daysAgo(18).addingTimeInterval(2_400),
                notes: "Early morning. Cold fingers affected grip.",
                feelTags: ["cold", "stiff"],
                conditions: SessionConditions(windSpeed: 8, tempF: 42, lighting: "Dawn"),
                arrowCount: 24
            ),
            ShootingSession(
                id: "ss8", bowId: "b1", bowConfigId: "c1", arrowConfigId: "a1",
                startedAt: daysAgo(24),
                endedAt: daysAgo(24).addingTimeInterval(3_600),
                notes: "First session with this config. Getting baseline numbers.",
                feelTags: ["baseline", "learning"],
                conditions: SessionConditions(windSpeed: 6, tempF: 70, lighting: "Sunny"),
                arrowCount: 36
            ),
        ]
    }()
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
