import Foundation

// ── DevMockData ──────────────────────────────────────────────────────────────
// DEPRECATED as a data seed source. Kept as reference for the shape of the
// fixtures DEBUG builds used to seed the in-memory SwiftData store with.
//
// DEBUG builds now fetch the same data from the Cloudflare API by auto-signing
// in as the e2e test user (see Services/DevAutoSignIn.swift + the hydration
// block in Navigation/MainTabView.swift). The server-side counterpart lives in
// bowpress-api/scripts/seed-e2e.ts.
//
// Remaining live uses are DEBUG-only: SwiftUI #Preview blocks (Analytics/…)
// and AppState.unreadSuggestionCount's initial value. If you're tempted to
// call DevMockData from new code, prefer pulling from the API + LocalStore.
// Do not delete this file without also updating the preview + AppState sites.

#if DEBUG

// MARK: - DevMockData

enum DevMockData {

    private static func daysAgo(_ n: Int) -> Date {
        Date().addingTimeInterval(-86_400 * Double(n))
    }

    // MARK: - Bows

    static let bow1 = Bow(
        id: "dev_bow1",
        userId: "dev",
        name: "Mathews TITLE 36",
        bowType: .compound,
        brand: "Mathews",
        model: "TITLE 36",
        createdAt: daysAgo(45)
    )

    static let bow2 = Bow(
        id: "dev_bow2",
        userId: "dev",
        name: "Hoyt Satori",
        bowType: .recurve,
        brand: "Hoyt",
        model: "Satori",
        createdAt: daysAgo(60)
    )

    /// Third bow exists so the analytics bow-style chip row renders all three
    /// styles. No sessions attached yet — clicking the Barebow chip will show
    /// the empty state, which is the correct behavior.
    static let bow3 = Bow(
        id: "dev_bow3",
        userId: "dev",
        name: "Border HEX7 Barebow",
        bowType: .barebow,
        brand: "Border",
        model: "HEX7",
        createdAt: daysAgo(20)
    )

    static let bows: [Bow] = [bow1, bow2, bow3]

    // MARK: - Arrow Configurations

    static let arrow1 = ArrowConfiguration(
        id: "dev_arrow1",
        userId: "dev",
        label: "Competition X10s",
        brand: "Easton",
        model: "X10",
        length: 28.5,
        pointWeight: 110,
        fletchingType: .vane,
        fletchingLength: 2.0,
        fletchingOffset: 1.5,
        nockType: "pin",
        totalWeight: 420,
        notes: nil
    )

    static let arrow2 = ArrowConfiguration(
        id: "dev_arrow2",
        userId: "dev",
        label: "Practice Platinums",
        brand: "Gold Tip",
        model: "Platinum",
        length: 29.0,
        pointWeight: 100,
        fletchingType: .vane,
        fletchingLength: 2.25,
        fletchingOffset: 2.0,
        nockType: nil,
        totalWeight: nil,
        notes: nil
    )

    static let arrowConfigs: [ArrowConfiguration] = [arrow1, arrow2]

    // MARK: - Bow Configurations

    static let bc1a = BowConfiguration(
        id: "dev_bc1a",
        bowId: "dev_bow1",
        createdAt: daysAgo(40),
        label: "Out of the Box",
        drawLength: 28.5,
        letOffPct: 80,
        peepHeight: 9.0,
        dLoopLength: 2.0,
        topCableTwists: 0,
        bottomCableTwists: 0,
        mainStringTopTwists: 0,
        mainStringBottomTwists: 0,
        topLimbTurns: 0,
        bottomLimbTurns: 0,
        restVertical: 0,
        restHorizontal: 0,
        restDepth: 0,
        sightPosition: 0,
        gripAngle: 45,
        nockingHeight: 0,
        frontStabWeight: 12,
        frontStabAngle: 0,
        rearStabSide: RearStabSide.none,
        rearStabWeight: 0,
        rearStabVertAngle: 0,
        rearStabHorizAngle: 0
    )

    static let bc1b = BowConfiguration(
        id: "dev_bc1b",
        bowId: "dev_bow1",
        createdAt: daysAgo(25),
        label: "Rest & Nocking Tune",
        drawLength: 28.5,
        letOffPct: 80,
        peepHeight: 9.25,
        dLoopLength: 2.0,
        topCableTwists: 2,
        bottomCableTwists: 2,
        mainStringTopTwists: 0,
        mainStringBottomTwists: 0,
        topLimbTurns: 0,
        bottomLimbTurns: 0,
        restVertical: 1,
        restHorizontal: -1,
        restDepth: 0.25,
        sightPosition: 1,
        gripAngle: 45,
        nockingHeight: 2,
        frontStabWeight: 12,
        frontStabAngle: 5,
        rearStabSide: .left,
        rearStabWeight: 8,
        rearStabVertAngle: -45,
        rearStabHorizAngle: 45
    )

    static let bc1c = BowConfiguration(
        id: "dev_bc1c",
        bowId: "dev_bow1",
        createdAt: daysAgo(10),
        label: "Competition Setup",
        drawLength: 28.5,
        letOffPct: 80,
        peepHeight: 9.25,
        dLoopLength: 2.125,
        topCableTwists: 3,
        bottomCableTwists: 3,
        mainStringTopTwists: 2,
        mainStringBottomTwists: 1,
        topLimbTurns: -0.5,
        bottomLimbTurns: -0.5,
        restVertical: 2,
        restHorizontal: -1,
        restDepth: 0.25,
        sightPosition: 2,
        gripAngle: 45,
        nockingHeight: 3,
        frontStabWeight: 14,
        frontStabAngle: 5,
        rearStabSide: .left,
        rearStabWeight: 10,
        rearStabVertAngle: -45,
        rearStabHorizAngle: 45
    )

