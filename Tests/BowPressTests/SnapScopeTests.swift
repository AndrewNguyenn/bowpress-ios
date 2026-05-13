import XCTest
@testable import BowPress

/// Pins the scope of `TargetGeometry.snappedPosition`: it must only be
/// called from the ArrowEditSheet chip handler — never on initial plot,
/// drag-to-replot, tap-to-replot, or anything inside SessionDetailSheet.
///
/// The bug this guards against (issue #11): the snap moves a dot under
/// the archer's feet to keep the plotted color matched to the new score.
/// That behaviour is correct *only* when the score changed via a chip and
/// the archer didn't re-place the dot themselves. Routing any other path
/// through `snappedPosition` would reintroduce "my arrows aren't where I
/// plotted them," the original symptom that took two sessions to chase
/// down (commits c443455 → e8e46ea).
///
/// Mechanism: scan all .swift files under Sources/BowPress and assert the
/// only production references to `snappedPosition(` are the definition in
/// TargetPlotView.swift and exactly one caller in SessionView.swift. A
/// new caller fails this test loudly; a refactor that legitimately moves
/// the chip handler to a new file fails too, forcing the author to update
/// the allowlist explicitly and confirm the new site really is a chip
/// path. That's the intended cost of the contract.
final class SnapScopeTests: XCTestCase {

    /// Files allowed to mention `snappedPosition(`. Update this list ONLY
    /// when adding a chip-style handler, and document why in the issue or
    /// commit message — silent additions defeat the test's purpose.
    private static let allowedCallers: Set<String> = [
        "TargetPlotView.swift",   // definition
        "SessionView.swift",      // ArrowEditSheet chip handler (issue #13 fix wired through)
    ]

    func test_snappedPosition_onlyReachableFromAllowedCallers() throws {
        let sourcesDir = Self.sourcesRoot()
        let swiftFiles = try Self.recursiveSwiftFiles(under: sourcesDir)
        XCTAssertFalse(swiftFiles.isEmpty,
                       "couldn't locate Sources/BowPress/**/*.swift from \(sourcesDir.path)")

        var unauthorizedHits: [String] = []
        for url in swiftFiles {
            let contents = try String(contentsOf: url, encoding: .utf8)
            guard contents.contains("snappedPosition(") else { continue }
            let name = url.lastPathComponent
            if !Self.allowedCallers.contains(name) {
                unauthorizedHits.append(name)
            }
        }

        XCTAssertTrue(
            unauthorizedHits.isEmpty,
            "snappedPosition leaked outside its intended scope. New caller(s) in: " +
            "\(unauthorizedHits.joined(separator: ", ")). " +
            "If the new site is a chip-style handler (not initial plot, drag, tap-replot, " +
            "or anything in SessionDetailSheet), add it to SnapScopeTests.allowedCallers " +
            "with a comment explaining why. Otherwise the snap will yank the archer's " +
            "dot — re-read issue #11 and commits c443455 / e8e46ea before adding it."
        )
    }

    /// Counts the actual call sites (not just files mentioning the name).
    /// Catches the case where someone duplicates the chip-handler logic
    /// inside an allowed file — e.g., adding a second `snappedPosition`
    /// call in SessionView.swift outside the chip closure.
    func test_snappedPosition_hasExactlyOneCallerOutsideTargetPlotView() throws {
        let sourcesDir = Self.sourcesRoot()
        let swiftFiles = try Self.recursiveSwiftFiles(under: sourcesDir)

        var callerCount = 0
        for url in swiftFiles where url.lastPathComponent != "TargetPlotView.swift" {
            let contents = try String(contentsOf: url, encoding: .utf8)
            callerCount += contents.components(separatedBy: ".snappedPosition(").count - 1
        }

        XCTAssertEqual(
            callerCount, 1,
            "expected exactly one call to .snappedPosition outside TargetPlotView.swift " +
            "(the ArrowEditSheet chip handler); found \(callerCount). " +
            "See test_snappedPosition_onlyReachableFromAllowedCallers for context."
        )
    }

    // MARK: - Helpers

    private static func sourcesRoot() -> URL {
        // #filePath is .../Tests/BowPressTests/SnapScopeTests.swift
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // BowPressTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // project root
            .appendingPathComponent("Sources/BowPress")
    }

    private static func recursiveSwiftFiles(under root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var result: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            result.append(url)
        }
        return result
    }
}
