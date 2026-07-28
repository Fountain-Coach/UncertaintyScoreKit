import UncertaintyScoreKit

// Fixtures for the demo/VRT harness. These are HAND-BUILT sample maps, never runtime data — they exist only to
// exercise the renderer and prove the encoding reads. One is a close reading (Telemachus); one is deliberately
// non-literary (log triage), because a library that can only draw readings is not the general thing it claims to be.

enum Fixtures {

    private static func note(_ id: String, _ s: Int, _ e: Int, _ state: UncertaintyState,
                             _ detail: String, _ by: String? = nil, mag: Double? = nil) -> UncertaintyNote {
        UncertaintyNote(id: id, start: s, end: e, state: state, magnitude: mag, detail: detail, resolvedBy: by)
    }

    // MARK: - A chapter carrying many questions at once — the braid at the scale that breaks a strip

    /// EIGHTEEN THINGS ALIVE IN ONE CHAPTER. Three notes on a lane can be drawn any way at all; the drawing has to
    /// survive the real case, where a close reading of one episode holds fifteen or forty questions, several of
    /// them open at the same moment and each named by a whole sentence. This fixture exists to be LOOKED AT: if
    /// the braid is unreadable here, it is unreadable in the app.
    static var braidedChapter: UncertaintyScore {
        let questions: [(Int, Int, String, Bool)] = [
            (1, 1118, "Will Buck Mulligan and Stephen Dedalus's conflict escalate?", true),
            (1, 105, "What is the significance of Buck Mulligan's blessing?", false),
            (14, 96, "Why does Mulligan perform the mass at the parapet?", false),
            (60, 240, "What does Stephen owe his mother now that she is dead?", true),
            (88, 152, "Will Stephen admit why he would not kneel?", false),
            (130, 1118, "What will happen next between Stephen and Buck?", true),
            (168, 300, "Who is Haines, and what is he doing in the tower?", false),
            (196, 410, "Does Stephen intend to come back to the tower tonight?", true),
            (240, 288, "What did the aunt mean by 'you killed your mother'?", false),
            (300, 470, "Why does the sea keep returning as the mother?", true),
            (352, 640, "Is Mulligan's mockery affection or contempt?", true),
            (410, 512, "What does Stephen want from the milkwoman?", false),
            (455, 700, "Who holds the key to the tower, and what does holding it mean?", true),
            (512, 604, "Will Haines's dream of the panther matter again?", false),
            (610, 880, "Is Stephen's poverty a choice he is making?", true),
            (700, 1050, "What is Stephen's quarrel with the Irish revival?", true),
            (812, 968, "Does Stephen believe what he says about the church?", false),
            (900, 1118, "Where will Stephen sleep tonight?", true)
        ]
        let notes = questions.enumerated().map { i, q in
            UncertaintyNote(id: "beat-\(i)", start: q.0, end: q.1, state: .ambiguity,
                            detail: q.2, resolvedBy: q.3 ? "answer it, or read on to where the story does" : nil,
                            continuesPastEnd: q.3)
        }
        return UncertaintyScore(
            title: "This reading", spineStart: 1, spineEnd: 1118, itemCount: 45,
            lanes: [
                UncertaintyLane(id: "structure", title: "Structure read", isFailureAxis: true, notes: [
                    note("s-0", 1, 400, .settled, "Read and confident here."),
                    note("s-1", 401, 840, .settled, "Read and confident here."),
                    note("s-2", 841, 1118, .thin, "Read thinly — the passages here were long.", "re-observe")
                ]),
                UncertaintyLane(id: "beats", title: "Beats — questions held open", notes: notes, presentation: .braid)
            ])
    }

    // MARK: - Telemachus (Ulysses, episode 1) — what a first on-device read plausibly leaves open

