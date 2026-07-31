import Foundation

/// A shared source-coordinate viewport. Every resolution of the navigator uses this same range.
public struct UncertaintyViewport: Codable, Sendable, Equatable {
    public let fullRange: ClosedRange<Int>
    public private(set) var visibleRange: ClosedRange<Int>

    public init(fullRange: ClosedRange<Int>, visibleRange: ClosedRange<Int>? = nil) {
        let normalized = min(fullRange.lowerBound, fullRange.upperBound)...max(fullRange.lowerBound, fullRange.upperBound)
        self.fullRange = normalized
        let requested = visibleRange ?? normalized
        self.visibleRange = Self.clamp(requested, to: normalized)
    }

    public mutating func reset() { visibleRange = fullRange }

    public mutating func pan(by delta: Int) {
        guard delta != 0 else { return }
        let width = visibleRange.upperBound - visibleRange.lowerBound
        let lower = visibleRange.lowerBound + delta
        visibleRange = Self.clamp((lower...(lower + width)), to: fullRange)
    }

    /// Zoom around a source-coordinate anchor. Values below 1 zoom in; values above 1 zoom out.
    public mutating func zoom(factor: Double, around anchor: Int? = nil) {
        guard factor.isFinite, factor > 0 else { return }
        let currentWidth = max(1, visibleRange.upperBound - visibleRange.lowerBound)
        let targetWidth = max(1, min(fullRange.upperBound - fullRange.lowerBound, Int(Double(currentWidth) * factor)))
        let center = anchor ?? ((visibleRange.lowerBound + visibleRange.upperBound) / 2)
        let ratio = currentWidth == 0 ? 0.5 : Double(center - visibleRange.lowerBound) / Double(currentWidth)
        let lower = center - Int(Double(targetWidth) * ratio)
        visibleRange = Self.clamp(lower...(lower + targetWidth), to: fullRange)
    }

    private static func clamp(_ requested: ClosedRange<Int>, to full: ClosedRange<Int>) -> ClosedRange<Int> {
        let width = min(full.upperBound - full.lowerBound, max(0, requested.upperBound - requested.lowerBound))
        var lower = max(full.lowerBound, min(requested.lowerBound, full.upperBound - width))
        if lower < full.lowerBound { lower = full.lowerBound }
        return lower...(lower + width)
    }
}

/// Pure navigation state for an arbitrary ordered uncertainty collection.
public struct UncertaintyNavigatorState: Codable, Sendable, Equatable {
    public private(set) var score: UncertaintyScore
    public private(set) var selection: UncertaintyAddress?
    public private(set) var searchText: String
    public private(set) var stateFilter: Set<UncertaintyState>
    public private(set) var viewport: UncertaintyViewport
    public private(set) var mutedLaneIDs: Set<String>
    public private(set) var soloedLaneIDs: Set<String>

    public init(score: UncertaintyScore = .init(title: "", spineStart: 0, spineEnd: 0, itemCount: 0, lanes: [])) {
        self.score = score
        self.selection = nil
        self.searchText = ""
        self.stateFilter = []
        self.viewport = UncertaintyViewport(fullRange: score.spine)
        self.mutedLaneIDs = []
        self.soloedLaneIDs = []
    }

    public mutating func replaceScore(_ score: UncertaintyScore) {
        self.score = score
        let range = score.spine
        viewport = UncertaintyViewport(fullRange: range, visibleRange: viewport.visibleRange)
        if let selection, score.note(for: selection) == nil { self.selection = nil }
        mutedLaneIDs = mutedLaneIDs.intersection(Set(score.lanes.map(\.id)))
        soloedLaneIDs = soloedLaneIDs.intersection(Set(score.lanes.map(\.id)))
    }

    public mutating func select(_ address: UncertaintyAddress?) {
        selection = address.flatMap { score.note(for: $0) == nil ? nil : $0 }
    }

    public mutating func setSearchText(_ value: String) {
        searchText = value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public mutating func setStateFilter(_ value: Set<UncertaintyState>) { stateFilter = value }

    public mutating func panViewport(by delta: Int) { viewport.pan(by: delta) }

    public mutating func zoomViewport(factor: Double, around anchor: Int? = nil) {
        viewport.zoom(factor: factor, around: anchor)
    }

    public mutating func resetViewport() { viewport.reset() }

    public mutating func toggleMute(_ laneID: String) {
        if mutedLaneIDs.contains(laneID) { mutedLaneIDs.remove(laneID) } else { mutedLaneIDs.insert(laneID) }
    }

    public mutating func toggleSolo(_ laneID: String) {
        if soloedLaneIDs.contains(laneID) { soloedLaneIDs.remove(laneID) } else { soloedLaneIDs.insert(laneID) }
    }

    public mutating func resetMix() {
        mutedLaneIDs.removeAll()
        soloedLaneIDs.removeAll()
    }

    public var visibleScore: UncertaintyScore {
        let query = searchText.localizedLowercase
        let lanes = score.lanes.compactMap { lane -> UncertaintyLane? in
            let laneMatches = query.isEmpty || lane.title.localizedLowercase.contains(query)
            let notes = lane.notes.filter { note in
                let stateMatches = stateFilter.isEmpty || stateFilter.contains(note.state)
                let textMatches = laneMatches || query.isEmpty
                    || note.id.localizedLowercase.contains(query)
                    || note.title.localizedLowercase.contains(query)
                    || note.detail.localizedLowercase.contains(query)
                return stateMatches && textMatches
            }
            // Keep producer lanes in the rack even when a writer's explicit filter leaves no marks.
            return UncertaintyLane(id: lane.id, title: lane.title, isFailureAxis: lane.isFailureAxis,
                                   notes: notes, presentation: lane.presentation)
        }
        return UncertaintyScore(title: score.title, spineStart: score.spineStart, spineEnd: score.spineEnd,
                                itemCount: score.itemCount, lanes: lanes)
    }

    public var visibleLanes: [UncertaintyLane] {
        if !soloedLaneIDs.isEmpty { return visibleScore.lanes.filter { soloedLaneIDs.contains($0.id) } }
        return visibleScore.lanes.filter { !mutedLaneIDs.contains($0.id) }
    }
}
