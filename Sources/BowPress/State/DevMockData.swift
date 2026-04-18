import Foundation

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
        brand: "Mathews",
        model: "TITLE 36",
        createdAt: daysAgo(45)
    )

    static let bow2 = Bow(
        id: "dev_bow2",
        userId: "dev",
        name: "Hoyt Concept X 37",
        brand: "Hoyt",
        model: "Concept X 37",
        createdAt: daysAgo(60)
    )

    static let bows: [Bow] = [bow1, bow2]

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
        rearStabSide: .none,
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
        rearStabSide: .none,
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
            conditions: SessionConditions(windSpeed: 8, tempF: 62, lighting: "bright"),
            arrowCount: 12
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
            conditions: SessionConditions(windSpeed: 4, tempF: 68, lighting: "overcast"),
            arrowCount: 15
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
            conditions: SessionConditions(windSpeed: 12, tempF: 60, lighting: "bright"),
            arrowCount: 14
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
            conditions: SessionConditions(windSpeed: 2, tempF: 72, lighting: "bright"),
            arrowCount: 16
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
            conditions: SessionConditions(windSpeed: 0, tempF: 75, lighting: "indoor"),
            arrowCount: 12
        ),
        ShootingSession(
            id: "dev_s1_6",
            bowId: "dev_bow1",
            bowConfigId: "dev_bc1c",
            arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(9),
            endedAt: daysAgo(9).addingTimeInterval(5_400),
            notes: "Competition setup dialed in. Hitting consistent Xs in low-wind conditions.",
            feelTags: ["consistent", "clean_release"],
            conditions: SessionConditions(windSpeed: 1, tempF: 70, lighting: "bright"),
            arrowCount: 18
        ),
        ShootingSession(
            id: "dev_s1_7",
            bowId: "dev_bow1",
            bowConfigId: "dev_bc1c",
            arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(5),
            endedAt: daysAgo(5).addingTimeInterval(5_700),
            notes: "Best session yet. Back tension fully engaged, impact pattern very tight.",
            feelTags: ["back_tension", "clean_release", "consistent"],
            conditions: SessionConditions(windSpeed: 3, tempF: 73, lighting: "bright"),
            arrowCount: 18
        ),
        ShootingSession(
            id: "dev_s1_8",
            bowId: "dev_bow1",
            bowConfigId: "dev_bc1c",
            arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(2),
            endedAt: daysAgo(2).addingTimeInterval(5_400),
            notes: "Pre-comp tune check. Groups holding well. Minor sight drift to correct.",
            feelTags: ["consistent", "clean_release"],
            conditions: SessionConditions(windSpeed: 5, tempF: 68, lighting: "overcast"),
            arrowCount: 18
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
            conditions: SessionConditions(windSpeed: 6, tempF: 58, lighting: "overcast"),
            arrowCount: 12
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
            conditions: SessionConditions(windSpeed: 9, tempF: 55, lighting: "bright"),
            arrowCount: 13
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
            conditions: SessionConditions(windSpeed: 3, tempF: 71, lighting: "bright"),
            arrowCount: 14
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
            conditions: SessionConditions(windSpeed: 0, tempF: 78, lighting: "indoor"),
            arrowCount: 15
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
            conditions: SessionConditions(windSpeed: 2, tempF: 74, lighting: "bright"),
            arrowCount: 15
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
            conditions: SessionConditions(windSpeed: 4, tempF: 65, lighting: "overcast"),
            arrowCount: 14
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

    private static func makePlots(sessionId: String, bowConfigId: String, arrowConfigId: String, startedAt: Date, count: Int, rings: [Int], zones: [ArrowPlot.Zone]) -> [ArrowPlot] {
        (0..<count).map { i in
            ArrowPlot(
                id: "\(sessionId)_p\(i + 1)",
                sessionId: sessionId,
                bowConfigId: bowConfigId,
                arrowConfigId: arrowConfigId,
                ring: rings[i % rings.count],
                zone: zones[i % zones.count],
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

        // dev_s1_6 — bc1c, 10s/11s, mostly center/n
        plots += makePlots(
            sessionId: "dev_s1_6", bowConfigId: "dev_bc1c", arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(9), count: 18,
            rings: [10, 11, 10, 11, 10, 11, 10, 10, 11, 10, 11, 10, 11, 10, 10, 11, 10, 11],
            zones: [.center, .n, .center, .center, .n, .center, .ne, .center, .center, .n, .center, .center, .n, .center, .center, .center, .n, .center]
        )

        // dev_s1_7 — bc1c, best session, mostly 11s/Xs
        plots += makePlots(
            sessionId: "dev_s1_7", bowConfigId: "dev_bc1c", arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(5), count: 18,
            rings: [11, 11, 10, 11, 11, 10, 11, 11, 11, 10, 11, 11, 10, 11, 11, 11, 10, 11],
            zones: [.center, .center, .n, .center, .center, .center, .n, .center, .center, .center, .center, .n, .center, .center, .center, .center, .n, .center]
        )

        // dev_s1_8 — bc1c, 10s/11s, tight
        plots += makePlots(
            sessionId: "dev_s1_8", bowConfigId: "dev_bc1c", arrowConfigId: "dev_arrow1",
            startedAt: daysAgo(2), count: 18,
            rings: [10, 11, 11, 10, 11, 10, 11, 11, 10, 11, 10, 11, 11, 10, 11, 10, 11, 11],
            zones: [.center, .center, .n, .center, .center, .n, .center, .center, .n, .center, .center, .center, .n, .center, .center, .center, .n, .center]
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

        // dev_s2_5 — bc2b, 10s/11s
        plots += makePlots(
            sessionId: "dev_s2_5", bowConfigId: "dev_bc2b", arrowConfigId: "dev_arrow2",
            startedAt: daysAgo(12), count: 15,
            rings: [10, 11, 10, 11, 10, 11, 10, 11, 10, 11, 10, 11, 10, 11, 10],
            zones: [.center, .n, .center, .center, .n, .center, .ne, .center, .n, .center, .center, .n, .center, .center, .n]
        )

        // dev_s2_6 — bc2b, 10s/11s, consistent
        plots += makePlots(
            sessionId: "dev_s2_6", bowConfigId: "dev_bc2b", arrowConfigId: "dev_arrow2",
            startedAt: daysAgo(6), count: 14,
            rings: [10, 11, 10, 11, 10, 10, 11, 10, 11, 10, 11, 10, 10, 11],
            zones: [.center, .n, .center, .center, .n, .center, .center, .n, .center, .center, .n, .center, .center, .center]
        )

        return plots
    }()

    static func arrowPlots(for sessionId: String) -> [ArrowPlot] {
        allArrowPlots.filter { $0.sessionId == sessionId }
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
            deliveryType: .push
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
            deliveryType: .reinforcement
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
            let cur = PeriodSlice(
                label: "Last 3 Days",
                plots: makePlots(
                    sessionId: "cmp_3d_cur", bowConfigId: "dev_bc1c", arrowConfigId: "dev_arrow1",
                    startedAt: daysAgo(2), count: 18,
                    rings: [11, 11, 10, 11, 11, 10, 11, 11, 11, 10, 11, 11, 10, 11, 11, 11, 10, 11],
                    zones:  [.center, .center, .n, .center, .center, .center, .n, .center, .center,
                             .center, .center, .n, .center, .center, .center, .center, .n, .center]
                ),
                avgArrowScore: 10.7, xPercentage: 72, sessionCount: 3, config: bc1c
            )
            let prev = PeriodSlice(
                label: "Previous 3 Days",
                plots: makePlots(
                    sessionId: "cmp_3d_prv", bowConfigId: "dev_bc1c", arrowConfigId: "dev_arrow1",
                    startedAt: daysAgo(6), count: 18,
                    rings: [10, 11, 10, 10, 11, 10, 10, 11, 10, 9, 11, 10, 10, 11, 10, 10, 9, 10],
                    zones:  [.center, .center, .n, .ne, .center, .n, .center, .n, .ne,
                             .n, .center, .n, .center, .center, .ne, .n, .ne, .center]
                ),
                avgArrowScore: 10.2, xPercentage: 44, sessionCount: 3, config: bc1c
            )
            return PeriodComparison(period: period, current: cur, previous: prev)

        case .twoWeeks:
            let cur = PeriodSlice(
                label: "This 2 Weeks",
                plots: makePlots(
                    sessionId: "cmp_2w_cur", bowConfigId: "dev_bc1c", arrowConfigId: "dev_arrow1",
                    startedAt: daysAgo(7), count: 18,
                    rings: [10, 11, 11, 10, 11, 10, 11, 11, 10, 11, 10, 11, 11, 10, 11, 10, 11, 11],
                    zones:  [.center, .center, .n, .center, .center, .n, .center, .center, .n,
                             .center, .center, .n, .center, .center, .center, .n, .center, .center]
                ),
                avgArrowScore: 10.6, xPercentage: 61, sessionCount: 7, config: bc1c
            )
            let prev = PeriodSlice(
                label: "Previous 2 Weeks",
                plots: makePlots(
                    sessionId: "cmp_2w_prv", bowConfigId: "dev_bc1a", arrowConfigId: "dev_arrow1",
                    startedAt: daysAgo(21), count: 18,
                    rings: [8, 9, 8, 9, 8, 9, 8, 9, 9, 8, 9, 8, 9, 8, 9, 8, 9, 8],
                    zones:  [.nw, .n, .ne, .w, .nw, .n, .ne, .nw, .n, .w, .ne, .nw,
                             .n, .w, .nw, .ne, .n, .nw]
                ),
                avgArrowScore: 8.5, xPercentage: 0, sessionCount: 5, config: bc1a
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