    static let bc2a = BowConfiguration(
        id: "dev_bc2a",
        bowId: "dev_bow2",
        createdAt: daysAgo(55),
        label: "Initial Draw Set",
        drawLength: 29.0,
        letOffPct: 85,
        peepHeight: 9.5,
        dLoopLength: 2.0,
        topCableTwists: 0,
        bottomCableTwists: 0,
        mainStringTopTwists: 0,
        mainStringBottomTwists: 0,
        topLimbTurns: 0,
        bottomLimbTurns: 0,
        restVertical: 0,
        restHorizontal: 0,
        restDepth: 0,
        sightPosition: 0,
        gripAngle: 40,
        nockingHeight: 0,
        frontStabWeight: 10,
        frontStabAngle: 0,
        rearStabSide: RearStabSide.none,
        rearStabWeight: 0,
        rearStabVertAngle: 0,
        rearStabHorizAngle: 0
    )

    static let bc2b = BowConfiguration(
        id: "dev_bc2b",
        bowId: "dev_bow2",
        createdAt: daysAgo(30),
        label: "Full Tune",
        drawLength: 29.0,
        letOffPct: 85,
        peepHeight: 9.5,
        dLoopLength: 2.0,
        topCableTwists: 4,
        bottomCableTwists: 4,
        mainStringTopTwists: 3,
        mainStringBottomTwists: 3,
        topLimbTurns: -1.0,
        bottomLimbTurns: -1.0,
        restVertical: 2,
        restHorizontal: 0,
        restDepth: 0.5,
        sightPosition: -1,
        gripAngle: 40,
        nockingHeight: 1,
        frontStabWeight: 12,
        frontStabAngle: 5,
        rearStabSide: .right,
        rearStabWeight: 8,
        rearStabVertAngle: -30,
        rearStabHorizAngle: 45
    )

    static func bowConfigs(for bowId: String) -> [BowConfiguration] {
        switch bowId {
        case "dev_bow1": return [bc1a, bc1b, bc1c]
        case "dev_bow2": return [bc2a, bc2b]
        default: return []
        }
    }

    // MARK: - Sessions

    // Distance distribution is spread across the most-recent sessions so every
    // chip shows real data at the default 3-day period:
    //   • s1_1, s1_2: nil (oldest — before the user started tracking distance)
    //   • s1_3, s1_5: 20yd (indoor practice)  — incl. one within 3 days
    //   • s1_6, s1_8: 50m (outdoor compound)  — incl. one within 3 days
    //   • s1_4, s1_7: 70m (outdoor compound)  — incl. one within 3 days
    // Plus bow2's recurve sessions (most at 70m) and the recurve session that's
    // also been pulled inside the 3-day window so the Recurve chip has data.
    private static let bow1Sessions: [ShootingSession] = [
        ShootingSession(
            id: "dev_s1_1",
            bowId: "dev_bow1",
            bowConfigId: "dev_bc1a",
            arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(35),
            endedAt: daysAgo(35).addingTimeInterval(4_500),
            notes: "First range session with the new bow. Still finding anchor, groups were wide.",
            feelTags: ["anchor_drift", "rushed"],
            arrowCount: 12,
            title: "First range"
        ),
        ShootingSession(
            id: "dev_s1_2",
            bowId: "dev_bow1",
            bowConfigId: "dev_bc1a",
            arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(32),
            endedAt: daysAgo(32).addingTimeInterval(5_400),
            notes: "Worked on back tension. Some improvement but still inconsistent peep alignment.",
            feelTags: ["back_tension", "peep_alignment"],
            arrowCount: 15,
            title: "Back tension drill"
        ),
        ShootingSession(
            id: "dev_s1_3",
            bowId: "dev_bow1",
            bowConfigId: "dev_bc1a",
            arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(29),
            endedAt: daysAgo(29).addingTimeInterval(5_100),
            notes: "Groups tightening slightly. Wind made it hard to judge impact consistently.",
            feelTags: ["wind_affected", "back_tension"],
            arrowCount: 14,
            distance: .twentyYards,
            title: "Windy afternoon"
        ),
        ShootingSession(
            id: "dev_s1_4",
            bowId: "dev_bow1",
            bowConfigId: "dev_bc1b",
            arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(23),
            endedAt: daysAgo(23).addingTimeInterval(4_800),
            notes: "New rest position making a clear difference. Cleaner breaks off the wall.",
            feelTags: ["clean_release", "consistent"],
            arrowCount: 16,
            distance: .twentyYards,
            title: "Rest tune check"
        ),
        ShootingSession(
            id: "dev_s1_5",
            bowId: "dev_bow1",
            bowConfigId: "dev_bc1b",
            arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(18),
            endedAt: daysAgo(18).addingTimeInterval(3_600),
            notes: "Short session due to fatigue. Still, groups are noticeably tighter than first week.",
            feelTags: ["fatigue", "consistent"],
            arrowCount: 12,
            distance: .fiftyMeters,
            title: "Short session"
        ),
        // The most-recent three sessions are spread across all three distances
        // and all sit inside the default 3-day analytics window so each
        // distance chip surfaces real data without changing the period selector.
        ShootingSession(
            id: "dev_s1_6",
            bowId: "dev_bow1",
            bowConfigId: "dev_bc1c",
            arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(2),
            endedAt: daysAgo(2).addingTimeInterval(5_400),
            notes: "Indoor 20yd practice — clean groups, tested new D-loop length.",
            feelTags: ["consistent", "clean_release"],
            arrowCount: 18,
            distance: .twentyYards,
            title: "Indoor practice"
        ),
        ShootingSession(
            id: "dev_s1_7",
            bowId: "dev_bow1",
            bowConfigId: "dev_bc1c",
            arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(1),
            endedAt: daysAgo(1).addingTimeInterval(5_700),
            notes: "Long-distance work at 70m. Back tension fully engaged, impact pattern very tight.",
            feelTags: ["back_tension", "clean_release", "consistent"],
            arrowCount: 18,
            distance: .seventyMeters,
            title: "Long-distance work"
        ),
        ShootingSession(
            id: "dev_s1_8",
            bowId: "dev_bow1",
            bowConfigId: "dev_bc1c",
            arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(0),
            endedAt: daysAgo(0).addingTimeInterval(5_400),
            notes: "Pre-comp tune check at 50m. Groups holding well. Minor sight drift to correct.",
            feelTags: ["consistent", "clean_release"],
            arrowCount: 18,
            distance: .fiftyMeters,
            title: "Pre-comp tune check"
        ),
    ]

