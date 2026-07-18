import XCTest
@testable import UncertaintyScoreKit

final class UncertaintyScoreTests: XCTestCase {

    // Grounded: a span a lane never assessed is BLANK, not settled. The two facts stay distinct.
    func testAbsenceIsExplicitNotSettled() {
        let lane = UncertaintyLane(id: "grd", title: "Grounding", notes: [
            UncertaintyNote(id: "n1", start: 1, end: 10, state: .settled, detail: "read")
        ])
        XCTAssertNotNil(lane.note(at: 5), "assessed span carries a note")
        XCTAssertNil(lane.note(at: 15), "unassessed span is blank, never an implicit settled")
    }

    // Failure must draw the eye: one breakdown in a column outweighs a crowd of mild ambiguities.
    func testFailureDominatesOpenness() {
        let failing = UncertaintyScore(title: "t", spineStart: 1, spineEnd: 10, itemCount: 1, lanes: [
            UncertaintyLane(id: "a", title: "A", isFailureAxis: true,
                            notes: [UncertaintyNote(id: "f", start: 1, end: 10, state: .failure)]),
            UncertaintyLane(id: "b", title: "B", notes: [UncertaintyNote(id: "s", start: 1, end: 10, state: .settled)])
        ])
        let ambiguous = UncertaintyScore(title: "t", spineStart: 1, spineEnd: 10, itemCount: 1, lanes: [
            UncertaintyLane(id: "a", title: "A", notes: [UncertaintyNote(id: "x", start: 1, end: 10, state: .thin)]),
            UncertaintyLane(id: "b", title: "B", notes: [UncertaintyNote(id: "y", start: 1, end: 10, state: .thin)])
        ])
        XCTAssertGreaterThan(failing.openness(at: 5), ambiguous.openness(at: 5))
        XCTAssertGreaterThanOrEqual(failing.openness(at: 5), UncertaintyState.failure.weight * 0.9)
    }

    // The states are ordered by attention owed — the whole model leans on this ranking.
    func testStateWeightOrdering() {
        XCTAssertLessThan(UncertaintyState.settled.weight, UncertaintyState.thin.weight)
        XCTAssertLessThan(UncertaintyState.thin.weight, UncertaintyState.ambiguity.weight)
        XCTAssertLessThan(UncertaintyState.ambiguity.weight, UncertaintyState.failure.weight)
    }

    // Magnitude defaults to the state's weight and never exceeds 1.
    func testMagnitudeDefaultsAndClamps() {
        XCTAssertEqual(UncertaintyNote(id: "d", start: 1, end: 2, state: .ambiguity).magnitude,
                       UncertaintyState.ambiguity.weight, accuracy: 0.0001)
        XCTAssertEqual(UncertaintyNote(id: "c", start: 1, end: 2, state: .failure, magnitude: 9).magnitude, 1)
        XCTAssertEqual(UncertaintyNote(id: "z", start: 1, end: 2, state: .failure, magnitude: -3).magnitude, 0)
    }

    // A backwards span is normalized rather than trusted.
    func testSpanNormalized() {
        let n = UncertaintyNote(id: "s", start: 20, end: 4, state: .thin)
        XCTAssertEqual(n.start, 4)
        XCTAssertEqual(n.end, 20)
    }

    func testPeakStateIsWorst() {
        let lane = UncertaintyLane(id: "l", title: "L", notes: [
            UncertaintyNote(id: "1", start: 1, end: 2, state: .settled),
            UncertaintyNote(id: "2", start: 3, end: 4, state: .ambiguity),
            UncertaintyNote(id: "3", start: 5, end: 6, state: .thin)
        ])
        XCTAssertEqual(lane.peakState, .ambiguity)
    }
}
