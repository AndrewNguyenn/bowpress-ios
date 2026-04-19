import Foundation

enum BowType: String, Codable, CaseIterable {
    case compound, recurve, barebow

    var label: String { rawValue.capitalized }
}

struct Bow: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var userId: String
    var name: String
    var bowType: BowType
    var brand: String
    var model: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, userId, name, bowType, brand, model, createdAt
    }

    init(id: String, userId: String, name: String, bowType: BowType = .compound, brand: String = "", model: String = "", createdAt: Date) {
        self.id = id
        self.userId = userId
        self.name = name
        self.bowType = bowType
        self.brand = brand
        self.model = model
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        userId = try c.decode(String.self, forKey: .userId)
        name = try c.decode(String.self, forKey: .name)
        bowType = try c.decodeIfPresent(BowType.self, forKey: .bowType) ?? .compound
        brand = try c.decodeIfPresent(String.self, forKey: .brand) ?? ""
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }
}