    private static let bow2Sessions: [ShootingSession] = [
        ShootingSession(
            id: "dev_s2_1",
            bowId: "dev_bow2",
            bowConfigId: "dev_bc2a",
            arrowConfigId: "dev_arrow2",
            startedAt: daysAgo(34),
            endedAt: daysAgo(34).addingTimeInterval(4_200),
            notes: "Initial setup session. Getting used to the longer draw on the Hoyt.",
            feelTags: ["anchor_drift", "rushed"],
            arrowCount: 12,
            distance: .seventyMeters,
            title: "Hoyt opener"
        ),
        ShootingSession(
            id: "dev_s2_2",
            bowId: "dev_bow2",
            bowConfigId: "dev_bc2a",
            arrowConfigId: "dev_arrow2",
            startedAt: daysAgo(31),
            endedAt: daysAgo(31).addingTimeInterval(4_500),
            notes: "More comfortable with the draw cycle. Groups still wide but more intentional.",
            feelTags: ["peep_alignment", "back_tension"],
            arrowCount: 13,
            distance: .seventyMeters,
            title: "Finding the draw"
        ),
        ShootingSession(
            id: "dev_s2_3",
            bowId: "dev_bow2",
            bowConfigId: "dev_bc2b",
            arrowConfigId: "dev_arrow2",
            startedAt: daysAgo(27),
            endedAt: daysAgo(27).addingTimeInterval(5_100),
            notes: "Full tune applied. Huge difference in arrow flight stability off the rest.",
            feelTags: ["consistent", "clean_release"],
            arrowCount: 14,
            distance: .seventyMeters,
            title: "Tune applied"
        ),
        ShootingSession(
            id: "dev_s2_4",
            bowId: "dev_bow2",
            bowConfigId: "dev_bc2b",
            arrowConfigId: "dev_arrow2",
            startedAt: daysAgo(20),
            endedAt: daysAgo(20).addingTimeInterval(5_400),
            notes: "Focused on windage. Groups printing slightly left — adjustments logged.",
            feelTags: ["consistent", "peep_alignment"],
            arrowCount: 15,
            distance: .seventyMeters,
            title: "Windage chase"
        ),
        ShootingSession(
            id: "dev_s2_5",
            bowId: "dev_bow2",
            bowConfigId: "dev_bc2b",
            arrowConfigId: "dev_arrow2",
            startedAt: daysAgo(12),
            endedAt: daysAgo(12).addingTimeInterval(5_700),
            notes: "Strong session. Back tension and release timing syncing up well.",
            feelTags: ["back_tension", "clean_release", "consistent"],
            arrowCount: 15,
            distance: .seventyMeters,
            title: "Strong session"
        ),
        ShootingSession(
            id: "dev_s2_6",
            bowId: "dev_bow2",
            bowConfigId: "dev_bc2b",
            arrowConfigId: "dev_arrow2",
            startedAt: daysAgo(6),
            endedAt: daysAgo(6).addingTimeInterval(5_400),
            notes: "Late evening session, slightly fatigued but managed consistent groups.",
            feelTags: ["fatigue", "consistent"],
            arrowCount: 14,
            distance: .seventyMeters,
            title: "Evening range"
        ),
    ]

    static func sessions(for bowId: String) -> [ShootingSession] {
        switch bowId {
        case "dev_bow1": return bow1Sessions
        case "dev_bow2": return bow2Sessions
        default: return []
        }
    }

    // MARK: - Arrow Plots

    private static func makePlots(
        sessionId: String, bowConfigId: String, arrowConfigId: String,
        startedAt: Date, count: Int,
        rings: [Int], zones: [ArrowPlot.Zone],
        plotX: [Double] = [], plotY: [Double] = []
    ) -> [ArrowPlot] {
        (0..<count).map { i in
            ArrowPlot(
                id: "\(sessionId)_p\(i + 1)",
                sessionId: sessionId,
                bowConfigId: bowConfigId,
                arrowConfigId: arrowConfigId,
                ring: rings[i % rings.count],
                zone: zones[i % zones.count],
                plotX: i < plotX.count ? plotX[i] : nil,
                plotY: i < plotY.count ? plotY[i] : nil,
                shotAt: startedAt.addingTimeInterval(Double(i) * 240),
                excluded: false,
                notes: nil
            )
        }
    }

