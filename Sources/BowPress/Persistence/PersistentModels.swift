import Foundation
import SwiftData

// MARK: - PersistentBow

@Model
final class PersistentBow {
    var id: String
    var userId: String
    var name: String
    var bowTypeStr: String = BowType.compound.rawValue
    var brand: String
    var model: String
    var createdAt: Date
    var pendingSync: Bool = false

    init(id: String, userId: String, name: String, bowTypeStr: String, brand: String, model: String, createdAt: Date) {
        self.id = id
        self.userId = userId
        self.name = name
        self.bowTypeStr = bowTypeStr
        self.brand = brand
        self.model = model
        self.createdAt = createdAt
    }

    func toDTO() -> Bow {
        Bow(
            id: id,
            userId: userId,
            name: name,
            bowType: BowType(rawValue: bowTypeStr) ?? .compound,
            brand: brand,
            model: model,
            createdAt: createdAt
        )
    }

    static func from(_ dto: Bow) -> PersistentBow {
        PersistentBow(
            id: dto.id,
            userId: dto.userId,
            name: dto.name,
            bowTypeStr: dto.bowType.rawValue,
            brand: dto.brand,
            model: dto.model,
            createdAt: dto.createdAt
        )
    }
}

// MARK: - PersistentBowConfig

@Model
final class PersistentBowConfig {
    var id: String
    var bowId: String
    var createdAt: Date
    var label: String?

    var drawLength: Double
    var letOffPct: Double
    var peepHeight: Double
    var dLoopLength: Double
    var topCableTwists: Int
    var bottomCableTwists: Int
    var mainStringTopTwists: Int
    var mainStringBottomTwists: Int
    var topLimbTurns: Double
    var bottomLimbTurns: Double

    var restVertical: Int
    var restHorizontal: Int
    var restDepth: Double

    var sightPosition: Int
    var gripAngle: Double
    var nockingHeight: Int

    var frontStabWeight: Double
    var frontStabAngle: Double
    var rearStabSideStr: String      // RearStabSide.rawValue
    var rearStabWeight: Double
    var rearStabVertAngle: Double
    var rearStabHorizAngle: Double

    var pendingSync: Bool = false

    init(
        id: String,
        bowId: String,
        createdAt: Date,
        label: String?,
        drawLength: Double,
        letOffPct: Double,
        peepHeight: Double,
        dLoopLength: Double,
        topCableTwists: Int,
        bottomCableTwists: Int,
        mainStringTopTwists: Int,
        mainStringBottomTwists: Int,
        topLimbTurns: Double,
        bottomLimbTurns: Double,
        restVertical: Int,
        restHorizontal: Int,
        restDepth: Double,
        sightPosition: Int,
        gripAngle: Double,
        nockingHeight: Int,
        frontStabWeight: Double,
        frontStabAngle: Double,
        rearStabSideStr: String,
        rearStabWeight: Double,
        rearStabVertAngle: Double,
        rearStabHorizAngle: Double
    ) {
        self.id = id
        self.bowId = bowId
        self.createdAt = createdAt
        self.label = label
        self.drawLength = drawLength
        self.letOffPct = letOffPct
        self.peepHeight = peepHeight
        self.dLoopLength = dLoopLength
        self.topCableTwists = topCableTwists
        self.bottomCableTwists = bottomCableTwists
        self.mainStringTopTwists = mainStringTopTwists
        self.mainStringBottomTwists = mainStringBottomTwists
        self.topLimbTurns = topLimbTurns
        self.bottomLimbTurns = bottomLimbTurns
        self.restVertical = restVertical
        self.restHorizontal = restHorizontal
        self.restDepth = restDepth
        self.sightPosition = sightPosition
        self.gripAngle = gripAngle
        self.nockingHeight = nockingHeight
        self.frontStabWeight = frontStabWeight
        self.frontStabAngle = frontStabAngle
        self.rearStabSideStr = rearStabSideStr
        self.rearStabWeight = rearStabWeight
        self.rearStabVertAngle = rearStabVertAngle
        self.rearStabHorizAngle = rearStabHorizAngle
    }

