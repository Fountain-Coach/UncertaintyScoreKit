import Foundation

// UncertaintyScoreKit — a provider-independent model for *what a reading is unsure of*, laid out as a score.
//
// The idea it encodes: a first pass over any material (a close reading, an extraction, a classification) is far more
// reliable at reporting **what it does and does not know** than at producing settled answers. So the deliverable is
// not a confident index — it is a multi-dimensional map of uncertainty, browsable as an orchestra of *dimensions*
// (instruments) over a shared *spine* (source order / time / any 1-D coordinate).
//
// This module owns ONLY that map and its invariants. It does not know about close reading, screenplays, or any
// producer's types — a caller adapts its own artifacts into `UncertaintyScore`. That boundary is deliberate: the
// same view draws the uncertainty of anything that emits per-item, multi-axis confidence.
//
// GROUNDED, as a type rule, not a hope: **absence is explicit.** There is no implicit "settled" fill. A dimension
// that was never assessed for an item simply has no note there (a blank in the spine); a dimension that WAS assessed
// and found fine carries an explicit `.settled` note (a faint hum). The two are different facts and the model keeps
// them different — a visualization must never invent a confident mark where the producer supplied none.

// MARK: - State

/// What one assessment says about one dimension of one item. Four states, ordered by how much attention they owe.
///
/// The hard line the whole model exists to keep: `.ambiguity` is a *result* — the material genuinely supports more
/// than one reading — while `.failure` is a *breakdown* — it was not assessed, could not be grounded, or is at risk
/// of being invented. They are different in kind, and a renderer is expected to make `.failure` louder, never to
/// launder it into a calm "open question".
public enum UncertaintyState: String, Codable, Sendable, CaseIterable {
    /// Assessed and confident. A faint hum, not silence — it is evidence the item was read.
    case settled
    /// Present but under-supported. Real, but the evidence is light.
    case ambiguity
    /// Genuinely open: the material supports competing readings and the producer honestly did not close it.
    case thin
    /// Broke down: not assessed, ungrounded, or at fabrication risk. Rendered loud; different in kind from ambiguity.
    case failure

    /// How much attention this state owes — drives default magnitude and the aggregate "tutti".
    public var weight: Double {
        switch self {
        case .settled: return 0.12
        case .thin: return 0.42
        case .ambiguity: return 0.72
        case .failure: return 0.96
        }
    }

    public var isFailure: Bool { self == .failure }
}

// MARK: - Note

/// One assessment: a state for one dimension across a span of the spine, with the reason and — the routing cue —
/// who could close it. `resolvedBy` is why this is a *map* and not a verdict: it points a later, better-equipped
/// stage (or a person) at exactly this span.
public struct UncertaintyNote: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    /// Inclusive span on the spine (e.g. source line numbers). `start <= end` is enforced.
    public let start: Int
    public let end: Int
    public let state: UncertaintyState
    /// 0…1 loudness within the state. Defaults to `state.weight`; a producer may raise it (e.g. three unresolved
    /// questions in one passage) but never past 1.
    public let magnitude: Double
    /// Plain-language account of the openness, for the person reading the map. Never internal codes.
    public let detail: String
    /// The cheapest next operation that could close this, phrased for a human ("paid escalation", "re-observe").
    /// `nil` means nothing closes it more cheaply than it already is.
    public let resolvedBy: String?

    public init(
        id: String,
        start: Int,
        end: Int,
        state: UncertaintyState,
        magnitude: Double? = nil,
        detail: String = "",
        resolvedBy: String? = nil
    ) {
        self.id = id
        self.start = Swift.min(start, end)
        self.end = Swift.max(start, end)
        self.state = state
        self.magnitude = Swift.min(1, Swift.max(0, magnitude ?? state.weight))
        self.detail = detail
        self.resolvedBy = resolvedBy
    }

    public var span: ClosedRange<Int> { start...end }
}

// MARK: - Lane

/// One dimension of uncertainty — an instrument. Identity is carried by the lane (its `title` and its row), so a
/// renderer is free to spend colour on STATE instead of on telling lanes apart.
public struct UncertaintyLane: Codable, Sendable, Identifiable, Equatable {
    /// Stable identity for solo/mute and for colour-follows-entity discipline.
    public let id: String
    public let title: String
    /// True for coverage/provenance/fabrication-style axes, where `.failure` means "not read" rather than "hard to
    /// read". A renderer uses this to decide how loud a breakdown here should be.
    public let isFailureAxis: Bool
    public let notes: [UncertaintyNote]

    public init(id: String, title: String, isFailureAxis: Bool = false, notes: [UncertaintyNote]) {
        self.id = id
        self.title = title
        self.isFailureAxis = isFailureAxis
        self.notes = notes.sorted { $0.start < $1.start }
    }

    /// The worst thing this lane says anywhere — for the mixer chip's at-a-glance colour.
    public var peakState: UncertaintyState {
        notes.map(\.state).max { $0.weight < $1.weight } ?? .settled
    }

    /// The note covering a spine position, if any.
    public func note(at position: Int) -> UncertaintyNote? {
        notes.first { $0.span.contains(position) }
    }
}

// MARK: - Score

/// The whole map: dimensions over one shared spine.
public struct UncertaintyScore: Codable, Sendable, Equatable {
    public let title: String
    /// The spine's inclusive extent. The renderer maps this to the horizontal axis.
    public let spineStart: Int
    public let spineEnd: Int
    /// How many items (passages / rows) fed the map — for the header, and to distinguish "read and settled" density
    /// from "barely covered".
    public let itemCount: Int
    /// Fixed order — never cycled. The caller decides the order once; the renderer honours it.
    public let lanes: [UncertaintyLane]

    public init(title: String, spineStart: Int, spineEnd: Int, itemCount: Int, lanes: [UncertaintyLane]) {
        self.title = title
        self.spineStart = Swift.min(spineStart, spineEnd)
        self.spineEnd = Swift.max(spineStart, spineEnd)
        self.itemCount = itemCount
        self.lanes = lanes
    }

    public var isEmpty: Bool { lanes.allSatisfy { $0.notes.isEmpty } }

    public var spine: ClosedRange<Int> { spineStart...spineEnd }

    /// Aggregate openness at a spine position across the given lanes — the "tutti" that makes hot spots pop for
    /// triage. `.failure` dominates: one breakdown outweighs several mild ambiguities, because it must draw the eye.
    public func openness(at position: Int, lanes visible: [UncertaintyLane]? = nil) -> Double {
        let set = visible ?? lanes
        guard !set.isEmpty else { return 0 }
        var total = 0.0
        var worstFailure = 0.0
        for lane in set {
            guard let note = lane.note(at: position) else { continue }
            let contribution = note.state.weight * note.magnitude
            total += contribution
            if note.state.isFailure { worstFailure = Swift.max(worstFailure, contribution) }
        }
        // Blend the mean with the worst failure so a single "not read" span still spikes the ribbon.
        let mean = total / Double(set.count)
        return Swift.min(1, Swift.max(mean, worstFailure))
    }

    public func lane(id: String) -> UncertaintyLane? { lanes.first { $0.id == id } }
}