    private static let allArrowPlots: [ArrowPlot] = {
        var plots: [ArrowPlot] = []

        // dev_s1_1 — early, wide groups, 8s/9s, spread zones
        plots += makePlots(
            sessionId: "dev_s1_1", bowConfigId: "dev_bc1a", arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(35), count: 12,
            rings: [8, 8, 9, 8, 9, 8, 9, 8, 8, 9, 8, 9],
            zones: [.nw, .n, .ne, .w, .e, .nw, .n, .w, .ne, .nw, .e, .n]
        )

        // dev_s1_2 — still early, 8s/9s, spread
        plots += makePlots(
            sessionId: "dev_s1_2", bowConfigId: "dev_bc1a", arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(32), count: 15,
            rings: [8, 9, 8, 9, 9, 8, 9, 8, 9, 9, 8, 9, 8, 9, 8],
            zones: [.n, .nw, .w, .ne, .n, .w, .nw, .e, .n, .ne, .nw, .n, .w, .ne, .n]
        )

        // dev_s1_3 — late bc1a, some 10s creeping in
        plots += makePlots(
            sessionId: "dev_s1_3", bowConfigId: "dev_bc1a", arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(29), count: 14,
            rings: [8, 9, 9, 10, 9, 8, 9, 10, 9, 9, 8, 9, 10, 9],
            zones: [.nw, .n, .ne, .n, .w, .nw, .n, .ne, .n, .nw, .e, .n, .ne, .n]
        )

        // dev_s1_4 — bc1b, more 9s/10s, tighter
        plots += makePlots(
            sessionId: "dev_s1_4", bowConfigId: "dev_bc1b", arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(23), count: 16,
            rings: [9, 10, 9, 10, 10, 9, 10, 9, 10, 10, 9, 10, 9, 10, 9, 10],
            zones: [.n, .ne, .n, .center, .n, .ne, .n, .center, .ne, .n, .ne, .center, .n, .ne, .n, .center]
        )

        // dev_s1_5 — bc1b, 9s/10s
        plots += makePlots(
            sessionId: "dev_s1_5", bowConfigId: "dev_bc1b", arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(18), count: 12,
            rings: [9, 10, 10, 9, 10, 9, 10, 10, 9, 10, 9, 10],
            zones: [.ne, .n, .center, .ne, .center, .n, .ne, .center, .n, .center, .ne, .n]
        )

        // dev_s1_6 — bc1c, 20yd indoor, 10s/11s, mostly center/n, NE bias developing
        plots += makePlots(
            sessionId: "dev_s1_6", bowConfigId: "dev_bc1c", arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(2), count: 18,
            rings: [10, 11, 10, 11, 10, 11, 10, 10, 11, 10, 11, 10, 11, 10, 10, 11, 10, 11],
            zones: [.center, .n, .center, .center, .n, .center, .ne, .center, .center, .n, .center, .center, .n, .center, .center, .center, .n, .center],
            plotX: [ 0.015,  0.012, -0.010,  0.018,  0.025, -0.005,  0.030, -0.018,  0.022,  0.010, -0.012,  0.028,  0.015, -0.015,  0.020,  0.010, -0.008,  0.008],
            plotY: [ 0.095,  0.030,  0.112,  0.025,  0.095,  0.040,  0.108,  0.120,  0.035,  0.102,  0.042,  0.115,  0.038,  0.105,  0.092,  0.028,  0.118,  0.032]
        )

        // dev_s1_7 — bc1c, 70m outdoor, best session, mostly 11s/Xs, tight NE cluster
        plots += makePlots(
            sessionId: "dev_s1_7", bowConfigId: "dev_bc1c", arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(1), count: 18,
            rings: [11, 11, 10, 11, 11, 10, 11, 11, 11, 10, 11, 11, 10, 11, 11, 11, 10, 11],
            zones: [.center, .center, .n, .center, .center, .center, .n, .center, .center, .center, .center, .n, .center, .center, .center, .center, .n, .center],
            plotX: [ 0.020,  0.025,  0.088,  0.018,  0.028,  0.095,  0.015,  0.022,  0.030,  0.082,  0.012,  0.025,  0.098,  0.020,  0.018,  0.022,  0.085,  0.015],
            plotY: [ 0.025,  0.030,  0.095,  0.022,  0.032,  0.105,  0.020,  0.028,  0.018,  0.108,  0.035,  0.030,  0.090,  0.025,  0.040,  0.015,  0.112,  0.028]
        )

        // dev_s1_8 — bc1c, 50m outdoor, 10s/11s, tightening, N bias only
        plots += makePlots(
            sessionId: "dev_s1_8", bowConfigId: "dev_bc1c", arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(0), count: 18,
            rings: [10, 11, 11, 10, 11, 10, 11, 11, 10, 11, 10, 11, 11, 10, 11, 10, 11, 11],
            zones: [.center, .center, .n, .center, .center, .n, .center, .center, .n, .center, .center, .center, .n, .center, .center, .center, .n, .center],
            plotX: [ 0.008,  0.012, -0.005,  0.015,  0.018, -0.010,  0.010, -0.008,  0.012,  0.020, -0.005,  0.015, -0.010,  0.010,  0.018,  0.008, -0.010,  0.020],
            plotY: [ 0.088,  0.018,  0.025,  0.095,  0.022,  0.090,  0.015,  0.030,  0.085,  0.012,  0.092,  0.020,  0.028,  0.088,  0.010,  0.086,  0.022,  0.018]
        )

        // dev_s2_1 — bc2a, early, wide, 8s/9s
        plots += makePlots(
            sessionId: "dev_s2_1", bowConfigId: "dev_bc2a", arrowConfigId: "dev_arrow2",
            startedAt: daysAgo(34), count: 12,
            rings: [8, 8, 9, 8, 9, 8, 8, 9, 8, 9, 8, 8],
            zones: [.nw, .w, .sw, .n, .ne, .w, .nw, .s, .e, .nw, .w, .n]
        )

        // dev_s2_2 — bc2a, 8s/9s, slightly tighter
        plots += makePlots(
            sessionId: "dev_s2_2", bowConfigId: "dev_bc2a", arrowConfigId: "dev_arrow2",
            startedAt: daysAgo(31), count: 13,
            rings: [8, 9, 8, 9, 9, 8, 9, 9, 8, 9, 8, 9, 9],
            zones: [.w, .nw, .n, .w, .ne, .nw, .n, .w, .ne, .n, .nw, .w, .n]
        )

        // dev_s2_3 — bc2b, 9s/10s, tighter
        plots += makePlots(
            sessionId: "dev_s2_3", bowConfigId: "dev_bc2b", arrowConfigId: "dev_arrow2",
            startedAt: daysAgo(27), count: 14,
            rings: [9, 10, 9, 10, 9, 10, 9, 10, 10, 9, 10, 9, 10, 10],
            zones: [.n, .ne, .center, .n, .ne, .center, .n, .ne, .center, .n, .center, .ne, .n, .center]
        )

        // dev_s2_4 — bc2b, 9s/10s, windage issue
        plots += makePlots(
            sessionId: "dev_s2_4", bowConfigId: "dev_bc2b", arrowConfigId: "dev_arrow2",
            startedAt: daysAgo(20), count: 15,
            rings: [9, 10, 9, 10, 10, 9, 10, 9, 10, 9, 10, 9, 10, 10, 9],
            zones: [.nw, .w, .nw, .n, .nw, .w, .nw, .n, .w, .nw, .n, .nw, .w, .n, .nw]
        )

        // dev_s2_5 — bc2b, 10s/11s, NW bias (left-high drift)
        plots += makePlots(
            sessionId: "dev_s2_5", bowConfigId: "dev_bc2b", arrowConfigId: "dev_arrow2",
            startedAt: daysAgo(12), count: 15,
            rings: [10, 11, 10, 11, 10, 11, 10, 11, 10, 11, 10, 11, 10, 11, 10],
            zones: [.center, .n, .center, .center, .n, .center, .ne, .center, .n, .center, .center, .n, .center, .center, .n],
            plotX: [-0.068, -0.022, -0.080, -0.018, -0.072, -0.025, -0.085, -0.020, -0.078, -0.028, -0.070, -0.015, -0.082, -0.022, -0.075],
            plotY: [ 0.065,  0.020,  0.055,  0.025,  0.070,  0.015,  0.062,  0.030,  0.060,  0.018,  0.068,  0.022,  0.058,  0.028,  0.065]
        )

        // dev_s2_6 — bc2b, 10s/11s, NW bias persisting (consistent drift)
        plots += makePlots(
            sessionId: "dev_s2_6", bowConfigId: "dev_bc2b", arrowConfigId: "dev_arrow2",
            startedAt: daysAgo(6), count: 14,
            rings: [10, 11, 10, 11, 10, 10, 11, 10, 11, 10, 11, 10, 10, 11],
            zones: [.center, .n, .center, .center, .n, .center, .center, .n, .center, .center, .n, .center, .center, .center],
            plotX: [-0.062, -0.018, -0.072, -0.015, -0.065, -0.078, -0.020, -0.070, -0.012, -0.068, -0.018, -0.075, -0.060, -0.015],
            plotY: [ 0.060,  0.015,  0.055,  0.022,  0.062,  0.050,  0.018,  0.058,  0.025,  0.065,  0.020,  0.052,  0.068,  0.015]
        )

        return plots
    }()

