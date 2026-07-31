import XCTest
import UncertaintyScoreKitUI

final class UncertaintyClosureCueTests: XCTestCase {
    func testCueIsProspectiveRatherThanClaimingClosure() {
        XCTAssertEqual(
            UncertaintyClosureCue.text(for: "the manuscript: read this stretch"),
            "Could be closed by: the manuscript: read this stretch"
        )
    }

    func testMissingOperationHasNoCue() {
        XCTAssertEqual(UncertaintyClosureCue.text(for: nil), "")
        XCTAssertEqual(UncertaintyClosureCue.text(for: "  "), "")
    }
}
