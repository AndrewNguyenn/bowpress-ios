import Foundation
import SwiftUI

struct BowCatalog: Codable {
    var manufacturers: [CatalogManufacturer]
}

struct CatalogManufacturer: Identifiable, Codable {
    var id: String
    var name: String
    var models: [CatalogModel]
}

struct CatalogModel: Identifiable, Codable {
    var id: String
    var name: String
    var ata: Double
    var braceHeight: Double
    var weight: Double
    var iboSpeed: Int
    var drawLengthMin: Double
    var drawLengthMax: Double
    var letOffOptions: [Int]
    var drawWeightOptions: [Int]
    var colors: [CatalogColor]
}

struct CatalogColor: Identifiable, Codable {
    var id: String
    var name: String
    var hex: String
    var imageUrl: String?         // populated when licensed images are on R2

    var swatchColor: Color {
        Color(hex: hex)
    }
}

// MARK: - Loader

final class BowCatalogLoader {
    static let shared = BowCatalogLoader()

    private(set) var catalog: BowCatalog = BowCatalog(manufacturers: [])

    private init() {
        guard let url = Bundle.main.url(forResource: "BowCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(BowCatalog.self, from: data)
        else { return }
        catalog = decoded
    }

    var manufacturers: [CatalogManufacturer] { catalog.manufacturers }

    func manufacturer(id: String) -> CatalogManufacturer? {
        catalog.manufacturers.first { $0.id == id }
    }

    func model(id: String) -> CatalogModel? {
        catalog.manufacturers.flatMap(\.models).first { $0.id == id }
    }

    func models(for manufacturerId: String) -> [CatalogModel] {
        manufacturer(id: manufacturerId)?.models ?? []
    }
}

// MARK: - Color hex init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