    static func arrowPlots(for sessionId: String) -> [ArrowPlot] {
        allArrowPlots.filter { $0.sessionId == sessionId }
    }

    static func ends(for sessionId: String) -> [SessionEnd] {
        let allSessions = bow1Sessions + bow2Sessions
        return allSessions.first { $0.id == sessionId }?.ends ?? []
    }

    // MARK: - Analytics Suggestions

    private static let bow1Suggestions: [AnalyticsSuggestion] = [
        AnalyticsSuggestion(
            id: "dev_sug1a",
            bowId: "dev_bow1",
            createdAt: daysAgo(2),
            parameter: "restVertical",
            suggestedValue: "+3/16\"",
            currentValue: "+2/16\"",
            reasoning: "Arrow flight shows mild porpoising pattern across last 3 sessions — consistent vertical oscillation visible in zone distribution. Raising rest 1/16\" may improve vertical forgiveness and tighten grouping consistency.",
            confidence: 0.82,
            qualifier: nil,
            wasRead: false,
            deliveryType: .push,
            evidence: SuggestionEvidence(
                sampleSize: 47,
                sessionIds: ["dev_s1_6", "dev_s1_7", "dev_s1_8"],
                windowStart: daysAgo(14),
                windowEnd: daysAgo(2),
                metrics: [
                    .init(label: "Average score", value: "10.5", deltaFromBaseline: "+0.4"),
                    .init(label: "Vertical drift", value: "0.09 in", deltaFromBaseline: "+0.06 in"),
                    .init(label: "Sessions analyzed", value: "3", deltaFromBaseline: nil),
                ],
                relatedConfigChangeIds: nil,
                patternType: "directional_drift"
            )
        ),
        AnalyticsSuggestion(
            id: "dev_sug1b",
            bowId: "dev_bow1",
            createdAt: daysAgo(3),
            parameter: "peepHeight",
            suggestedValue: "9.5\"",
            currentValue: "9.25\"",
            reasoning: "Anchor inconsistency detected in 4 of last 12 arrows. Slight peep height increase may improve alignment.",
            confidence: 0.71,
            qualifier: nil,
            wasRead: false,
            deliveryType: .inApp
        ),
        AnalyticsSuggestion(
            id: "dev_sug1c",
            bowId: "dev_bow1",
            createdAt: daysAgo(8),
            parameter: "topLimbTurns",
            suggestedValue: "-1.0 turns",
            currentValue: "-0.5 turns",
            reasoning: "Draw force curve suggests bow is slightly over peak weight. Backing off limb tension may improve shot consistency.",
            confidence: 0.65,
            qualifier: nil,
            wasRead: true,
            deliveryType: .inApp
        ),
        AnalyticsSuggestion(
            id: "dev_sug1d",
            bowId: "dev_bow1",
            createdAt: daysAgo(10),
            parameter: "dLoopLength",
            suggestedValue: "2.25\"",
            currentValue: "2.125\"",
            reasoning: "Slight nocking point inconsistency over last 6 shots. A longer D-loop may reduce this variance.",
            confidence: 0.58,
            qualifier: nil,
            wasRead: true,
            deliveryType: .reinforcement,
            // Demo of the applied state — sorts to bottom in the analytics
            // list and renders the green "Applied" capsule + disabled CTA.
            wasApplied: true,
            appliedAt: daysAgo(7),
            appliedConfigId: "dev_bc1c"
        ),
        AnalyticsSuggestion(
            id: "dev_sug1e",
            bowId: "dev_bow1",
            createdAt: daysAgo(2),
            parameter: "sightPosition",
            suggestedValue: "+1",
            currentValue: "0",
            reasoning: "Sessions tagged 'grip_torque' show 34% worse grouping scores than clean sessions. Moving the sight rod one position back increases the effective sight radius, reducing torque amplification and may improve grouping consistency under grip pressure.",
            confidence: 0.77,
            qualifier: nil,
            wasRead: false,
            deliveryType: .push
        ),
    ]

