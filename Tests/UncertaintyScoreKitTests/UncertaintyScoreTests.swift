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

// MARK: - A lane of things with lives (braid)

/// A braid lane carries several things running at once — questions a story holds open, say — and the whole point is
/// that they overlap. These are about the packing that keeps them from being drawn on top of each other.
final class BraidLaneTests: XCTestCase {

    private func note(_ id: String, _ start: Int, _ end: Int, open: Bool = false) -> UncertaintyNote {
        .init(id: id, start: start, end: end, state: .ambiguity, detail: "q\(id)", continuesPastEnd: open)
    }

    func testThingsAliveAtOnceGetRowsOfTheirOwn() {
        let lane = UncertaintyLane(id: "beats", title: "Beats", notes: [
            note("a", 1, 100), note("b", 40, 200), note("c", 60, 90)
        ], presentation: .braid)
        XCTAssertEqual(lane.rows.count, 3, "Three questions alive at l. 60 is three rows, never one smear.")
    }

    func testThingsThatNeverOverlapShareARow() {
        let lane = UncertaintyLane(id: "beats", title: "Beats", notes: [
            note("a", 1, 50), note("b", 60, 100), note("c", 110, 160)
        ], presentation: .braid)
        XCTAssertEqual(lane.rows.count, 1, "A sequence of finished questions is one row — depth of one.")
        XCTAssertEqual(lane.rows[0].count, 3)
    }

    func testRowsCoverEveryNoteExactlyOnce() {
        let notes = [note("a", 1, 100), note("b", 40, 200), note("c", 60, 90), note("d", 210, 260)]
        let lane = UncertaintyLane(id: "beats", title: "Beats", notes: notes, presentation: .braid)
        let packed = lane.rows.flatMap { $0 }.map(\.id).sorted()
        XCTAssertEqual(packed, ["a", "b", "c", "d"], "Packing may reorder, never lose or duplicate.")
    }

    func testAScoreWrittenBeforeTheseFieldsExistedStillReads() throws {
        // A stored map is the record of a reading that happened; a new field must not make an old reading unreadable.
        let legacy = """
        {"title":"This reading","spineStart":1,"spineEnd":500,"itemCount":2,
         "lanes":[{"id":"l","title":"Structure read","isFailureAxis":false,
           "notes":[{"id":"n","start":1,"end":40,"state":"ambiguity","magnitude":0.7,"detail":"unsettled"}]}]}
        """
        let score = try JSONDecoder().decode(UncertaintyScore.self, from: Data(legacy.utf8))
        XCTAssertEqual(score.lanes.first?.presentation, .strip, "An old lane is a strip — the drawing it was made for.")
        XCTAssertEqual(score.lanes.first?.notes.first?.continuesPastEnd, false)
    }

    func testAnOpenEndedNoteSurvivesARoundTrip() throws {
        let score = UncertaintyScore(title: "t", spineStart: 1, spineEnd: 300, itemCount: 1, lanes: [
            UncertaintyLane(id: "beats", title: "Beats", notes: [note("a", 1, 300, open: true)], presentation: .braid)
        ])
        let back = try JSONDecoder().decode(UncertaintyScore.self, from: JSONEncoder().encode(score))
        XCTAssertEqual(back, score)
        XCTAssertTrue(back.lanes[0].notes[0].continuesPastEnd)
    }
}
