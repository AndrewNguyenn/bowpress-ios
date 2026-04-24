import Foundation
import SwiftData
import Observation

@Observable @MainActor
final class LocalStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Bows

    func fetchBows() throws -> [Bow] {
        let descriptor = FetchDescriptor<PersistentBow>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toDTO() }
    }

    func save(bow: Bow) throws {
        let id = bow.id
        let predicate = #Predicate<PersistentBow> { $0.id == id }
        let descriptor = FetchDescriptor<PersistentBow>(predicate: predicate)
        if let existing = try context.fetch(descriptor).first {
            existing.userId = bow.userId
            existing.name = bow.name
            existing.bowTypeStr = bow.bowType.rawValue
            existing.brand = bow.brand
            existing.model = bow.model
            existing.createdAt = bow.createdAt
        } else {
            let record = PersistentBow.from(bow)
            record.pendingSync = true
            context.insert(record)
        }
        try context.save()
    }

    func deleteBow(id: String) throws {
        let predicate = #Predicate<PersistentBow> { $0.id == id }
        let descriptor = FetchDescriptor<PersistentBow>(predicate: predicate)
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            try context.save()
        }
    }

    // MARK: - BowConfigurations

    func fetchConfigurations(bowId: String) throws -> [BowConfiguration] {
        let predicate = #Predicate<PersistentBowConfig> { $0.bowId == bowId }
        let descriptor = FetchDescriptor<PersistentBowConfig>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toDTO() }
    }

    func save(config: BowConfiguration) throws {
        let id = config.id
        let predicate = #Predicate<PersistentBowConfig> { $0.id == id }
        let descriptor = FetchDescriptor<PersistentBowConfig>(predicate: predicate)
        if let existing = try context.fetch(descriptor).first {
            existing.bowId = config.bowId
            existing.createdAt = config.createdAt
            existing.label = config.label
            existing.drawLength = config.drawLength
            existing.letOffPct = config.letOffPct
            existing.peepHeight = config.peepHeight
            existing.dLoopLength = config.dLoopLength
            existing.topCableTwists = config.topCableTwists
            existing.bottomCableTwists = config.bottomCableTwists
            existing.mainStringTopTwists = config.mainStringTopTwists
            existing.mainStringBottomTwists = config.mainStringBottomTwists
            existing.topLimbTurns = config.topLimbTurns
            existing.bottomLimbTurns = config.bottomLimbTurns
            existing.restVertical = config.restVertical
            existing.restHorizontal = config.restHorizontal
            existing.restDepth = config.restDepth
            existing.sightPosition = config.sightPosition
            existing.gripAngle = config.gripAngle
            existing.nockingHeight = config.nockingHeight
            existing.frontStabWeight = config.frontStabWeight
            existing.frontStabAngle = config.frontStabAngle
            existing.rearStabSideStr = config.rearStabSide?.rawValue
            existing.rearStabWeight = config.rearStabWeight
            existing.rearStabVertAngle = config.rearStabVertAngle
            existing.rearStabHorizAngle = config.rearStabHorizAngle
            existing.braceHeight = config.braceHeight
            existing.tillerTop = config.tillerTop
            existing.tillerBottom = config.tillerBottom
            existing.plungerTension = config.plungerTension
            existing.clickerPosition = config.clickerPosition
            existing.rearStabLeftWeight = config.rearStabLeftWeight
            existing.rearStabRightWeight = config.rearStabRightWeight
        } else {
            let record = PersistentBowConfig.from(config)
            record.pendingSync = true
            context.insert(record)
        }
        try context.save()
    }

    // MARK: - ArrowConfigurations

    func fetchArrowConfigs() throws -> [ArrowConfiguration] {
        let descriptor = FetchDescriptor<PersistentArrowConfig>(
            sortBy: [SortDescriptor(\.label)]
        )
        return try context.fetch(descriptor).map { $0.toDTO() }
    }

    func save(arrowConfig: ArrowConfiguration) throws {
        let id = arrowConfig.id
        let predicate = #Predicate<PersistentArrowConfig> { $0.id == id }
        let descriptor = FetchDescriptor<PersistentArrowConfig>(predicate: predicate)
        if let existing = try context.fetch(descriptor).first {
            existing.userId = arrowConfig.userId
            existing.label = arrowConfig.label
            existing.brand = arrowConfig.brand
            existing.model = arrowConfig.model
            existing.length = arrowConfig.length
            existing.pointWeight = arrowConfig.pointWeight
            existing.fletchingTypeStr = arrowConfig.fletchingType.rawValue
            existing.fletchingLength = arrowConfig.fletchingLength
            existing.fletchingOffset = arrowConfig.fletchingOffset
            existing.nockType = arrowConfig.nockType
            existing.totalWeight = arrowConfig.totalWeight
            existing.shaftDiameterRaw = arrowConfig.shaftDiameter?.rawValue
            existing.notes = arrowConfig.notes
        } else {
            let record = PersistentArrowConfig.from(arrowConfig)
            record.pendingSync = true
            context.insert(record)
        }
        try context.save()
    }

    func deleteArrowConfig(id: String) throws {
        let predicate = #Predicate<PersistentArrowConfig> { $0.id == id }
        let descriptor = FetchDescriptor<PersistentArrowConfig>(predicate: predicate)
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            try context.save()
        }
    }

    // MARK: - Sessions

    func save(session: ShootingSession) throws {
        let id = session.id
        let predicate = #Predicate<PersistentSession> { $0.id == id }
        let descriptor = FetchDescriptor<PersistentSession>(predicate: predicate)

        let tagsJSON: String
        if let data = try? JSONEncoder().encode(session.feelTags),
           let str = String(data: data, encoding: .utf8) {
            tagsJSON = str
        } else {
            tagsJSON = "[]"
        }

        if let existing = try context.fetch(descriptor).first {
            existing.bowId = session.bowId
            existing.bowConfigId = session.bowConfigId
            existing.arrowConfigId = session.arrowConfigId
            existing.startedAt = session.startedAt
            existing.endedAt = session.endedAt
            existing.notes = session.notes
            existing.feelTagsJSON = tagsJSON
            existing.arrowCount = session.arrowCount
        } else {
            let record = PersistentSession.from(session)
            record.pendingSync = true
            context.insert(record)
        }
        try context.save()
    }

    func fetchSessions() throws -> [ShootingSession] {
        let descriptor = FetchDescriptor<PersistentSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let arrowDescriptor = FetchDescriptor<PersistentArrowPlot>(
            sortBy: [SortDescriptor(\.shotAt)]
        )
        let arrowsBySession = Dictionary(grouping: try context.fetch(arrowDescriptor), by: { $0.sessionId })
        return try context.fetch(descriptor)
            .filter { $0.endedAt != nil }
            .map { record in
                var dto = record.toDTO()
                dto.arrowCount = arrowsBySession[record.id]?.count ?? 0
                return dto
            }
    }

    func fetchArrows(sessionId: String) throws -> [ArrowPlot] {
        let predicate = #Predicate<PersistentArrowPlot> { $0.sessionId == sessionId }
        let descriptor = FetchDescriptor<PersistentArrowPlot>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.shotAt)]
        )
        return try context.fetch(descriptor).map { $0.toDTO() }
    }

    func fetchEnds(sessionId: String) throws -> [SessionEnd] {
        let predicate = #Predicate<PersistentEnd> { $0.sessionId == sessionId }
        let descriptor = FetchDescriptor<PersistentEnd>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.endNumber)]
        )
        return try context.fetch(descriptor).map { $0.toDTO() }
    }

    func updateSession(id: String, endedAt: Date, notes: String, arrowCount: Int) throws {
        let predicate = #Predicate<PersistentSession> { $0.id == id }
        let descriptor = FetchDescriptor<PersistentSession>(predicate: predicate)
        if let existing = try context.fetch(descriptor).first {
            existing.endedAt = endedAt
            existing.notes = notes
            existing.arrowCount = arrowCount
            existing.pendingSync = true
            try context.save()
        }
    }

    func deleteSession(id: String) throws {
        let arrowPredicate = #Predicate<PersistentArrowPlot> { $0.sessionId == id }
        for arrow in try context.fetch(FetchDescriptor<PersistentArrowPlot>(predicate: arrowPredicate)) {
            context.delete(arrow)
        }
        let endPredicate = #Predicate<PersistentEnd> { $0.sessionId == id }
        for end in try context.fetch(FetchDescriptor<PersistentEnd>(predicate: endPredicate)) {
            context.delete(end)
        }
        let sessionPredicate = #Predicate<PersistentSession> { $0.id == id }
        if let existing = try context.fetch(FetchDescriptor<PersistentSession>(predicate: sessionPredicate)).first {
            context.delete(existing)
        }
        try context.save()
    }

    // MARK: - ArrowPlots

    func save(arrow: ArrowPlot) throws {
        let id = arrow.id
        let predicate = #Predicate<PersistentArrowPlot> { $0.id == id }
        let descriptor = FetchDescriptor<PersistentArrowPlot>(predicate: predicate)
        if let existing = try context.fetch(descriptor).first {
            existing.sessionId = arrow.sessionId
            existing.bowConfigId = arrow.bowConfigId
            existing.arrowConfigId = arrow.arrowConfigId
            existing.ring = arrow.ring
            existing.zoneStr = arrow.zone.rawValue
            existing.plotX = arrow.plotX
            existing.plotY = arrow.plotY
            // Preserve locally-stamped endId when the incoming record doesn't
            // carry one. `completeEnd` stamps endId locally and fires a
            // best-effort API sync; if `LocalHydration` pulls arrows back from
            // the server before that sync lands, the server payload's nil
            // endId would otherwise wipe the local stamp and break the
            // per-end breakdown in Session Detail on next launch.
            if let incomingEndId = arrow.endId {
                existing.endId = incomingEndId
            }
            existing.shotAt = arrow.shotAt
            existing.excluded = arrow.excluded
            existing.notes = arrow.notes
        } else {
            let record = PersistentArrowPlot.from(arrow)
            record.pendingSync = true
            context.insert(record)
        }
        try context.save()
    }

    func deleteArrow(id: String) throws {
        let predicate = #Predicate<PersistentArrowPlot> { $0.id == id }
        if let existing = try context.fetch(FetchDescriptor<PersistentArrowPlot>(predicate: predicate)).first {
            context.delete(existing)
            try context.save()
        }
    }

    func fetchArrows(since date: Date) throws -> [ArrowPlot] {
        let descriptor = FetchDescriptor<PersistentArrowPlot>(
            predicate: #Predicate { $0.shotAt >= date },
            sortBy: [SortDescriptor(\.shotAt)]
        )
        return try context.fetch(descriptor).map { $0.toDTO() }
    }

    func fetchAllArrows() throws -> [ArrowPlot] {
        let descriptor = FetchDescriptor<PersistentArrowPlot>(
            sortBy: [SortDescriptor(\.shotAt)]
        )
        return try context.fetch(descriptor).map { $0.toDTO() }
    }

    // MARK: - Ends

    func save(end: SessionEnd) throws {
        let id = end.id
        let predicate = #Predicate<PersistentEnd> { $0.id == id }
        let descriptor = FetchDescriptor<PersistentEnd>(predicate: predicate)
        if let existing = try context.fetch(descriptor).first {
            existing.sessionId = end.sessionId
            existing.endNumber = end.endNumber
            existing.notes = end.notes
            existing.completedAt = end.completedAt
        } else {
            context.insert(PersistentEnd.from(end))
        }
        try context.save()
    }

    // MARK: - Pending sync queries

    func fetchPendingBows() throws -> [Bow] {
        let descriptor = FetchDescriptor<PersistentBow>(
            predicate: #Predicate { $0.pendingSync == true },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor).map { $0.toDTO() }
    }

    func fetchPendingBowConfigs() throws -> [BowConfiguration] {
        let descriptor = FetchDescriptor<PersistentBowConfig>(
            predicate: #Predicate { $0.pendingSync == true },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor).map { $0.toDTO() }
    }

    func fetchPendingArrowConfigs() throws -> [ArrowConfiguration] {
        let descriptor = FetchDescriptor<PersistentArrowConfig>(
            predicate: #Predicate { $0.pendingSync == true },
            sortBy: [SortDescriptor(\.label)]
        )
        return try context.fetch(descriptor).map { $0.toDTO() }
    }

    func fetchPendingSessions() throws -> [ShootingSession] {
        let descriptor = FetchDescriptor<PersistentSession>(
            predicate: #Predicate { $0.pendingSync == true },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        return try context.fetch(descriptor).map { $0.toDTO() }
    }

    func fetchPendingPlots() throws -> [ArrowPlot] {
        let descriptor = FetchDescriptor<PersistentArrowPlot>(
            predicate: #Predicate { $0.pendingSync == true },
            sortBy: [SortDescriptor(\.shotAt)]
        )
        return try context.fetch(descriptor).map { $0.toDTO() }
    }

    func markBowSynced(id: String) throws {
        let predicate = #Predicate<PersistentBow> { $0.id == id }
        if let record = try context.fetch(FetchDescriptor(predicate: predicate)).first {
            record.pendingSync = false
            try context.save()
        }
    }

    func markBowConfigSynced(id: String) throws {
        let predicate = #Predicate<PersistentBowConfig> { $0.id == id }
        if let record = try context.fetch(FetchDescriptor(predicate: predicate)).first {
            record.pendingSync = false
            try context.save()
        }
    }

    func markArrowConfigSynced(id: String) throws {
        let predicate = #Predicate<PersistentArrowConfig> { $0.id == id }
        if let record = try context.fetch(FetchDescriptor(predicate: predicate)).first {
            record.pendingSync = false
            try context.save()
        }
    }

    func markSessionSynced(id: String) throws {
        let predicate = #Predicate<PersistentSession> { $0.id == id }
        if let record = try context.fetch(FetchDescriptor(predicate: predicate)).first {
            record.pendingSync = false
            try context.save()
        }
    }

    func markPlotSynced(id: String) throws {
        let predicate = #Predicate<PersistentArrowPlot> { $0.id == id }
        if let record = try context.fetch(FetchDescriptor(predicate: predicate)).first {
            record.pendingSync = false
            try context.save()
        }
    }

    // MARK: - Suggestions

    func fetchSuggestions() throws -> [AnalyticsSuggestion] {
        let descriptor = FetchDescriptor<PersistentSuggestion>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toDTO() }
    }

    func save(suggestion: AnalyticsSuggestion) throws {
        let id = suggestion.id
        let predicate = #Predicate<PersistentSuggestion> { $0.id == id }
        let descriptor = FetchDescriptor<PersistentSuggestion>(predicate: predicate)
        if let existing = try context.fetch(descriptor).first {
            existing.bowId = suggestion.bowId
            existing.createdAt = suggestion.createdAt
            existing.parameter = suggestion.parameter
            existing.suggestedValue = suggestion.suggestedValue
            existing.currentValue = suggestion.currentValue
            existing.reasoning = suggestion.reasoning
            existing.confidence = suggestion.confidence
            existing.qualifier = suggestion.qualifier
            existing.wasRead = suggestion.wasRead
            existing.deliveryTypeStr = suggestion.deliveryType.rawValue
        } else {
            context.insert(PersistentSuggestion.from(suggestion))
        }
        try context.save()
    }

    func markRead(suggestionId: String) throws {
        let predicate = #Predicate<PersistentSuggestion> { $0.id == suggestionId }
        let descriptor = FetchDescriptor<PersistentSuggestion>(predicate: predicate)
        if let existing = try context.fetch(descriptor).first {
            existing.wasRead = true
            try context.save()
        }
    }
}