    private static let bow2Suggestions: [AnalyticsSuggestion] = [
        AnalyticsSuggestion(
            id: "dev_sug2a",
            bowId: "dev_bow2",
            createdAt: daysAgo(4),
            parameter: "mainStringTopTwists",
            suggestedValue: "4 twists",
            currentValue: "3 twists",
            reasoning: "String walking detected — top string twists slightly looser than bottom. Equalize for better nock travel.",
            confidence: 0.74,
            qualifier: nil,
            wasRead: false,
            deliveryType: .push
        ),
        AnalyticsSuggestion(
            id: "dev_sug2b",
            bowId: "dev_bow2",
            createdAt: daysAgo(7),
            parameter: "restHorizontal",
            suggestedValue: "+1/16\"",
            currentValue: "0",
            reasoning: "Arrows consistently printing left-of-center. Minor windage adjustment recommended.",
            confidence: 0.69,
            qualifier: nil,
            wasRead: true,
            deliveryType: .inApp
        ),
        AnalyticsSuggestion(
            id: "dev_sug2c",
            bowId: "dev_bow2",
            createdAt: daysAgo(9),
            parameter: "nockingHeight",
            suggestedValue: "+2/16\"",
            currentValue: "+1/16\"",
            reasoning: "Nocking point pattern suggests arrows are leaving slightly porpoising. Raising nocking height 1/16\" may stabilize.",
            confidence: 0.61,
            qualifier: nil,
            wasRead: true,
            deliveryType: .reinforcement
        ),
    ]

    static func suggestions() -> [AnalyticsSuggestion] {
        return bow1Suggestions + bow2Suggestions
    }

    // MARK: - Period Comparisons

