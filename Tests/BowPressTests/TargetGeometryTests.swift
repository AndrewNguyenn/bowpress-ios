import XCTest
@testable import BowPress

/// Ring-boundary coverage for both face presets.
/// The compound `sixRing` preset keeps the exact historical thresholds, so
/// legacy sessions remain interpretable; the `tenRing` preset is the standard
/// WA 10-ring face with equal-width rings.
final class TargetGeometryTests: XCTestCase {

    // MARK: - TargetFaceType

    func test_faceType_rawValues_areStable() {
        XCTAssertEqual(TargetFaceType.sixRing.rawValue, "six_ring")
        XCTAssertEqual(TargetFaceType.tenRing.rawValue, "ten_ring")
    }

    func test_defaultFor_compound_isSixRing() {
        XCTAssertEqual(TargetFaceType.defaultFor(.compound), .sixRing)
    }

    func test_defaultFor_recurveAndBarebow_isTenRing() {
        XCTAssertEqual(TargetFaceType.defaultFor(.recurve), .tenRing)
        XCTAssertEqual(TargetFaceType.defaultFor(.barebow), .tenRing)
    }

    // MARK: - sixRing geometry (historical)

    func test_sixRing_xRing_hitsAtCentre() {
        let geo = TargetGeometry.sixRing
        XCTAssertEqual(geo.ring(for: 0.0), 11)
        XCTAssertEqual(geo.ring(for: 0.04), 11)
        // xRadius = 60/735 ≈ 0.0816
        XCTAssertEqual(geo.ring(for: 0.08), 11)
    }

    func test_sixRing_ring10_boundary() {
        let geo = TargetGeometry.sixRing
        // xRadius ≈ 0.0816 → still X just below
        XCTAssertEqual(geo.ring(for: 0.082), 10,
                       "just outside X should score 10")
        // r10Radius = 119/735 ≈ 0.1619
        XCTAssertEqual(geo.ring(for: 0.15), 10)
    }

    func test_sixRing_ringMidValues() {
        let geo = TargetGeometry.sixRing
        XCTAssertEqual(geo.ring(for: 0.20), 9)   // between 119 and 238
        XCTAssertEqual(geo.ring(for: 0.40), 8)   // between 238 and 357
        XCTAssertEqual(geo.ring(for: 0.55), 7)   // between 357 and 475
        XCTAssertEqual(geo.ring(for: 0.70), 6)   // between 475 and 594
    }

    func test_sixRing_miss_isNil() {
        let geo = TargetGeometry.sixRing
        // Outside 594/735 ≈ 0.808 is a miss.
        XCTAssertNil(geo.ring(for: 0.81))
        XCTAssertNil(geo.ring(for: 0.95))
        XCTAssertNil(geo.ring(for: 1.0))
        XCTAssertNil(geo.ring(for: 1.5))
    }

    func test_sixRing_outerRing_lastScoringRing() {
        let geo = TargetGeometry.sixRing
        // Just inside the outer ring-6 edge should still score 6.
        XCTAssertEqual(geo.ring(for: 0.80), 6)
    }

    // MARK: - tenRing geometry (standard WA)

    func test_tenRing_xRing_hitsAtCentre() {
        let geo = TargetGeometry.tenRing
        XCTAssertEqual(geo.ring(for: 0.0), 11)
        XCTAssertEqual(geo.ring(for: 0.04), 11)
        // xRadius = 0.05 exactly, half-open below.
        XCTAssertEqual(geo.ring(for: 0.049), 11)
    }

    func test_tenRing_ring10_boundary() {
        let geo = TargetGeometry.tenRing
        // 0.05 is the X outer boundary — on/above scores 10.
        XCTAssertEqual(geo.ring(for: 0.05), 10)
        XCTAssertEqual(geo.ring(for: 0.09), 10)
    }

    func test_tenRing_intermediateRings() {
        let geo = TargetGeometry.tenRing
        // Equal-width rings: each band is 0.10 wide.
        XCTAssertEqual(geo.ring(for: 0.15), 9)
        XCTAssertEqual(geo.ring(for: 0.25), 8)
        XCTAssertEqual(geo.ring(for: 0.35), 7)
        XCTAssertEqual(geo.ring(for: 0.45), 6)
        XCTAssertEqual(geo.ring(for: 0.55), 5)
        XCTAssertEqual(geo.ring(for: 0.65), 4)
        XCTAssertEqual(geo.ring(for: 0.75), 3)
        XCTAssertEqual(geo.ring(for: 0.85), 2)
        XCTAssertEqual(geo.ring(for: 0.95), 1)
    }

    func test_tenRing_outerRing1_lastScoringRing() {
        let geo = TargetGeometry.tenRing
        // Just inside the outer edge still scores 1.
        XCTAssertEqual(geo.ring(for: 0.99), 1)
    }

    func test_tenRing_miss_isNil() {
        let geo = TargetGeometry.tenRing
        // Exactly 1.0 and beyond is a miss (outer ring is rings[0] = 1.0 exclusive).
        XCTAssertNil(geo.ring(for: 1.0))
        XCTAssertNil(geo.ring(for: 1.01))
        XCTAssertNil(geo.ring(for: 2.0))
    }

    // MARK: - Preset lookup

    func test_preset_returnsMatchingGeometry() {
        XCTAssertEqual(TargetGeometry.preset(for: .sixRing).faceType, .sixRing)
        XCTAssertEqual(TargetGeometry.preset(for: .tenRing).faceType, .tenRing)
    }

    // MARK: - ShootingSession back-compat decoding

    func test_sessionDecoding_missingTargetFaceType_defaultsToSixRing() throws {
        let legacyJSON = """
        {
          "id": "s1",
          "bowId": "b1",
          "bowConfigId": "bc1",
          "arrowConfigId": "a1",
          "startedAt": "2024-01-15T12:00:00Z",
          "endedAt": null,
          "notes": "",
          "feelTags": [],
          "arrowCount": 0
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let session = try decoder.decode(ShootingSession.self, from: legacyJSON)

        XCTAssertEqual(session.targetFaceType, .sixRing,
                       "legacy sessions without the field must decode as sixRing")
    }

    func test_sessionEncoding_roundTrip_preservesTargetFaceType() throws {
        for face in TargetFaceType.allCases {
            let session = ShootingSession(
                id: "s1", bowId: "b1", bowConfigId: "bc1", arrowConfigId: "a1",
                startedAt: Date(timeIntervalSince1970: 1_700_000_000),
                endedAt: nil, notes: "", feelTags: [], arrowCount: 0,
                targetFaceType: face
            )

            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            let data = try enc.encode(session)

            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            let decoded = try dec.decode(ShootingSession.self, from: data)

            XCTAssertEqual(decoded.targetFaceType, face,
                           "round-trip failed for \(face.rawValue)")
        }
    }
}
