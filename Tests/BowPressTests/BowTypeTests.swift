import XCTest
@testable import BowPress

/// Tests the bow-type enum, back-compat decoding, and type-aware defaults.
final class BowTypeTests: XCTestCase {

    // MARK: - BowType enum

    func test_bowType_allCases_orderAndValues() {
        XCTAssertEqual(BowType.allCases, [.compound, .recurve, .barebow])
        XCTAssertEqual(BowType.compound.rawValue, "compound")
        XCTAssertEqual(BowType.recurve.rawValue, "recurve")
        XCTAssertEqual(BowType.barebow.rawValue, "barebow")
    }

    func test_bowType_label_isCapitalized() {
        XCTAssertEqual(BowType.compound.label, "Compound")
        XCTAssertEqual(BowType.recurve.label, "Recurve")
        XCTAssertEqual(BowType.barebow.label, "Barebow")
    }

    // MARK: - Back-compat decoding

    func test_bowDecoding_missingBowType_defaultsToCompound() throws {
        // Simulates a response from a pre-bowType backend.
        let legacyJSON = """
        {
          "id": "b1",
          "userId": "u1",
          "name": "Legacy Bow",
          "brand": "Hoyt",
          "model": "RX-8",
          "createdAt": "2024-01-15T12:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bow = try decoder.decode(Bow.self, from: legacyJSON)

        XCTAssertEqual(bow.bowType, .compound)
        XCTAssertEqual(bow.name, "Legacy Bow")
    }

    func test_bowEncoding_roundTrip_preservesBowType() throws {
        for type in BowType.allCases {
            let original = Bow(
                id: "b1", userId: "u1", name: "Test",
                bowType: type,
                brand: "", model: "",
                createdAt: Date(timeIntervalSince1970: 1_700_000_000)
            )

            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            let data = try enc.encode(original)

            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            let decoded = try dec.decode(Bow.self, from: data)

            XCTAssertEqual(decoded.bowType, type, "round-trip failed for \(type.rawValue)")
            XCTAssertEqual(decoded.name, "Test")
        }
    }

    // MARK: - makeDefault per bow type

    // Contract: makeDefault populates the RIGHT SET of fields per bow type.
    // We don't lock specific numeric defaults — a designer can change e.g.
    // letOffPct=80 → 85 without breaking behavior. We lock:
    //   (a) bowId wiring,
    //   (b) which optional fields are populated (non-nil) vs must stay nil.

    func test_makeDefault_compound_populatesCompoundFields() {
        let bow = Bow(id: "b1", userId: "u1", name: "C", bowType: .compound, createdAt: Date())
        let cfg = BowConfiguration.makeDefault(for: bow)

        XCTAssertEqual(cfg.bowId, "b1")
        XCTAssertGreaterThan(cfg.drawLength, 0, "drawLength must default to a plausible value")
        // Compound-only fields populated
        XCTAssertNotNil(cfg.letOffPct)
        XCTAssertNotNil(cfg.peepHeight)
        XCTAssertNotNil(cfg.dLoopLength)
        XCTAssertEqual(cfg.rearStabSide, RearStabSide.none)
        // Recurve-only fields must be nil
        XCTAssertNil(cfg.braceHeight)
        XCTAssertNil(cfg.tillerTop)
        XCTAssertNil(cfg.clickerPosition)
        XCTAssertNil(cfg.rearStabLeftWeight)
    }

    func test_makeDefault_recurve_populatesRecurveFields() {
        let bow = Bow(id: "b2", userId: "u1", name: "R", bowType: .recurve, createdAt: Date())
        let cfg = BowConfiguration.makeDefault(for: bow)

        XCTAssertGreaterThan(cfg.drawLength, 0)
        // Recurve-specific fields populated
        XCTAssertNotNil(cfg.braceHeight)
        XCTAssertNotNil(cfg.tillerTop)
        XCTAssertNotNil(cfg.tillerBottom)
        XCTAssertNotNil(cfg.plungerTension)
        XCTAssertNotNil(cfg.clickerPosition)
        XCTAssertNotNil(cfg.frontStabWeight)
        XCTAssertNotNil(cfg.rearStabLeftWeight)
        XCTAssertNotNil(cfg.rearStabRightWeight)
        // V-bar shared angles (recurve now has them, like compound)
        XCTAssertNotNil(cfg.rearStabVertAngle)
        XCTAssertNotNil(cfg.rearStabHorizAngle)
        // Recurve has a sight (unlike barebow)
        XCTAssertNotNil(cfg.sightPosition)
        // Compound-only fields must be nil
        XCTAssertNil(cfg.letOffPct)
        XCTAssertNil(cfg.peepHeight)
        XCTAssertNil(cfg.dLoopLength)
        XCTAssertNil(cfg.topCableTwists)
        XCTAssertNil(cfg.topLimbTurns)
        XCTAssertNil(cfg.rearStabSide)
    }

    func test_makeDefault_barebow_populatesMinimalFields() {
        let bow = Bow(id: "b3", userId: "u1", name: "B", bowType: .barebow, createdAt: Date())
        let cfg = BowConfiguration.makeDefault(for: bow)

        XCTAssertGreaterThan(cfg.drawLength, 0)
        XCTAssertNotNil(cfg.braceHeight)
        XCTAssertNotNil(cfg.tillerTop)
        XCTAssertNotNil(cfg.tillerBottom)
        XCTAssertNotNil(cfg.plungerTension)
        // Clicker must be nil for barebow
        XCTAssertNil(cfg.clickerPosition)
        // No sight for barebow
        XCTAssertNil(cfg.sightPosition)
        // No stabilizers for barebow
        XCTAssertNil(cfg.frontStabWeight)
        XCTAssertNil(cfg.rearStabLeftWeight)
        XCTAssertNil(cfg.rearStabRightWeight)
        // Compound fields nil
        XCTAssertNil(cfg.letOffPct)
        XCTAssertNil(cfg.topCableTwists)
        XCTAssertNil(cfg.rearStabSide)
    }

    // MARK: - Serialization omits nil optionals

    func test_recurveConfigJSON_omitsCompoundFields() throws {
        let bow = Bow(id: "b2", userId: "u1", name: "R", bowType: .recurve, createdAt: Date())
        let cfg = BowConfiguration.makeDefault(for: bow)

        let data = try JSONEncoder().encode(cfg)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        // Must include recurve fields
        XCTAssertTrue(json.contains("\"braceHeight\""), "recurve config must include braceHeight")
        XCTAssertTrue(json.contains("\"tillerTop\""))
        XCTAssertTrue(json.contains("\"plungerTension\""))
        XCTAssertTrue(json.contains("\"clickerPosition\""))
        XCTAssertTrue(json.contains("\"rearStabLeftWeight\""))

        // Must omit compound-only keys (nil optionals are dropped by default JSONEncoder)
        XCTAssertFalse(json.contains("\"letOffPct\""), "recurve payload must not include letOffPct")
        XCTAssertFalse(json.contains("\"peepHeight\""))
        XCTAssertFalse(json.contains("\"dLoopLength\""))
        XCTAssertFalse(json.contains("\"topCableTwists\""))
        XCTAssertFalse(json.contains("\"topLimbTurns\""))
        XCTAssertFalse(json.contains("\"rearStabSide\""))
    }

    func test_barebowConfigJSON_omitsStabilizersAndClicker() throws {
        let bow = Bow(id: "b3", userId: "u1", name: "B", bowType: .barebow, createdAt: Date())
        let cfg = BowConfiguration.makeDefault(for: bow)

        let data = try JSONEncoder().encode(cfg)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(json.contains("\"braceHeight\""))
        XCTAssertTrue(json.contains("\"tillerTop\""))
        XCTAssertTrue(json.contains("\"plungerTension\""))

        XCTAssertFalse(json.contains("\"clickerPosition\""), "barebow must not include clicker")
        XCTAssertFalse(json.contains("\"frontStabWeight\""), "barebow must not include front stab")
        XCTAssertFalse(json.contains("\"rearStabLeftWeight\""), "barebow must not include V-bar")
        XCTAssertFalse(json.contains("\"rearStabRightWeight\""))
    }

    func test_compoundConfigJSON_omitsRecurveFields() throws {
        let bow = Bow(id: "b1", userId: "u1", name: "C", bowType: .compound, createdAt: Date())
        let cfg = BowConfiguration.makeDefault(for: bow)

        let data = try JSONEncoder().encode(cfg)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        // Compound fields present
        XCTAssertTrue(json.contains("\"letOffPct\""))
        XCTAssertTrue(json.contains("\"rearStabSide\""))

        // Recurve fields omitted
        XCTAssertFalse(json.contains("\"braceHeight\""))
        XCTAssertFalse(json.contains("\"tillerTop\""))
        XCTAssertFalse(json.contains("\"clickerPosition\""))
        XCTAssertFalse(json.contains("\"rearStabLeftWeight\""))
    }

    // MARK: - Round-trip through the legacy String-based makeDefault

    func test_makeDefaultByString_returnsCompoundDefaults() {
        let cfg = BowConfiguration.makeDefault(for: "placeholder-id")
        XCTAssertEqual(cfg.bowId, "placeholder-id")
        XCTAssertNotNil(cfg.letOffPct)
        XCTAssertNil(cfg.braceHeight)
    }
}