    static func comparison(period: AnalyticsPeriod) -> PeriodComparison {
        switch period {

        case .threeDays:
            // Current: tight NE cluster — X shots ~4mm NE, missed-X ring-10s just outside X ring N
            let cur = PeriodSlice(
                label: "Last 3 Days",
                plots: makePlots(
                    sessionId: "cmp_3d_cur", bowConfigId: "dev_bc1c", arrowConfigId: "dev_arrow1",
                    startedAt: daysAgo(2), count: 18,
                    rings: [11, 11, 10, 11, 11, 10, 11, 11, 11, 10, 11, 11, 10, 11, 11, 11, 10, 11],
                    zones:  [.center, .center, .n, .center, .center, .n, .center, .center, .center,
                             .n, .center, .center, .n, .center, .center, .center, .n, .center],
                    plotX: [ 0.022,  0.016,  0.000,  0.025,  0.018,  0.030,  0.028,  0.012,  0.030,
                            -0.025,  0.022,  0.020,  0.015,  0.025,  0.010,  0.024, -0.010,  0.018],
                    plotY: [ 0.028,  0.022,  0.092,  0.018,  0.032,  0.088,  0.025,  0.035,  0.020,
                             0.088,  0.030,  0.015,  0.090,  0.022,  0.038,  0.028,  0.092,  0.025]
                ),
                avgArrowScore: 10.7, xPercentage: 72, sessionCount: 3, config: bc1c
            )
            // Previous: fewer Xs, N drift — missed-X ring-10s barely outside X ring, still very tight
            let prev = PeriodSlice(
                label: "Previous 3 Days",
                plots: makePlots(
                    sessionId: "cmp_3d_prv", bowConfigId: "dev_bc1c", arrowConfigId: "dev_arrow1",
                    startedAt: daysAgo(6), count: 18,
                    rings: [10, 11, 10, 10, 11, 10, 10, 11, 10, 10, 11, 10, 10, 11, 10, 10, 10, 10],
                    zones:  [.n, .center, .n, .n, .center, .n, .n, .center, .n,
                             .n, .center, .n, .n, .center, .n, .n, .n, .n],
                    plotX: [ 0.005,  0.010, -0.020,  0.025, -0.005, -0.035,  0.040,  0.015, -0.010,
                             0.048, -0.008, -0.042,  0.030,  0.005, -0.015,  0.035, -0.025,  0.012],
                    plotY: [ 0.090,  0.015,  0.088,  0.086,  0.022,  0.082,  0.082,  0.018,  0.092,
                             0.076,  0.025,  0.080,  0.086,  0.020,  0.090,  0.084,  0.087,  0.091]
                ),
                avgArrowScore: 10.28, xPercentage: 28, sessionCount: 3, config: bc1c
            )
            return PeriodComparison(period: period, current: cur, previous: prev)

        case .twoWeeks:
            // Current: tight NW cluster — X shots ~3.7mm NW, ring-10 just outside X ring NW
            let cur = PeriodSlice(
                label: "This 2 Weeks",
                plots: makePlots(
                    sessionId: "cmp_2w_cur", bowConfigId: "dev_bc1c", arrowConfigId: "dev_arrow1",
                    startedAt: daysAgo(7), count: 18,
                    rings: [10, 11, 11, 10, 11, 10, 11, 11, 10, 11, 10, 11, 11, 10, 11, 10, 11, 11],
                    zones:  [.nw, .nw, .nw, .nw, .nw, .nw, .nw, .nw, .nw,
                             .nw, .nw, .nw, .nw, .nw, .nw, .nw, .nw, .nw],
                    plotX: [-0.062, -0.018, -0.025, -0.068, -0.028, -0.072, -0.015, -0.030, -0.058,
                            -0.020, -0.050, -0.032, -0.012, -0.078, -0.025, -0.045, -0.035, -0.015],
                    plotY: [ 0.065,  0.020,  0.015,  0.060,  0.022,  0.055,  0.028,  0.012,  0.070,
                             0.018,  0.078,  0.015,  0.030,  0.048,  0.010,  0.080,  0.018,  0.025]
                ),
                avgArrowScore: 10.6, xPercentage: 61, sessionCount: 7, config: bc1c
            )
            // Previous: N drift on old config bc1a — tighter group, drift shifted after tuning change
            let prev = PeriodSlice(
                label: "Previous 2 Weeks",
                plots: makePlots(
                    sessionId: "cmp_2w_prv", bowConfigId: "dev_bc1a", arrowConfigId: "dev_arrow1",
                    startedAt: daysAgo(21), count: 18,
                    rings: [10, 11, 10, 11, 10, 11, 10, 10, 11, 10, 11, 10, 11, 10, 11, 10, 11, 10],
                    zones:  [.n, .center, .n, .center, .n, .center, .n, .n, .center,
                             .n, .center, .n, .center, .n, .center, .n, .center, .n],
                    plotX: [ 0.008,  0.008, -0.025, -0.010,  0.030,  0.012, -0.040,  0.020, -0.006,
                            -0.012,  0.010,  0.045, -0.015, -0.038,  0.005,  0.025, -0.008, -0.020],
                    plotY: [ 0.090,  0.018,  0.086,  0.025,  0.085,  0.015,  0.080,  0.088,  0.028,
                             0.092,  0.012,  0.078,  0.022,  0.082,  0.020,  0.087,  0.015,  0.089]
                ),
                avgArrowScore: 10.44, xPercentage: 44, sessionCount: 5, config: bc1a
            )
            return PeriodComparison(period: period, current: cur, previous: prev)

        case .month:
            let cur = PeriodSlice(
                label: "This Month",
                plots: makePlots(
                    sessionId: "cmp_1m_cur", bowConfigId: "dev_bc1c", arrowConfigId: "dev_arrow1",
                    startedAt: daysAgo(5), count: 18,
                    rings: [10, 11, 10, 11, 10, 11, 10, 11, 10, 11, 10, 11, 10, 11, 10, 11, 10, 11],
                    zones:  [.center, .center, .n, .center, .n, .center, .ne, .center, .center,
                             .n, .center, .center, .n, .center, .center, .center, .n, .center]
                ),
                avgArrowScore: 10.5, xPercentage: 50, sessionCount: 9, config: bc1c
            )
            let prev = PeriodSlice(
                label: "Last Month",
                plots: makePlots(
                    sessionId: "cmp_1m_prv", bowConfigId: "dev_bc1a", arrowConfigId: "dev_arrow1",
                    startedAt: daysAgo(35), count: 18,
                    rings: [8, 8, 9, 8, 8, 9, 8, 8, 9, 8, 9, 8, 8, 9, 8, 9, 8, 8],
                    zones:  [.nw, .w, .n, .ne, .nw, .w, .nw, .n, .ne, .w, .n, .nw,
                             .ne, .w, .nw, .n, .w, .nw]
                ),
                avgArrowScore: 8.3, xPercentage: 0, sessionCount: 7, config: bc1a
            )
            return PeriodComparison(period: period, current: cur, previous: prev)

        case .threeMonths:
            let cur = PeriodSlice(
                label: "This 3 Months",
                plots: makePlots(
                    sessionId: "cmp_3mo_cur", bowConfigId: "dev_bc1c", arrowConfigId: "dev_arrow1",
                    startedAt: daysAgo(14), count: 18,
                    rings: [10, 11, 11, 10, 11, 10, 11, 11, 10, 11, 11, 10, 11, 11, 10, 11, 10, 11],
                    zones:  [.center, .center, .n, .center, .center, .ne, .center, .center, .n,
                             .center, .center, .n, .center, .center, .center, .n, .center, .center]
                ),
                avgArrowScore: 10.6, xPercentage: 56, sessionCount: 18, config: bc1c
            )
            let prev = PeriodSlice(
                label: "Previous 3 Months",
                plots: makePlots(
                    sessionId: "cmp_3mo_prv", bowConfigId: "dev_bc1a", arrowConfigId: "dev_arrow1",
                    startedAt: daysAgo(75), count: 18,
                    rings: [8, 9, 8, 8, 9, 8, 9, 8, 9, 8, 8, 9, 8, 9, 8, 8, 9, 8],
                    zones:  [.nw, .n, .w, .nw, .n, .ne, .nw, .w, .n, .ne, .nw, .n,
                             .w, .nw, .ne, .n, .nw, .w]
                ),
                avgArrowScore: 8.4, xPercentage: 0, sessionCount: 12, config: bc1a
            )
            return PeriodComparison(period: period, current: cur, previous: prev)

        case .sixMonths:
            let cur = PeriodSlice(
                label: "This 6 Months",
                plots: makePlots(
                    sessionId: "cmp_6mo_cur", bowConfigId: "dev_bc1c", arrowConfigId: "dev_arrow1",
                    startedAt: daysAgo(30), count: 18,
                    rings: [10, 11, 10, 11, 10, 11, 10, 11, 11, 10, 11, 10, 11, 10, 11, 10, 11, 10],
                    zones:  [.center, .center, .n, .center, .ne, .center, .center, .n,
                             .center, .center, .n, .center, .center, .ne, .center, .n, .center, .center]
                ),
                avgArrowScore: 10.5, xPercentage: 50, sessionCount: 34, config: bc1c
            )
            let prev = PeriodSlice(
                label: "Previous 6 Months",
                plots: makePlots(
                    sessionId: "cmp_6mo_prv", bowConfigId: "dev_bc1a", arrowConfigId: "dev_arrow1",
                    startedAt: daysAgo(150), count: 18,
                    rings: [8, 7, 9, 8, 7, 9, 8, 8, 9, 7, 8, 9, 8, 7, 9, 8, 7, 8],
                    zones:  [.nw, .w, .sw, .n, .nw, .w, .ne, .nw, .n, .w, .sw,
                             .nw, .n, .w, .nw, .sw, .n, .w]
                ),
                avgArrowScore: 8.0, xPercentage: 0, sessionCount: 20, config: bc1a
            )
            return PeriodComparison(period: period, current: cur, previous: prev)

        case .year:
            let cur = PeriodSlice(
                label: "This Year",
                plots: makePlots(
                    sessionId: "cmp_1y_cur", bowConfigId: "dev_bc1c", arrowConfigId: "dev_arrow1",
                    startedAt: daysAgo(60), count: 18,
                    rings: [10, 11, 10, 11, 10, 11, 10, 11, 10, 11, 10, 11, 10, 11, 10, 11, 11, 10],
                    zones:  [.center, .center, .n, .center, .center, .n, .center, .center,
                             .ne, .center, .center, .n, .center, .center, .n, .center, .center, .ne]
                ),
                avgArrowScore: 10.5, xPercentage: 50, sessionCount: 58, config: bc1c
            )
            let prev = PeriodSlice(
                label: "Last Year",
                plots: makePlots(
                    sessionId: "cmp_1y_prv", bowConfigId: "dev_bc1a", arrowConfigId: "dev_arrow1",
                    startedAt: daysAgo(300), count: 18,
                    rings: [7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8],
                    zones:  [.sw, .w, .nw, .s, .sw, .w, .nw, .n, .ne, .w,
                             .sw, .s, .nw, .w, .sw, .s, .w, .nw]
                ),
                avgArrowScore: 7.5, xPercentage: 0, sessionCount: 31, config: bc1a
            )
            return PeriodComparison(period: period, current: cur, previous: prev)

        default: // .week
            let cur = PeriodSlice(
                label: "This Week",
                plots: makePlots(
                    sessionId: "cmp_w_cur", bowConfigId: "dev_bc1c", arrowConfigId: "dev_arrow1",
                    startedAt: daysAgo(5), count: 18,
                    rings: [10, 11, 11, 10, 11, 11, 10, 11, 11, 10, 11, 10, 11, 11, 10, 11, 10, 11],
                    zones:  [.center, .center, .n, .center, .n, .center, .ne, .center, .center,
                             .n, .center, .center, .n, .center, .center, .center, .n, .center]
                ),
                avgArrowScore: 10.6, xPercentage: 61, sessionCount: 5, config: bc1c
            )
            let prev = PeriodSlice(
                label: "Last Week",
                plots: makePlots(
                    sessionId: "cmp_w_prv", bowConfigId: "dev_bc1b", arrowConfigId: "dev_arrow1",
                    startedAt: daysAgo(12), count: 18,
                    rings: [9, 10, 9, 10, 9, 9, 10, 9, 10, 9, 9, 10, 9, 9, 10, 9, 10, 9],
                    zones:  [.n, .ne, .nw, .n, .ne, .nw, .n, .ne, .nw, .n, .ne, .n,
                             .nw, .n, .ne, .nw, .n, .nw]
                ),
                avgArrowScore: 9.4, xPercentage: 17, sessionCount: 5, config: bc1b
            )
            return PeriodComparison(period: period, current: cur, previous: prev)
        }
    }

