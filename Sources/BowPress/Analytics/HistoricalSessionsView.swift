import SwiftUI

// MARK: - HistoricalSessionsView

struct HistoricalSessionsView: View {
    let sessions: [ShootingSession]
    let bowName: String
    var allConfigs: [BowConfiguration] = []

    @Environment(AppState.self) private var appState
    @Environment(LocalStore.self) private var store: LocalStore?
    @State private var pendingDeleteSession: ShootingSession?
    @State private var errorMessage: String?
    @State private var filtersSheetPresented = false
    /// sessionId → plots, lazily hydrated once on appearance. `LocalStore.fetchSessions()`
    /// intentionally skips populating `session.arrows` (it would be O(n²) on the wire);
    /// SessionLogRow's per-arrow bar strip and avg calculations need those plots, so
    /// we bulk-fetch here and pass them down.
    @State private var plotsBySession: [String: [ArrowPlot]] = [:]

    // MARK: - Computed properties

    private var sortedSessions: [ShootingSession] {
        sessions.sorted { $0.startedAt > $1.startedAt }
    }

    private var totalArrows: Int {
        sessions.reduce(0) { $0 + $1.arrowCount }
    }

    private var earliestSessionDate: Date? {
        sessions.map(\.startedAt).min()
    }

    private var sinceDateString: String {
        guard let earliest = earliestSessionDate else { return "—" }
        let cal = Calendar.current
        let year = cal.component(.year, from: earliest)
        let month = cal.component(.month, from: earliest)
        return String(format: "%d · %02d", year, month)
    }

    // Group sessions into buckets: "This week", "Last week", then monthly
    private var groupedSessions: [(header: String, bucket: GroupBucket, sessions: [ShootingSession])] {
        let sorted = sortedSessions
        let dict = Dictionary(grouping: sorted) { weekBucket(for: $0.startedAt) }
        let bucketOrder = sorted.map { weekBucket(for: $0.startedAt) }
            .reduce(into: [String]()) { result, bucket in
                if !result.contains(bucket) { result.append(bucket) }
            }
        return bucketOrder.compactMap { bucket in
            guard let items = dict[bucket] else { return nil }
            let bkt = groupBucket(for: bucket)
            return (header: bucket, bucket: bkt, sessions: items)
        }
    }

    // All sessions sorted oldest-first for historical avg comparison
    private var historicalSortedByDate: [ShootingSession] {
        sessions.sorted { $0.startedAt < $1.startedAt }
    }

    private var historicalBestAvg: Double {
        sessions.map { sessionAvg($0) }.max() ?? 0
    }