    func toDTO() -> BowConfiguration {
        BowConfiguration(
            id: id,
            bowId: bowId,
            createdAt: createdAt,
            label: label,
            drawLength: drawLength,
            letOffPct: letOffPct,
            peepHeight: peepHeight,
            dLoopLength: dLoopLength,
            topCableTwists: topCableTwists,
            bottomCableTwists: bottomCableTwists,
            mainStringTopTwists: mainStringTopTwists,
            mainStringBottomTwists: mainStringBottomTwists,
            topLimbTurns: topLimbTurns,
            bottomLimbTurns: bottomLimbTurns,
            restVertical: restVertical,
            restHorizontal: restHorizontal,
            restDepth: restDepth,
            sightPosition: sightPosition,
            gripAngle: gripAngle,
            nockingHeight: nockingHeight,
            frontStabWeight: frontStabWeight,
            frontStabAngle: frontStabAngle,
            rearStabSide: RearStabSide(rawValue: rearStabSideStr) ?? .none,
            rearStabWeight: rearStabWeight,
            rearStabVertAngle: rearStabVertAngle,
            rearStabHorizAngle: rearStabHorizAngle
        )
    }

    static func from(_ dto: BowConfiguration) -> PersistentBowConfig {
        PersistentBowConfig(
            id: dto.id,
            bowId: dto.bowId,
            createdAt: dto.createdAt,
            label: dto.label,
            drawLength: dto.drawLength,
            letOffPct: dto.letOffPct,
            peepHeight: dto.peepHeight,
            dLoopLength: dto.dLoopLength,
            topCableTwists: dto.topCableTwists,
            bottomCableTwists: dto.bottomCableTwists,
            mainStringTopTwists: dto.mainStringTopTwists,
            mainStringBottomTwists: dto.mainStringBottomTwists,
            topLimbTurns: dto.topLimbTurns,
            bottomLimbTurns: dto.bottomLimbTurns,
            restVertical: dto.restVertical,
            restHorizontal: dto.restHorizontal,
            restDepth: dto.restDepth,
            sightPosition: dto.sightPosition,
            gripAngle: dto.gripAngle,
            nockingHeight: dto.nockingHeight,
            frontStabWeight: dto.frontStabWeight,
            frontStabAngle: dto.frontStabAngle,
            rearStabSideStr: dto.rearStabSide.rawValue,
            rearStabWeight: dto.rearStabWeight,
            rearStabVertAngle: dto.rearStabVertAngle,
            rearStabHorizAngle: dto.rearStabHorizAngle
        )
    }
}

// MARK: - PersistentArrowConfig

@Model
final class PersistentArrowConfig {
    var id: String
    var userId: String
    var label: String
    var brand: String?
    var model: String?
    var length: Double
    var pointWeight: Int
    var fletchingTypeStr: String    // FletchingType.rawValue
    var fletchingLength: Double
    var fletchingOffset: Double
    var nockType: String?
    var totalWeight: Int?
    var shaftDiameterRaw: Double?   // ShaftDiameter.rawValue
    var notes: String?
    var pendingSync: Bool = false

    init(
        id: String,
        userId: String,
        label: String,
        brand: String?,
        model: String?,
        length: Double,
        pointWeight: Int,
        fletchingTypeStr: String,
        fletchingLength: Double,
        fletchingOffset: Double,
        nockType: String?,
        totalWeight: Int?,
        shaftDiameterRaw: Double?,
        notes: String?
    ) {
        self.id = id
        self.userId = userId
        self.label = label
        self.brand = brand
        self.model = model
        self.length = length
        self.pointWeight = pointWeight
        self.fletchingTypeStr = fletchingTypeStr
        self.fletchingLength = fletchingLength
        self.fletchingOffset = fletchingOffset
        self.nockType = nockType
        self.totalWeight = totalWeight
        self.shaftDiameterRaw = shaftDiameterRaw
        self.notes = notes
    }

    func toDTO() -> ArrowConfiguration {
        ArrowConfiguration(
            id: id,
            userId: userId,
            label: label,
            brand: brand,
            model: model,
            length: length,
            pointWeight: pointWeight,
            fletchingType: ArrowConfiguration.FletchingType(rawValue: fletchingTypeStr) ?? .vane,
            fletchingLength: fletchingLength,
            fletchingOffset: fletchingOffset,
            nockType: nockType,
            totalWeight: totalWeight,
            shaftDiameter: shaftDiameterRaw.flatMap { ArrowConfiguration.ShaftDiameter(rawValue: $0) },
            notes: notes
        )
    }