    // MARK: - Analytics Overviews

    static func overview(period: AnalyticsPeriod) -> AnalyticsOverview {
        let allSuggestions = bow1Suggestions + bow2Suggestions
        switch period {
        case .threeDays:   return AnalyticsOverview(period: period, sessionCount: 3,  avgArrowScore: 10.7, xPercentage: 72, suggestions: allSuggestions)
        case .week:        return AnalyticsOverview(period: period, sessionCount: 5,  avgArrowScore: 10.3, xPercentage: 61, suggestions: allSuggestions)
        case .twoWeeks:    return AnalyticsOverview(period: period, sessionCount: 9,  avgArrowScore: 10.0, xPercentage: 50, suggestions: allSuggestions)
        case .month:       return AnalyticsOverview(period: period, sessionCount: 17, avgArrowScore: 9.7,  xPercentage: 41, suggestions: allSuggestions)
        case .threeMonths: return AnalyticsOverview(period: period, sessionCount: 30, avgArrowScore: 9.4,  xPercentage: 32, suggestions: allSuggestions)
        case .sixMonths:   return AnalyticsOverview(period: period, sessionCount: 54, avgArrowScore: 9.1,  xPercentage: 24, suggestions: allSuggestions)
        case .year:        return AnalyticsOverview(period: period, sessionCount: 89, avgArrowScore: 8.8,  xPercentage: 18, suggestions: allSuggestions)
        }
    }
}

#endif