    var body: some View {
        Group {
            if sessions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        headerView
                        filterSummaryView
                        sessionGroups
                    }
                }
                .background(Color.appPaper)
            }
        }
        .background(Color.appPaper)
        .alert(
            "Delete session?",
            isPresented: Binding(
                get: { pendingDeleteSession != nil },
                set: { if !$0 { pendingDeleteSession = nil } }
            ),
            presenting: pendingDeleteSession
        ) { session in
            Button("Cancel", role: .cancel) { pendingDeleteSession = nil }
            Button("Delete", role: .destructive) {
                if let store {
                    if let err = deleteSessionEverywhere(session, appState: appState, store: store) {
                        errorMessage = err.localizedDescription
                    }
                }
                pendingDeleteSession = nil
            }
        } message: { _ in
            Text("This permanently removes this session and its arrows, ends, and analytics — locally and from the cloud. This cannot be undone.")
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task(id: appState.analyticsRefreshNonce) {
            // Hydrate plots keyed on sessionId. The refresh-nonce id makes this
            // task re-run after `MainTabView` finishes its `LocalHydration.
            // hydrateFromAPI` round-trip and bumps `analyticsRefreshNonce` — a
            // plain `.task { ... }` fired once on appearance lost the race with
            // hydration, leaving `plotsBySession` empty and every row reading
            // "— avg · 0% X · <bow>" forever. `fetchAllArrows()` is a single
            // read against the in-memory store, so re-running on each nonce
            // bump is cheap.
            guard let store else { return }
            if let all = try? store.fetchAllArrows() {
                plotsBySession = Dictionary(grouping: all, by: \.sessionId)
            }
        }
        // TODO: filter sheet — currently stub
        .sheet(isPresented: $filtersSheetPresented) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Filters")
                        .font(.bpDisplay(22, italic: true, weight: .medium))
                        .foregroundStyle(Color.appInk)
                        .padding()
                    Spacer()
                    // TODO: filter sheet full implementation
                    Text("Filter options coming soon")
                        .font(.bpUI(14))
                        .foregroundStyle(Color.appInk3)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                    Button("Done") { filtersSheetPresented = false }
                        .font(.bpUI(14, weight: .semibold))
                        .foregroundStyle(Color.appPondDk)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .background(Color.appPaper)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 12) {
                // Left: eyebrow + title
                VStack(alignment: .leading, spacing: 4) {
                    Text("BOWPRESS")
                        .font(.bpUI(10.5, weight: .semibold))
                        .tracking(10.5 * 0.32)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.appPondDk)
                    Text("Session log")
                        .font(.bpDisplay(30, italic: true, weight: .medium))
                        .foregroundStyle(Color.appInk)
                }
                Spacer(minLength: 8)
                // Right: mono count block
                VStack(alignment: .trailing, spacing: 2) {
                    monoCountLine(bold: "\(sessions.count)", rest: " sessions")
                    monoCountLine(bold: "\(totalArrows)", rest: " arrows")
                    Text("since \(sinceDateString)")
                        .font(.bpMono(10))
                        .foregroundStyle(Color.appInk3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Rectangle()
                .fill(Color.appLine)
                .frame(height: 1)
        }
        .background(Color.appPaper)
    }

    private func monoCountLine(bold: String, rest: String) -> some View {
        (Text(bold)
            .font(.bpMono(10, weight: .medium))
            .foregroundStyle(Color.appInk)
        + Text(rest)
            .font(.bpMono(10))
            .foregroundStyle(Color.appInk3))
    }

    // MARK: - Filter summary

    private var filterSummaryView: some View {
        BPFilterSummary(
            summary: "All bows · All distances · 1 Week",
            subtitle: "tap to change filters"
        ) {
            // TODO: filter sheet
            filtersSheetPresented = true
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    // MARK: - Session groups

    @ViewBuilder
    private var sessionGroups: some View {
        let groups = groupedSessions
        let insertMonthboxAfterIndex = monthboxInsertionIndex(in: groups)

        ForEach(Array(groups.enumerated()), id: \.element.header) { idx, group in
            // Insert monthbox before the first non-recent group
            if idx == insertMonthboxAfterIndex {
                monthboxView
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            }

            groupSection(group: group, allGroups: groups)
        }
    }

    private func groupSection(
        group: (header: String, bucket: GroupBucket, sessions: [ShootingSession]),
        allGroups: [(header: String, bucket: GroupBucket, sessions: [ShootingSession])]
    ) -> some View {
        let bestSession = bestSessionInGroup(group.sessions)
        let rangeLabel = groupRangeLabel(for: group)

        return VStack(alignment: .leading, spacing: 0) {
            // Group title row
            HStack(alignment: .center) {
                Text(group.header)
                    .font(.bpUI(9.5, weight: .semibold))
                    .tracking(9.5 * 0.24)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.appInk3)
                Spacer()
                Text(rangeLabel)
                    .font(.bpMono(10))
                    .tracking(10 * 0.04)
                    .foregroundStyle(Color.appInk3)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            // Hairline
            Rectangle()
                .fill(Color.appLine)
                .frame(height: 1)

            // Session rows
            ForEach(Array(group.sessions.enumerated()), id: \.element.id) { idx, session in
                let isBest = session.id == bestSession?.id
                let prevSession = previousSession(before: session, in: allGroups)
                let isLastInGroup = idx == group.sessions.count - 1

                NavigationLink {
                    SessionDetailSheet(session: session, allConfigs: allConfigs)
                } label: {
                    SessionLogRow(
                        session: session,
                        isBest: isBest,
                        previousAvg: prevSession.map { sessionAvg($0) },
                        isLastInGroup: isLastInGroup,
                        plots: plots(for: session),
                        bowName: bowName(for: session)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("session_row_\(session.id)")
                .contextMenu {
                    Button(role: .destructive) {
                        pendingDeleteSession = session
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Monthbox (April 2026 heatmap)

    private var monthboxView: some View {
        let now = Date()
        let cal = Calendar.current
        let currentMonth = cal.component(.month, from: now)
        let currentYear = cal.component(.year, from: now)

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"
        let monthLabel = monthFormatter.string(from: now)

        // Sessions this month
        let thisMonthSessions = sessions.filter { s in
            let m = cal.component(.month, from: s.startedAt)
            let y = cal.component(.year, from: s.startedAt)
            return m == currentMonth && y == currentYear
        }

        let monthCount = thisMonthSessions.count
        let monthAvg = thisMonthSessions.isEmpty ? 0.0 :
            thisMonthSessions.map { sessionAvg($0) }.reduce(0, +) / Double(thisMonthSessions.count)

        // Compute days in month and arrow counts per day
        let daysInMonth = cal.range(of: .day, in: .month, for: now)?.count ?? 30
        let arrowsByDay = arrowCountsByDay(for: now, sessions: sessions)
        let maxArrows = arrowsByDay.values.max() ?? 1
        let bestDayArrows = arrowsByDay.values.max() ?? 0

        // Range days = days in month from 1 to today
        let todayDay = cal.component(.day, from: now)

        return VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.appLine)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                // Title row
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(monthLabel)
                        .font(.bpDisplay(14, italic: true, weight: .medium))
                        .foregroundStyle(Color.appInk)
                    Text("· \(monthCount) sessions · avg \(String(format: "%.1f", monthAvg))")
                        .font(.bpMono(10.5))
                        .tracking(10.5 * 0.06)
                        .foregroundStyle(Color.appInk3)
                }

                // Sub row: range days / shot days
                HStack {
                    Text("range days")
                        .font(.bpUI(10.5))
                        .foregroundStyle(Color.appInk2)
                    Spacer()
                    Text("shot days")
                        .font(.bpUI(10.5))
                        .foregroundStyle(Color.appInk2)
                }

                // 30-cell heatmap grid
                let cellCount = 30
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: cellCount), spacing: 3) {
                    ForEach(1...cellCount, id: \.self) { dayNum in
                        let arrows = arrowsByDay[dayNum] ?? 0
                        let isBestDay = arrows > 0 && arrows == bestDayArrows && bestDayArrows > 0
                        let isInMonth = dayNum <= daysInMonth
                        let isInRange = dayNum <= todayDay

                        Rectangle()
                            .fill(isInMonth && isInRange ? heatmapColor(arrows: arrows, max: maxArrows) : Color.appLine2)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                isBestDay ?
                                Rectangle().strokeBorder(Color.appInk, lineWidth: 1.5)
                                : nil
                            )
                    }
                }

                // Legend
                HStack(spacing: 10) {
                    legendSwatch(color: Color.appLine2, label: "none")
                    legendSwatch(color: Color(red: 0.75, green: 0.83, blue: 0.74), label: "short")
                    legendSwatch(color: Color.appMoss, label: "full")
                    legendSwatch(color: Color.appPine, label: "peak")
                    Spacer()
                }
            }
            .padding(14)
            .background(Color.appPaper2)

            Rectangle()
                .fill(Color.appLine)
                .frame(height: 1)
        }
    }

    private func legendSwatch(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(label)
                .font(.bpUI(9))
                .tracking(9 * 0.04)
                .foregroundStyle(Color.appInk3)
        }
    }

    private func heatmapColor(arrows: Int, max: Int) -> Color {
        if arrows == 0 { return Color.appLine2 }
        let ratio = max > 0 ? Double(arrows) / Double(max) : 0
        if ratio < 0.33 { return Color(red: 0.75, green: 0.83, blue: 0.74) }
        if ratio < 0.66 { return Color.appMoss }
        return Color.appPine
    }

    private func arrowCountsByDay(for date: Date, sessions: [ShootingSession]) -> [Int: Int] {
        let cal = Calendar.current
        let month = cal.component(.month, from: date)
        let year = cal.component(.year, from: date)
        var counts: [Int: Int] = [:]
        for session in sessions {
            let sm = cal.component(.month, from: session.startedAt)
            let sy = cal.component(.year, from: session.startedAt)
            guard sm == month && sy == year else { continue }
            let day = cal.component(.day, from: session.startedAt)
            counts[day, default: 0] += session.arrowCount
        }
        return counts
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("No sessions yet")
                .font(.bpDisplay(22, italic: true, weight: .medium))
                .foregroundStyle(Color.appInk)
            Text("Log a session to see your history here.")
                .font(.bpUI(14))
                .foregroundStyle(Color.appInk3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Helpers

    enum GroupBucket {
        case thisWeek, lastWeek, monthly
    }

    private func weekBucket(for date: Date) -> String {
        let cal = Calendar.current
        let now = Date()
        if cal.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            return "This week"
        }
        let oneWeekAgo = cal.date(byAdding: .weekOfYear, value: -1, to: now)!
        if cal.isDate(date, equalTo: oneWeekAgo, toGranularity: .weekOfYear) {
            return "Last week"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func groupBucket(for header: String) -> GroupBucket {
        if header == "This week" { return .thisWeek }
        if header == "Last week" { return .lastWeek }
        return .monthly
    }

    private func groupRangeLabel(for group: (header: String, bucket: GroupBucket, sessions: [ShootingSession])) -> String {
        guard !group.sessions.isEmpty else { return "" }
        let sorted = group.sessions.sorted { $0.startedAt < $1.startedAt }
        let first = sorted.first!.startedAt
        let last = sorted.last!.startedAt
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let count = group.sessions.count
        if Calendar.current.isDate(first, inSameDayAs: last) {
            return "\(fmt.string(from: first).lowercased()) · \(count) session\(count == 1 ? "" : "s")"
        }
        return "\(fmt.string(from: first).lowercased()) — \(fmt.string(from: last).lowercased()) · \(count) session\(count == 1 ? "" : "s")"
    }

    private func monthboxInsertionIndex(
        in groups: [(header: String, bucket: GroupBucket, sessions: [ShootingSession])]
    ) -> Int? {
        // Insert the monthbox before the first monthly bucket
        for (idx, group) in groups.enumerated() {
            if group.bucket == .monthly { return idx }
        }
        return nil
    }

    private func sessionAvg(_ session: ShootingSession) -> Double {
        let source = plots(for: session)
        guard !source.isEmpty else { return 0 }
        return Double(source.reduce(0) { $0 + min($1.ring, 10) }) / Double(source.count)
    }

    /// Returns pre-fetched plots for this session, falling back to
    /// `session.arrows` for tests / mock DTOs that populate arrows inline.
    private func plots(for session: ShootingSession) -> [ArrowPlot] {
        if let hydrated = plotsBySession[session.id], !hydrated.isEmpty {
            return hydrated
        }
        return session.arrows ?? []
    }

    /// Resolves `session.bowId` to its user-facing name via `appState.bows`.
    /// Falls back to "bow" when the bow hasn't been loaded (e.g. snapshot tests
    /// without AppState seeded).
    private func bowName(for session: ShootingSession) -> String {
        appState.bows.first(where: { $0.id == session.bowId })?.name ?? "bow"
    }

    private func bestSessionInGroup(_ groupSessions: [ShootingSession]) -> ShootingSession? {
        guard !groupSessions.isEmpty else { return nil }
        if groupSessions.count == 1 {
            let single = groupSessions[0]
            let avg = sessionAvg(single)
            // Only mark best if it's also the historical best
            return avg >= historicalBestAvg - 0.001 ? single : nil
        }
        return groupSessions.max(by: { sessionAvg($0) < sessionAvg($1) })
    }

    private func previousSession(
        before session: ShootingSession,
        in allGroups: [(header: String, bucket: GroupBucket, sessions: [ShootingSession])]
    ) -> ShootingSession? {
        let allSorted = allGroups.flatMap(\.sessions).sorted { $0.startedAt > $1.startedAt }
        guard let idx = allSorted.firstIndex(where: { $0.id == session.id }), idx + 1 < allSorted.count else {
            return nil
        }
        return allSorted[idx + 1]
    }
}

// MARK: - SessionLogRow

private struct SessionLogRow: View {
    let session: ShootingSession
    let isBest: Bool
    let previousAvg: Double?
    let isLastInGroup: Bool
    /// Pre-fetched arrow plots for this session. `fetchSessions()` doesn't
    /// hydrate `session.arrows`, so the parent view loads plots from
    /// `LocalStore.fetchAllArrows()` and hands them in here. Falls back to
    /// `session.arrows` for call sites that still populate the DTO inline
    /// (e.g. `mockSessions` in snapshot tests).
    let plots: [ArrowPlot]
    /// Resolved bow name for this session's `bowId`. Passed down from the
    /// parent so snapshot tests that don't wire AppState still render.
    let bowName: String

    private var arrows: [ArrowPlot] {
        if !plots.isEmpty { return plots }
        return session.arrows ?? []
    }

    private var avgRing: Double {
        guard !arrows.isEmpty else { return 0 }
        return Double(arrows.reduce(0) { $0 + min($1.ring, 10) }) / Double(arrows.count)
    }

    private var xCount: Int { arrows.filter { $0.ring == 11 }.count }
    private var xPct: Int {
        guard !arrows.isEmpty else { return 0 }
        return Int(Double(xCount) / Double(arrows.count) * 100)
    }

    private var deltaVsPrev: Double {
        guard let prev = previousAvg, prev > 0 else { return 0 }
        return avgRing - prev
    }

    private var sessionTitle: String {
        if let dist = session.distance {
            return "Range · \(dist.label)"
        }
        return "Range"
    }

    private var distanceTag: String {
        var parts: [String] = []
        if let dist = session.distance { parts.append(dist.label) }
        parts.append("\(session.arrowCount) arrows")
        return "· " + parts.joined(separator: " · ")
    }

    private var dayNumber: String {
        let cal = Calendar.current
        let day = cal.component(.day, from: session.startedAt)
        return String(format: "%02d", day)
    }

    private var weekdayAbbr: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return fmt.string(from: session.startedAt).lowercased()
    }

    private var noteExcerpt: String? {
        guard !session.notes.isEmpty else { return nil }
        let firstSentence = session.notes
            .components(separatedBy: ". ").first?
            .components(separatedBy: "! ").first?
            .components(separatedBy: "? ").first ?? session.notes
        let trimmed = String(firstSentence.prefix(60))
        return trimmed.isEmpty ? nil : "\u{201C}\(trimmed)\u{201D}"
    }

    private var scoreString: String {
        avgRing > 0 ? String(format: "%.1f", avgRing) : "—"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Col 1: Day tile (38pt wide)
            VStack(alignment: .center, spacing: 3) {
                Text(dayNumber)
                    .font(.bpDisplay(22, italic: true, weight: .medium))
                    .foregroundStyle(isBest ? Color.appPine : Color.appPondDk)
                Text(weekdayAbbr)
                    .font(.bpUI(8.5, weight: .semibold))
                    .tracking(8.5 * 0.18)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.appInk3)
            }
            .frame(width: 38, alignment: .center)
            .padding(.top, 2)

            // Col 2: Main column
            VStack(alignment: .leading, spacing: 5) {
                // Title + best stamp
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(sessionTitle)
                        .font(.bpDisplay(15, italic: true, weight: .medium))
                        .foregroundStyle(Color.appInk)
                    Text(" \(distanceTag)")
                        .font(.bpMono(10))
                        .tracking(10 * 0.04)
                        .foregroundStyle(Color.appInk3)
                    if isBest {
                        Spacer(minLength: 6)
                        BPStamp("BEST", tone: .pine)
                    }
                }

                // Per-arrow bar strip
                ArrowBars(arrows: arrows, arrowCount: session.arrowCount)
                    .frame(height: 6)

                // Meta line
                metaLine

                // Note excerpt
                if let note = noteExcerpt {
                    Text(note)
                        .font(.bpDisplay(11.5, italic: true, weight: .regular))
                        .foregroundStyle(Color.appInk2)
                        .lineLimit(2)
                }
            }

            // Col 3: Right rail
            VStack(alignment: .trailing, spacing: 4) {
                BPBigScore(value: scoreString, size: 22)
                if isBest && previousAvg != nil {
                    bestDeltaChip
                } else {
                    BPDelta(value: deltaVsPrev)
                }
                Text("\u{203A}")
                    .font(.bpDisplay(14, italic: true, weight: .medium))
                    .foregroundStyle(Color.appPond)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Color.appPaper)
        .overlay(alignment: .bottom) {
            if !isLastInGroup {
                Rectangle()
                    .fill(Color.appLine2)
                    .frame(height: 1)
            }
        }
    }

    /// `<avg with maple dot> avg · <x%>% X · <bow name>` per spec
    /// (analytics-japanese.html line ~756 — `<b>10.7</b> avg · <b>78%</b> X`).
    /// When arrow plots haven't loaded yet (or the session has no plots),
    /// fall back to just the bow name rather than misleading with "0% X"
    /// or "— avg".
    private var metaLine: some View {
        metaLineText
    }

    /// Returns a concatenated `Text` so the integer / decimal / fractional
    /// portions of the avg can carry different foreground styles (the decimal
    /// point picks up `appMaple` to echo the hero BPBigScore treatment).
    private var metaLineText: Text {
        let bowSuffix = Text(bowNameForSession)
            .font(.bpMono(10))
            .foregroundStyle(Color.appInk3)
            .tracking(10 * 0.04)
        guard !arrows.isEmpty else {
            return bowSuffix
        }
        let avgStr = String(format: "%.1f", avgRing)
        let avgParts = avgStr.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let intNumeral = Text(avgParts[0])
            .font(.bpMono(10, weight: .medium))
            .foregroundStyle(Color.appInk2)
            .tracking(10 * 0.04)
        let decimalPiece: Text = {
            guard avgParts.count == 2 else { return Text("") }
            return Text(".")
                .font(.bpMono(10, weight: .medium))
                .foregroundStyle(Color.appMaple)
                + Text(avgParts[1])
                    .font(.bpMono(10, weight: .medium))
                    .foregroundStyle(Color.appInk2)
                    .tracking(10 * 0.04)
        }()
        return intNumeral
            + decimalPiece
            + Text(" avg · ")
                .font(.bpMono(10))
                .foregroundStyle(Color.appInk3)
                .tracking(10 * 0.04)
            + Text("\(xPct)%")
                .font(.bpMono(10, weight: .medium))
                .foregroundStyle(Color.appInk2)
                .tracking(10 * 0.04)
            + Text(" X · ")
                .font(.bpMono(10))
                .foregroundStyle(Color.appInk3)
                .tracking(10 * 0.04)
            + bowSuffix
    }

    private var bowNameForSession: String {
        bowName.isEmpty ? "bow" : bowName
    }

    private var bestDeltaChip: some View {
        let delta = previousAvg.map { avgRing - $0 } ?? 0
        let text = delta > 0 ? "best · +\(String(format: "%.1f", delta))" : "best"
        return Text(text)
            .font(.bpMono(10))
            .tracking(10 * 0.04)
            .foregroundStyle(Color.appPine)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.appPine.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

// MARK: - Arrow bars

private struct ArrowBars: View {
    let arrows: [ArrowPlot]
    let arrowCount: Int

    // NB: no GeometryReader here. `Rectangle` has zero intrinsic height, so
    // wrapping it in a GeometryReader collapsed the strip to 0pt — only the
    // row's underlying hairline was visible. The caller applies `.frame(height: 6)`
    // externally; `maxHeight: .infinity` on the Rectangles lets them fill it.
    var body: some View {
        HStack(spacing: 1) {
            if arrows.isEmpty {
                // Placeholder bars — arrows haven't loaded from the store yet.
                ForEach(0..<max(1, arrowCount), id: \.self) { _ in
                    Rectangle()
                        .fill(Color.appLine2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cornerRadius(1)
                }
            } else {
                ForEach(Array(arrows.enumerated()), id: \.element.id) { _, arrow in
                    Rectangle()
                        .fill(barColor(for: arrow.ring))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cornerRadius(1)
                }
            }
        }
    }

    private func barColor(for ring: Int) -> Color {
        switch ring {
        case 11: return Color.appPine     // X
        case 9, 10: return Color.appPondDk
        case 8: return Color.appPond
        case 6, 7: return Color.appPondLt
        default: return Color.appLine2
        }
    }
}

// MARK: - WrappingTagRow (preserved for session detail)

struct WrappingTagRow: View {
    let tags: [String]
    var maxVisible: Int = 4

    var body: some View {
        HStack(spacing: 5) {
            ForEach(tags.prefix(maxVisible), id: \.self) { tag in
                Text(tag)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.appAccent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.appAccent.opacity(0.12), in: Capsule())
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

    @Environment(AppState.self) private var appState
    @Environment(LocalStore.self) private var store: LocalStore?
    @State private var selectedEnd: SessionEnd?
    @State private var loadedArrows: [ArrowPlot] = []
    @State private var loadedEnds: [SessionEnd] = []
    @State private var visibleCount: Int = 0
    @State private var didInitScrub: Bool = false
    @State private var showEditSheet: Bool = false
    /// Latest edited copy so the detail view reflects saves without a re-fetch.
    @State private var liveSession: ShootingSession?

    private var displaySession: ShootingSession { liveSession ?? session }

    private var sessionEnds: [SessionEnd] {
        loadedEnds.isEmpty ? (session.ends ?? []) : loadedEnds
    }
    private var allArrows: [ArrowPlot] {
        loadedArrows.isEmpty ? (session.arrows ?? []) : loadedArrows
    }

    private var sortedArrows: [ArrowPlot] {
        allArrows.sorted { $0.shotAt < $1.shotAt }
    }

    /// Arrow counts at which each subsequent end begins (for slider tick marks).
    private var endBoundaries: [Int] {
        let sorted = sortedArrows
        var seen = Set<String>()
        var boundaries: [Int] = []
        for (idx, arrow) in sorted.enumerated() {
            guard let endId = arrow.endId else { continue }
            if !seen.contains(endId) {
                seen.insert(endId)
                if idx > 0 { boundaries.append(idx) }
            }
        }
        return boundaries
    }

    private var arrowIdToEndNumber: [String: Int] {
        var map: [String: Int] = [:]
        for end in sessionEnds {
            map[end.id] = end.endNumber
        }
        var result: [String: Int] = [:]
        for arrow in allArrows {
            if let endId = arrow.endId, let num = map[endId] {
                result[arrow.id] = num
            }
        }
        return result
    }

    private var currentScrubEndNumber: Int? {
        guard visibleCount > 0, visibleCount <= sortedArrows.count else { return nil }
        let last = sortedArrows[visibleCount - 1]
        return arrowIdToEndNumber[last.id]
    }

    private var isScrubbing: Bool {
        didInitScrub && visibleCount < allArrows.count
    }

    private var highlightArrowId: String? {
        guard isScrubbing, visibleCount > 0 else { return nil }
        return sortedArrows[visibleCount - 1].id
    }

    private var scrubbedArrows: [ArrowPlot] {
        Array(sortedArrows.prefix(max(0, visibleCount)))
    }

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
        List {
                // Shot distribution heatmap
                if !allArrows.isEmpty {
                    Section {
                        VStack(spacing: 8) {
                            SessionHeatMapView(
                                plots: allArrows,
                                endArrows: selectedEnd != nil ? displayedArrows : [],
                                scrubArrows: isScrubbing ? scrubbedArrows : nil,
                                highlightArrowId: highlightArrowId
                            )
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .padding(.horizontal, 24)
                            .animation(.easeInOut(duration: 0.25), value: selectedEnd?.id)
                            .animation(.easeInOut(duration: 0.15), value: visibleCount)

                            if allArrows.count > 1 {
                                ArrowProgressionSlider(
                                    totalArrows: allArrows.count,
                                    endBoundaries: endBoundaries,
                                    currentEnd: currentScrubEndNumber,
                                    endCount: sessionEnds.count,
                                    isDisabled: selectedEnd != nil,
                                    visibleCount: $visibleCount
                                )
                            }

                            if selectedEnd == nil && PrecisionStats.isEliteContext(allArrows) {
                                let statsPlots = isScrubbing ? scrubbedArrows : allArrows
                                let stats = PrecisionStats.compute(statsPlots)
                                PrecisionStatsRow(stats: stats)
                                    .padding(.horizontal, 24)
                                    .animation(.easeInOut(duration: 0.15), value: visibleCount)
                                PrecisionScatterView(plots: statsPlots, stats: stats)
                                    .frame(width: 180, height: 180)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 24)
                                    .padding(.top, 4)
                                    .animation(.easeInOut(duration: 0.15), value: visibleCount)
                            }

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

                // Performance summary (moved to below ends)
                Section("Performance") {
                    DetailRow(label: "Total Arrows", value: "\(session.arrowCount)")
                    if !allArrows.isEmpty {
                        let avgFmt = avgRing >= 9.8 ? "%.2f" : "%.1f"
                        DetailRow(label: "Avg Ring Score", value: String(format: avgFmt, avgRing))
                        if xCount > 0 {
                            DetailRow(label: "X Count", value: "\(xCount)")
                        }
                        DetailRow(label: "10+ Ring Rate", value: String(format: "%.0f%%",
                            Double(allArrows.filter { $0.ring >= 10 }.count) / Double(allArrows.count) * 100))
                        if let stats = PrecisionStats.compute(allArrows), PrecisionStats.isEliteContext(allArrows) {
                            DetailRow(label: "Avg from Center", value: String(format: "~%.1fmm", stats.meanDistMM))
                            DetailRow(label: "Group Spread σ", value: String(format: "±%.1fmm", stats.groupSigmaMM))
                        }
                    }
                }

                // Notes (editable via toolbar Edit button)
                if !displaySession.notes.isEmpty {
                    Section("Notes") {
                        Text(displaySession.notes)
                            .font(.body)
                            .padding(.vertical, 4)
                    }
                }

                // Feel tags
                if !displaySession.feelTags.isEmpty {
                    Section("Feel") {
                        WrappingTagRow(tags: displaySession.feelTags, maxVisible: 20)
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
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEditSheet = true }
                    .accessibilityIdentifier("edit_session_button")
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditSessionSheet(session: displaySession) { updated in
                liveSession = updated
                if let idx = appState.completedSessions.firstIndex(where: { $0.id == updated.id }) {
                    appState.completedSessions[idx] = updated
                }
            }
        }
        .task {
            guard let store else { return }
            if loadedArrows.isEmpty {
                loadedArrows = (try? store.fetchArrows(sessionId: session.id)) ?? []
            }
            if loadedEnds.isEmpty {
                loadedEnds = (try? store.fetchEnds(sessionId: session.id)) ?? []
            }
            if !didInitScrub && !allArrows.isEmpty {
                visibleCount = allArrows.count
                didInitScrub = true
            }
        }
        .onAppear {
            if !didInitScrub && !allArrows.isEmpty {
                visibleCount = allArrows.count
                didInitScrub = true
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

// MARK: - Precision math helpers (shared across heatmap, stats row, scatter view)

private struct PrecisionStats {
    let centroid: (x: Double, y: Double)
    let meanDistMM: Double
    let groupSigmaMM: Double

    static let mmPerNorm: Double = 20.0 / (119.0 / 735.0)  // ≈ 123.5 (WA 40cm indoor)

    static func compute(_ plots: [ArrowPlot]) -> PrecisionStats? {
        let pts = plots.compactMap { p -> (Double, Double)? in
            guard let x = p.plotX, let y = p.plotY else { return nil }
            return (x, y)
        }
        guard !pts.isEmpty else { return nil }
        let cx = pts.map(\.0).reduce(0, +) / Double(pts.count)
        let cy = pts.map(\.1).reduce(0, +) / Double(pts.count)
        let meanDist = sqrt(pts.map { $0.0 * $0.0 + $0.1 * $0.1 }.reduce(0, +) / Double(pts.count))
        let sigma = sqrt(pts.map { pow($0.0 - cx, 2) + pow($0.1 - cy, 2) }.reduce(0, +) / Double(pts.count))
        return PrecisionStats(
            centroid: (cx, cy),
            meanDistMM: meanDist * mmPerNorm,
            groupSigmaMM: sigma * mmPerNorm
        )
    }

    static func isEliteContext(_ plots: [ArrowPlot]) -> Bool {
        guard plots.count >= 3, plots.contains(where: { $0.plotX != nil }) else { return false }
        let xRate = Double(plots.filter { $0.ring == 11 }.count) / Double(plots.count)
        let avgScore = Double(plots.reduce(0) { $0 + $1.ring }) / Double(plots.count)
        return xRate >= 0.4 || avgScore >= 9.5
    }

    var directionArrow: String {
        let dist = hypot(centroid.x, centroid.y)
        guard dist >= 0.01 else { return "\u{2299}" }
        let adx = abs(centroid.x), ady = abs(centroid.y)
        if ady > adx * 2 { return centroid.y > 0 ? "\u{2191}" : "\u{2193}" }
        if adx > ady * 2 { return centroid.x > 0 ? "\u{2192}" : "\u{2190}" }
        return (centroid.y > 0 ? "\u{2191}" : "\u{2193}") + (centroid.x > 0 ? "\u{2192}" : "\u{2190}")
    }
}

// MARK: - SessionHeatMapView

private struct SessionHeatMapView: View {
    let plots: [ArrowPlot]
    var endArrows: [ArrowPlot] = []
    var scrubArrows: [ArrowPlot]? = nil
    var highlightArrowId: String? = nil

    private var renderPlots: [ArrowPlot] {
        scrubArrows ?? plots
    }

    private func centroidNorm() -> (x: Double, y: Double)? {
        guard !renderPlots.isEmpty else { return nil }
        if let s = PrecisionStats.compute(renderPlots) { return s.centroid }
        var sumX = 0.0, sumY = 0.0
        for plot in renderPlots {
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
            sumX += nr * cos(angle)
            sumY += nr * sin(angle)
        }
        let n = Double(renderPlots.count)
        return (x: sumX / n, y: sumY / n)
    }

    private func groupSpread() -> Double? {
        let pts = renderPlots.compactMap { p -> (Double, Double)? in
            guard let x = p.plotX, let y = p.plotY else { return nil }
            return (x, y)
        }
        guard !pts.isEmpty else { return nil }
        let cx = pts.map(\.0).reduce(0, +) / Double(pts.count)
        let cy = pts.map(\.1).reduce(0, +) / Double(pts.count)
        return sqrt(pts.map { pow($0.0 - cx, 2) + pow($0.1 - cy, 2) }.reduce(0, +) / Double(pts.count))
    }

    private var blurRadius: CGFloat {
        guard let spread = groupSpread() else { return 10 }
        if spread < 0.08 { return 5 }
        if spread < 0.18 { return 8 }
        return 12
    }

    var body: some View {
        Image("target_face")
            .resizable()
            .scaledToFit()
            .overlay {
                Canvas { context, size in
                    for (i, plot) in renderPlots.enumerated() {
                        let pt = blobPosition(for: plot, index: i, in: size)
                        let rect = CGRect(x: pt.x - 11, y: pt.y - 11, width: 22, height: 22)
                        context.fill(Path(ellipseIn: rect), with: .color(Color.appAccent.opacity(0.50)))
                    }
                }
                .drawingGroup()
                .blur(radius: blurRadius)
            }
            .overlay {
                Canvas { context, size in
                    let halfW = size.width / 2
                    guard let cn = centroidNorm() else { return }
                    let cs = normToScreen(cn, in: size)
                    if let spread = groupSpread() {
                        let spreadPx = CGFloat(spread * halfW)
                        let sr = CGRect(x: cs.x - spreadPx, y: cs.y - spreadPx, width: spreadPx * 2, height: spreadPx * 2)
                        context.stroke(Path(ellipseIn: sr), with: .color(Color.appAccent.opacity(0.45)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                    let r: CGFloat = 12, bw: CGFloat = 2.5
                    context.fill(Path(ellipseIn: CGRect(x: cs.x - r, y: cs.y - r, width: r * 2, height: r * 2)), with: .color(Color.appAccent))
                    context.stroke(Path(ellipseIn: CGRect(x: cs.x - r - bw, y: cs.y - r - bw, width: (r + bw) * 2, height: (r + bw) * 2)), with: .color(.white.opacity(0.9)), lineWidth: bw)
                }
            }
            .overlay {
                if !endArrows.isEmpty {
                    GeometryReader { geo in
                        let radius = min(geo.size.width, geo.size.height) / 2
                        let dotSize = max(CGFloat(5.0) * (radius * 2) / 160.0, 10)
                        ForEach(Array(endArrows.enumerated()), id: \.element.id) { idx, arrow in
                            EndArrowDot(number: idx + 1, ring: arrow.ring, size: dotSize)
                                .position(blobPosition(for: arrow, index: idx, in: geo.size))
                        }
                    }
                }
            }
            .overlay {
                if let scrub = scrubArrows, !scrub.isEmpty {
                    GeometryReader { geo in
                        let radius = min(geo.size.width, geo.size.height) / 2
                        let dotSize = max(CGFloat(5.0) * (radius * 2) / 160.0, 10)
                        ForEach(Array(scrub.enumerated()), id: \.element.id) { idx, arrow in
                            EndArrowDot(
                                number: idx + 1,
                                ring: arrow.ring,
                                size: dotSize,
                                highlighted: arrow.id == highlightArrowId
                            )
                            .position(blobPosition(for: arrow, index: idx, in: geo.size))
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            .clipShape(Circle())
    }

    private func normToScreen(_ norm: (x: Double, y: Double), in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2 + CGFloat(norm.x) * size.width / 2,
                y: size.height / 2 - CGFloat(norm.y) * size.height / 2)
    }

    private func blobPosition(for plot: ArrowPlot, index: Int, in size: CGSize) -> CGPoint {
        if let px = plot.plotX, let py = plot.plotY {
            return normToScreen((px, py), in: size)
        }
        return ringZonePosition(for: plot, index: index, in: size)
    }

    private func ringZonePosition(for plot: ArrowPlot, index: Int, in size: CGSize) -> CGPoint {
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
        case .center: baseAngle = Double(index % 6) * .pi / 3
        case .n:      baseAngle =  .pi / 2
        case .ne:     baseAngle =  .pi / 4
        case .e:      baseAngle =  0
        case .se:     baseAngle = -.pi / 4
        case .s:      baseAngle = -.pi / 2
        case .sw:     baseAngle = -.pi * 3 / 4
        case .w:      baseAngle =  .pi
        case .nw:     baseAngle =  .pi * 3 / 4
        }
        let jitter = Double(index % 5) * 0.12 - 0.24
        let r = nr * halfW * 0.92
        return CGPoint(x: center.x + r * cos(baseAngle + jitter),
                       y: center.y - r * sin(baseAngle + jitter))
    }
}

// MARK: - PrecisionStatsRow

private struct PrecisionStatsRow: View {
    let stats: PrecisionStats?

    var body: some View {
        HStack(spacing: 8) {
            if let stats {
                StatChip(label: "\(stats.directionArrow) \(String(format: "%.1f", stats.meanDistMM))mm from center")
                StatChip(label: "\u{00B1} \(String(format: "%.1f", stats.groupSigmaMM))mm group \u{03C3}")
            } else {
                StatChip(label: "\u{2014} mm from center")
                StatChip(label: "\u{00B1} \u{2014} mm group \u{03C3}")
            }
            Spacer()
        }
    }
}

private struct StatChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.appAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.appAccent.opacity(0.1), in: Capsule())
    }
}

// MARK: - PrecisionScatterView

private struct PrecisionScatterView: View {
    let plots: [ArrowPlot]
    let stats: PrecisionStats?

    private let zoomFactor: Double = 0.88 / (119.0 / 735.0)
    private let xNorm: Double = 60.0 / 735.0
    private let r10Norm: Double = 119.0 / 735.0

    private var realShots: [(ring: Int, x: Double, y: Double)] {
        plots.compactMap { p in
            guard let x = p.plotX, let y = p.plotY else { return nil }
            return (p.ring, x, y)
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Text("X \u{00B7} 10 Ring Detail")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Canvas { context, size in
                let halfW = size.width / 2
                let center = CGPoint(x: halfW, y: size.height / 2)
                let scale = CGFloat(zoomFactor) * halfW

                let r10px = CGFloat(r10Norm * zoomFactor) * halfW
                context.stroke(Path(ellipseIn: CGRect(x: center.x - r10px, y: center.y - r10px, width: r10px * 2, height: r10px * 2)), with: .color(.secondary.opacity(0.2)), lineWidth: 1)

                let xpx = CGFloat(xNorm * zoomFactor) * halfW
                context.stroke(Path(ellipseIn: CGRect(x: center.x - xpx, y: center.y - xpx, width: xpx * 2, height: xpx * 2)), with: .color(.primary.opacity(0.25)), lineWidth: 1.5)

                var axisPath = Path()
                let axisLen = r10px * 1.1
                axisPath.move(to: CGPoint(x: center.x, y: center.y - axisLen))
                axisPath.addLine(to: CGPoint(x: center.x, y: center.y + axisLen))
                axisPath.move(to: CGPoint(x: center.x - axisLen, y: center.y))
                axisPath.addLine(to: CGPoint(x: center.x + axisLen, y: center.y))
                context.stroke(axisPath, with: .color(.secondary.opacity(0.12)), lineWidth: 0.75)

                let labelOffset = axisLen + 10
                context.draw(Text("N").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.secondary), at: CGPoint(x: center.x, y: center.y - labelOffset))
                context.draw(Text("S").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.secondary), at: CGPoint(x: center.x, y: center.y + labelOffset))
                context.draw(Text("E").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.secondary), at: CGPoint(x: center.x + labelOffset, y: center.y))
                context.draw(Text("W").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.secondary), at: CGPoint(x: center.x - labelOffset, y: center.y))

                for shot in realShots {
                    let sx = center.x + CGFloat(shot.x) * scale
                    let sy = center.y - CGFloat(shot.y) * scale
                    let dotR: CGFloat = 5
                    let dotColor: Color
                    switch shot.ring {
                    case 11: dotColor = Color(red: 1.0, green: 0.85, blue: 0.0)
                    case 10: dotColor = Color(red: 1.0, green: 0.95, blue: 0.25)
                    case 9:  dotColor = .orange
                    default: dotColor = .red
                    }
                    context.fill(Path(ellipseIn: CGRect(x: sx - dotR, y: sy - dotR, width: dotR * 2, height: dotR * 2)), with: .color(dotColor.opacity(0.9)))
                    context.stroke(Path(ellipseIn: CGRect(x: sx - dotR, y: sy - dotR, width: dotR * 2, height: dotR * 2)), with: .color(.black.opacity(0.25)), lineWidth: 0.75)
                }

                if let stats {
                    let cx = center.x + CGFloat(stats.centroid.x) * scale
                    let cy = center.y - CGFloat(stats.centroid.y) * scale
                    let arm: CGFloat = 9
                    var cross = Path()
                    cross.move(to: CGPoint(x: cx - arm, y: cy))
                    cross.addLine(to: CGPoint(x: cx + arm, y: cy))
                    cross.move(to: CGPoint(x: cx, y: cy - arm))
                    cross.addLine(to: CGPoint(x: cx, y: cy + arm))
                    context.stroke(cross, with: .color(Color.appAccent), style: StrokeStyle(lineWidth: 2))
                    context.fill(Path(ellipseIn: CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6)), with: .color(Color.appAccent))
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .background(Color.appSurface)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.appBorder.opacity(0.5), lineWidth: 1))
        }
    }
}

// MARK: - EndArrowDot

private struct EndArrowDot: View {
    let number: Int
    let ring: Int
    let size: CGFloat
    var highlighted: Bool = false

    var body: some View {
        ZStack {
            if highlighted {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 2.5)
                    .frame(width: size + 8, height: size + 8)
                    .shadow(color: Color.appAccent.opacity(0.9), radius: 6)
            }
            Circle()
                .fill(dotColor)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            Text("\(number)")
                .font(.system(size: max(size * 0.42, 7), weight: .bold, design: .rounded))
                .foregroundStyle(ring >= 9 ? Color.black : Color.white)
        }
    }

    private var dotColor: Color {
        switch ring {
        case 11: return Color(red: 1.0,  green: 0.85, blue: 0.0)
        case 10, 9: return Color(red: 1.0, green: 0.95, blue: 0.2)
        case 8, 7: return Color(red: 0.88, green: 0.28, blue: 0.22)
        case 6: return Color(red: 0.0, green: 0.73, blue: 0.89)
        default: return .gray
        }
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
                arrowCount: 36, ends: e1, arrows: a1),
            ShootingSession(id: "ss2", bowId: "b1", bowConfigId: "c5", arrowConfigId: "a1",
                startedAt: daysAgo(3), endedAt: daysAgo(3).addingTimeInterval(2_700),
                notes: "Working on form breakdown at distance.",
                feelTags: ["tense", "inconsistent-grip"],
                arrowCount: 24, ends: e2, arrows: a2),
            ShootingSession(id: "ss3", bowId: "b1", bowConfigId: "c4", arrowConfigId: "a1",
                startedAt: daysAgo(5), endedAt: daysAgo(5).addingTimeInterval(4_200),
                notes: "Tried adjusting nocking height mid-session.",
                feelTags: ["experimenting", "learning"],
                arrowCount: 48, ends: e3, arrows: a3),
            ShootingSession(id: "ss4", bowId: "b1", bowConfigId: "c4", arrowConfigId: "a1",
                startedAt: daysAgo(8), endedAt: daysAgo(8).addingTimeInterval(3_000),
                notes: "Short practice. Focus on back tension.",
                feelTags: ["relaxed", "back-tension"],
                arrowCount: 18, ends: e4, arrows: a4),
            ShootingSession(id: "ss5", bowId: "b1", bowConfigId: "c3", arrowConfigId: "a1",
                startedAt: daysAgo(10), endedAt: daysAgo(10).addingTimeInterval(3_600),
                notes: "",
                feelTags: ["tired", "rushed"],
                arrowCount: 30, ends: e5, arrows: a5),
            ShootingSession(id: "ss6", bowId: "b1", bowConfigId: "c3", arrowConfigId: "a1",
                startedAt: daysAgo(14), endedAt: daysAgo(14).addingTimeInterval(5_400),
                notes: "Paper tuning session. Got a clean bullet hole.",
                feelTags: ["focused", "technical"],
                arrowCount: 60, ends: e6, arrows: a6),
            ShootingSession(id: "ss7", bowId: "b1", bowConfigId: "c2", arrowConfigId: "a1",
                startedAt: daysAgo(18), endedAt: daysAgo(18).addingTimeInterval(2_400),
                notes: "Early morning. Cold fingers affected grip.",
                feelTags: ["cold", "stiff"],
                arrowCount: 24, ends: e7, arrows: a7),
            ShootingSession(id: "ss8", bowId: "b1", bowConfigId: "c1", arrowConfigId: "a1",
                startedAt: daysAgo(24), endedAt: daysAgo(24).addingTimeInterval(3_600),
                notes: "First session with this config. Getting baseline numbers.",
                feelTags: ["baseline", "learning"],
                arrowCount: 36, ends: e8, arrows: a8),
        ]
    }()

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
    .environment(AppState())
}

#Preview("Empty") {
    NavigationStack {
        HistoricalSessionsView(sessions: [], bowName: "Hoyt RX7")
    }
    .environment(AppState())
}