    static func from(_ dto: ArrowConfiguration) -> PersistentArrowConfig {
        PersistentArrowConfig(
            id: dto.id,
            userId: dto.userId,
            label: dto.label,
            brand: dto.brand,
            model: dto.model,
            length: dto.length,
            pointWeight: dto.pointWeight,
            fletchingTypeStr: dto.fletchingType.rawValue,
            fletchingLength: dto.fletchingLength,
            fletchingOffset: dto.fletchingOffset,
            nockType: dto.nockType,
            totalWeight: dto.totalWeight,
            shaftDiameterRaw: dto.shaftDiameter?.rawValue,
            notes: dto.notes
        )
    }
}

// MARK: - PersistentSession

@Model
final class PersistentSession {
    var id: String
    var bowId: String
    var bowConfigId: String
    var arrowConfigId: String
    var startedAt: Date
    var endedAt: Date?
    var notes: String
    var feelTagsJSON: String        // JSON-encoded [String]
    var arrowCount: Int
    var pendingSync: Bool = false

    init(
        id: String,
        bowId: String,
        bowConfigId: String,
        arrowConfigId: String,
        startedAt: Date,
        endedAt: Date?,
        notes: String,
        feelTagsJSON: String,
        arrowCount: Int
    ) {
        self.id = id
        self.bowId = bowId
        self.bowConfigId = bowConfigId
        self.arrowConfigId = arrowConfigId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.notes = notes
        self.feelTagsJSON = feelTagsJSON
        self.arrowCount = arrowCount
    }

    func toDTO() -> ShootingSession {
        let tags: [String]
        if let data = feelTagsJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            tags = decoded
        } else {
            tags = []
        }

        return ShootingSession(
            id: id,
            bowId: bowId,
            bowConfigId: bowConfigId,
            arrowConfigId: arrowConfigId,
            startedAt: startedAt,
            endedAt: endedAt,
            notes: notes,
            feelTags: tags,
            conditions: nil,
            arrowCount: arrowCount,
            ends: nil,
            arrows: nil
        )
    }

    static func from(_ dto: ShootingSession) -> PersistentSession {
        let tagsJSON: String
        if let data = try? JSONEncoder().encode(dto.feelTags),
           let str = String(data: data, encoding: .utf8) {
            tagsJSON = str
        } else {
            tagsJSON = "[]"
        }

        return PersistentSession(
            id: dto.id,
            bowId: dto.bowId,
            bowConfigId: dto.bowConfigId,
            arrowConfigId: dto.arrowConfigId,
            startedAt: dto.startedAt,
            endedAt: dto.endedAt,
            notes: dto.notes,
            feelTagsJSON: tagsJSON,
            arrowCount: dto.arrowCount
        )
    }
}

// MARK: - PersistentArrowPlot

@Model
final class PersistentArrowPlot {
    var id: String
    var sessionId: String
    var bowConfigId: String
    var arrowConfigId: String
    var ring: Int
    var zoneStr: String             // Zone.rawValue
    var plotX: Double?
    var plotY: Double?
    var endId: String?
    var shotAt: Date
    var excluded: Bool
    var notes: String?
    var pendingSync: Bool = false

    init(
        id: String,
        sessionId: String,
        bowConfigId: String,
        arrowConfigId: String,
        ring: Int,
        zoneStr: String,
        plotX: Double?,
        plotY: Double?,
        endId: String?,
        shotAt: Date,
        excluded: Bool,
        notes: String?
    ) {
        self.id = id
        self.sessionId = sessionId
        self.bowConfigId = bowConfigId
        self.arrowConfigId = arrowConfigId
        self.ring = ring
        self.zoneStr = zoneStr
        self.plotX = plotX
        self.plotY = plotY
        self.endId = endId
        self.shotAt = shotAt
        self.excluded = excluded
        self.notes = notes
    }