    static var telemachus: UncertaintyScore {
        // A rough passage grid over the episode's line span.
        let p: [(Int, Int)] = [
            (1, 28), (29, 60), (61, 96), (97, 130), (131, 170), (171, 210), (211, 250),
            (251, 290), (291, 330), (331, 372), (373, 410), (411, 452), (453, 496), (497, 540), (541, 560)
        ]
        func hum(_ lane: String) -> [UncertaintyNote] {
            p.enumerated().map { i, span in note("\(lane)-\(i)", span.0, span.1, .settled, "Read and confident here.") }
        }
        func over(_ lane: String, _ events: [Int: (UncertaintyState, String, String?)]) -> [UncertaintyNote] {
            p.enumerated().map { i, span in
                if let e = events[i] {
                    return note("\(lane)-\(i)", span.0, span.1, e.0, e.1, e.2)
                }
                return note("\(lane)-\(i)", span.0, span.1, .settled, "Read and confident here.")
            }
        }

        let lanes: [UncertaintyLane] = [
            UncertaintyLane(id: "literalCoverage", title: "Literal coverage", isFailureAxis: true, notes: over("cov", [
                4: (.thin, "The interior-monologue drift is only partly transcribed into events.", "re-observe the passage"),
                8: (.thin, "Latin liturgy fragments left unparaphrased.", "re-observe the passage")
            ])),
            UncertaintyLane(id: "grounding", title: "Grounding", isFailureAxis: true, notes: over("grd", [
                8: (.failure, "The church-parody span produced claims citing no line in range — ungrounded.", "re-observe the passage"),
                11: (.thin, "‘Chrysostomos’ attached to a speaker the text does not name here.", "re-observe the passage")
            ])),
            UncertaintyLane(id: "relations", title: "Relations", isFailureAxis: false, notes: over("rel", [
                2: (.thin, "Ordering between Mulligan's shaving and his speech is only implied.", "relate the observations"),
                9: (.ambiguity, "Does the milkwoman's entrance interrupt or answer the mock-mass? Both hold.", "another interpretive pass")
            ])),
            UncertaintyLane(id: "continuity", title: "Continuity", isFailureAxis: false, notes: over("con", [
                6: (.thin, "Reference to Stephen's Paris year assumes context this passage doesn't carry.", "compare against prior reading")
            ])),
            UncertaintyLane(id: "interpretation", title: "Interpretation", isFailureAxis: false, notes: over("int", [
                3: (.ambiguity, "Mulligan's mockery reads as affection OR as cruelty — the evidence allows both.", "paid escalation"),
                7: (.ambiguity, "Is the sea ‘our great sweet mother’ consolation or accusation? Held open.", "paid escalation"),
                12: (.thin, "Usurper motif asserted more strongly than this span's lines support.", "argue against the claim")
            ])),
            UncertaintyLane(id: "ambiguityKept", title: "Ambiguity kept", isFailureAxis: false, notes: over("amb", [
                5: (.ambiguity, "Stephen's grief: remembered mourning vs present refusal — the passage sustains both.", "another interpretive pass"),
                10: (.ambiguity, "‘Agenbite of inwit’ — guilt named, cause left genuinely undecided.", nil)
            ])),
            UncertaintyLane(id: "counterReading", title: "Counter-reading", isFailureAxis: false, notes: over("ctr", [
                3: (.thin, "The affection reading was never argued against.", "argue against the claim"),
                7: (.thin, "No counter put to the mother-sea claim.", "argue against the claim")
            ])),
            UncertaintyLane(id: "fabricationRisk", title: "Fabrication risk", isFailureAxis: true, notes: over("fab", [
                8: (.failure, "A character ‘Chrysostomos’ was invented from an adjective — not a person in the text.", "re-observe the passage"),
                13: (.thin, "Motive attributed to Haines the lines don't state.", "argue against the claim")
            ])),
            UncertaintyLane(id: "openQuestions", title: "Open questions", isFailureAxis: false, notes: over("opn", [
                5: (.ambiguity, "What does Stephen refuse, exactly — the prayer, the mother, or Mulligan's terms?", nil),
                9: (.ambiguity, "Whose authority does the tower key stand for?", nil),
                14: (.ambiguity, "Is the closing ‘Usurper’ aimed at Mulligan, Haines, or England?", "paid escalation")
            ])),
            UncertaintyLane(id: "provenance", title: "Provenance / trust", isFailureAxis: true, notes: over("prv", [
                8: (.failure, "This span's reading came from a silent fallback lane — trust unverified.", "re-read on a real lane"),
                11: (.failure, "Fallback lane again; provenance not the intended reader.", "re-read on a real lane")
            ]))
        ]
        return UncertaintyScore(title: "Telemachus — reading uncertainty", spineStart: 1, spineEnd: 560,
                                itemCount: p.count, lanes: lanes)
    }

    // MARK: - Non-literary: log-triage uncertainty (proves the model is general)

    static var logTriage: UncertaintyScore {
        let lanes: [UncertaintyLane] = [
            UncertaintyLane(id: "parse", title: "Parse coverage", isFailureAxis: true, notes: [
                note("ps0", 1, 60, .settled, "Structured lines parsed cleanly."),
                note("ps1", 61, 96, .failure, "A block of non-JSON stack traces could not be parsed.", "re-ingest with a raw matcher"),
                note("ps2", 97, 200, .settled, "Parsed.")
            ]),
            UncertaintyLane(id: "fields", title: "Field grounding", isFailureAxis: true, notes: [
                note("fg0", 1, 96, .settled, "All fields present."),
                note("fg1", 97, 140, .thin, "`user_id` inferred from `uid` — mapping unconfirmed.", "confirm the field map"),
                note("fg2", 141, 200, .settled, "Grounded.")
            ]),
            UncertaintyLane(id: "severity", title: "Severity", isFailureAxis: false, notes: [
                note("sv0", 1, 96, .settled, "Severity unambiguous."),
                note("sv1", 97, 160, .ambiguity, "WARN-vs-ERROR: the same code appears at both levels.", "escalate to a rules pass"),
                note("sv2", 161, 200, .settled, "Clear.")
            ]),
            UncertaintyLane(id: "correlation", title: "Correlation", isFailureAxis: false, notes: [
                note("cr0", 1, 130, .thin, "Trace IDs partly missing; correlation is heuristic.", "join on request id"),
                note("cr1", 131, 200, .settled, "Correlated.")
            ]),
            UncertaintyLane(id: "pii", title: "PII risk", isFailureAxis: true, notes: [
                note("pi0", 1, 200, .settled, "No PII detected."),
                note("pi1", 45, 52, .failure, "An email address slipped through unredacted.", "redact before export")
            ]),
            UncertaintyLane(id: "provenance", title: "Provenance", isFailureAxis: true, notes: [
                note("pv0", 1, 200, .settled, "Single trusted collector.")
            ])
        ]
        return UncertaintyScore(title: "Log triage — extraction uncertainty", spineStart: 1, spineEnd: 200,
                                itemCount: 4, lanes: lanes)
    }
}
