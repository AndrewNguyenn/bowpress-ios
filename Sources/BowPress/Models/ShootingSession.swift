import Foundation

struct ShootingSession: Identifiable, Codable, Equatable {
    var id: String
    var bowId: String
    var bowConfigId: String
    var arrowConfigId: String
    var startedAt: Date
    var endedAt: Date?
    var notes: String
    var feelTags: [String]
    var conditions: SessionConditions?
    var arrowCount: Int
    var ends: [SessionEnd]?
    var arrows: [ArrowPlot]?
    /// Which target face this session was shot on. Defaults to `.sixRing` when
    /// missing so legacy rows (which predate this field) decode with the
    /// compound 6-ring geometry their ring values were recorded against.
    var targetFaceType: TargetFaceType
    /// Distance from the shooter to the target. Optional — sessions that
    /// predate the field, or where the user didn't pick a distance, stay nil.
    var distance: ShootingDistance?
    /// Short archer-authored session name ("Morning range", "Pre-comp tune").
    /// Server side lives in `shooting_sessions.title` (migration 0018); nil
    /// when untitled, in which case the UI falls back to a distance template.
    var title: String?

    enum CodingKeys: String, CodingKey {
        case id, bowId, bowConfigId, arrowConfigId
        case startedAt, endedAt, notes, feelTags
        case conditions, arrowCount, ends, arrows
        case targetFaceType, distance, title
    }

    init(
        id: String,
        bowId: String,
        bowConfigId: String,
        arrowConfigId: String,
        startedAt: Date,
        endedAt: Date?,
        notes: String,
        feelTags: [String],
        conditions: SessionConditions? = nil,
        arrowCount: Int,
        ends: [SessionEnd]? = nil,
        arrows: [ArrowPlot]? = nil,
        targetFaceType: TargetFaceType = .sixRing,
        distance: ShootingDistance? = nil,
        title: String? = nil
    ) {
        self.id = id
        self.bowId = bowId
        self.bowConfigId = bowConfigId
        self.arrowConfigId = arrowConfigId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.notes = notes
        self.feelTags = feelTags
        self.conditions = conditions
        self.arrowCount = arrowCount
        self.ends = ends
        self.arrows = arrows
        self.targetFaceType = targetFaceType
        self.distance = distance
        self.title = title
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        bowId = try c.decode(String.self, forKey: .bowId)
        bowConfigId = try c.decode(String.self, forKey: .bowConfigId)
        arrowConfigId = try c.decode(String.self, forKey: .arrowConfigId)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt)
        notes = try c.decode(String.self, forKey: .notes)
        feelTags = try c.decode([String].self, forKey: .feelTags)
        conditions = try c.decodeIfPresent(SessionConditions.self, forKey: .conditions)
        arrowCount = try c.decode(Int.self, forKey: .arrowCount)
        ends = try c.decodeIfPresent([SessionEnd].self, forKey: .ends)
        arrows = try c.decodeIfPresent([ArrowPlot].self, forKey: .arrows)
        targetFaceType = try c.decodeIfPresent(TargetFaceType.self, forKey: .targetFaceType) ?? .sixRing
        distance = try c.decodeIfPresent(ShootingDistance.self, forKey: .distance)
        title = try c.decodeIfPresent(String.self, forKey: .title)
    }
}

struct SessionConditions: Codable, Equatable {
    var windSpeed: Double?
    var tempF: Double?
    var lighting: String?
}