    func toDTO() -> ArrowPlot {
        ArrowPlot(
            id: id,
            sessionId: sessionId,
            bowConfigId: bowConfigId,
            arrowConfigId: arrowConfigId,
            ring: ring,
            zone: ArrowPlot.Zone(rawValue: zoneStr) ?? .center,
            plotX: plotX,
            plotY: plotY,
            endId: endId,
            shotAt: shotAt,
            excluded: excluded,
            notes: notes
        )
    }

    static func from(_ dto: ArrowPlot) -> PersistentArrowPlot {
        PersistentArrowPlot(
            id: dto.id,
            sessionId: dto.sessionId,
            bowConfigId: dto.bowConfigId,
            arrowConfigId: dto.arrowConfigId,
            ring: dto.ring,
            zoneStr: dto.zone.rawValue,
            plotX: dto.plotX,
            plotY: dto.plotY,
            endId: dto.endId,
            shotAt: dto.shotAt,
            excluded: dto.excluded,
            notes: dto.notes
        )
    }
}

// MARK: - PersistentEnd

@Model
final class PersistentEnd {
    var id: String
    var sessionId: String
    var endNumber: Int
    var notes: String?
    var completedAt: Date

    init(id: String, sessionId: String, endNumber: Int, notes: String?, completedAt: Date) {
        self.id = id
        self.sessionId = sessionId
        self.endNumber = endNumber
        self.notes = notes
        self.completedAt = completedAt
    }

    func toDTO() -> SessionEnd {
        SessionEnd(id: id, sessionId: sessionId, endNumber: endNumber, notes: notes, completedAt: completedAt)
    }

    static func from(_ dto: SessionEnd) -> PersistentEnd {
        PersistentEnd(
            id: dto.id,
            sessionId: dto.sessionId,
            endNumber: dto.endNumber,
            notes: dto.notes,
            completedAt: dto.completedAt
        )
    }
}

// MARK: - PersistentSuggestion

@Model
final class PersistentSuggestion {
    var id: String
    var bowId: String
    var createdAt: Date
    var parameter: String
    var suggestedValue: String
    var currentValue: String
    var reasoning: String
    var confidence: Double
    var qualifier: String?
    var wasRead: Bool
    var wasDismissed: Bool = false
    var deliveryTypeStr: String     // DeliveryType.rawValue

    init(
        id: String,
        bowId: String,
        createdAt: Date,
        parameter: String,
        suggestedValue: String,
        currentValue: String,
        reasoning: String,
        confidence: Double,
        qualifier: String?,
        wasRead: Bool,
        wasDismissed: Bool,
        deliveryTypeStr: String
    ) {
        self.id = id
        self.bowId = bowId
        self.createdAt = createdAt
        self.parameter = parameter
        self.suggestedValue = suggestedValue
        self.currentValue = currentValue
        self.reasoning = reasoning
        self.confidence = confidence
        self.qualifier = qualifier
        self.wasRead = wasRead
        self.wasDismissed = wasDismissed
        self.deliveryTypeStr = deliveryTypeStr
    }

    func toDTO() -> AnalyticsSuggestion {
        AnalyticsSuggestion(
            id: id,
            bowId: bowId,
            createdAt: createdAt,
            parameter: parameter,
            suggestedValue: suggestedValue,
            currentValue: currentValue,
            reasoning: reasoning,
            confidence: confidence,
            qualifier: qualifier,
            wasRead: wasRead,
            wasDismissed: wasDismissed,
            deliveryType: AnalyticsSuggestion.DeliveryType(rawValue: deliveryTypeStr) ?? .inApp
        )
    }

    static func from(_ dto: AnalyticsSuggestion) -> PersistentSuggestion {
        PersistentSuggestion(
            id: dto.id,
            bowId: dto.bowId,
            createdAt: dto.createdAt,
            parameter: dto.parameter,
            suggestedValue: dto.suggestedValue,
            currentValue: dto.currentValue,
            reasoning: dto.reasoning,
            confidence: dto.confidence,
            qualifier: dto.qualifier,
            wasRead: dto.wasRead,
            wasDismissed: dto.wasDismissed,
            deliveryTypeStr: dto.deliveryType.rawValue
        )
    }
}
