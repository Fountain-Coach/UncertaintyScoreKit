import SwiftUI
import UncertaintyScoreKit

/// The three synchronized resolutions of an uncertainty score: the complete lane rack, the shared-spine map, and
/// a stable generic account of the selected thread. Reframe supplies domain context around this view; this type
/// never imports or names a producer's ledger, evidence, or action types.
public struct UncertaintyScoreNavigatorView: View {
    public let score: UncertaintyScore
    @Binding public var selectedAddress: UncertaintyAddress?
    public let onSelectAddress: ((UncertaintyAddress) -> Void)?
    public let dragProvider: ((UncertaintyNote, UncertaintyAddress) -> NSItemProvider)?

    @State private var navigation: UncertaintyNavigatorState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The navigator is a contextual instrument, not a second full-height stage. Keep the three resolutions
    /// visible without allowing a dense score to increase the height of the host's Story surface. The complete
    /// collection remains reachable inside the rack and map viewports.
    private static let navigatorViewportHeight: CGFloat = 248
    private static let inspectorHeight: CGFloat = 132

    public init(score: UncertaintyScore, selectedAddress: Binding<UncertaintyAddress?>,
                dragProvider: ((UncertaintyNote, UncertaintyAddress) -> NSItemProvider)? = nil,
                onSelectAddress: ((UncertaintyAddress) -> Void)? = nil) {
        self.score = score
        self._selectedAddress = selectedAddress
        self.dragProvider = dragProvider
        self.onSelectAddress = onSelectAddress
        self._navigation = State(initialValue: UncertaintyNavigatorState(score: score))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            navigationControls
            HStack(alignment: .top, spacing: 12) {
                laneRack
                    .frame(minWidth: 218, maxWidth: 286,
                           minHeight: Self.navigatorViewportHeight, maxHeight: Self.navigatorViewportHeight)
                mapAndInspector
            }
        }
        .onChange(of: score) { _, newScore in navigation.replaceScore(newScore) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("uncertainty-navigator")
        .accessibilityLabel("Uncertainty map navigator")
    }

    private var navigationControls: some View {
        HStack(spacing: 8) {
            TextField("Search lanes and notes", text: Binding(
                get: { navigation.searchText },
                set: { navigation.setSearchText($0) }))
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("uncertainty-map-search")
                .accessibilityLabel("Search uncertainty lanes and notes")

            Menu {
                ForEach(UncertaintyState.allCases, id: \.self) { state in
                    Button {
                        var next = navigation.stateFilter
                        if next.contains(state) { next.remove(state) } else { next.insert(state) }
                        navigation.setStateFilter(next)
                    } label: {
                        Label(state.rawValue.capitalized,
                              systemImage: navigation.stateFilter.contains(state) ? "checkmark.square" : "square")
                    }
                }
                Divider()
                Button("Show all states") { navigation.setStateFilter([]) }
            } label: {
                Label(filterLabel, systemImage: "line.3.horizontal.decrease.circle")
            }
            .accessibilityIdentifier("uncertainty-map-state-filter")
            .accessibilityLabel(filterLabel)

            Button { navigation.panViewport(by: -panAmount) } label: { Image(systemName: "chevron.left") }
                .accessibilityIdentifier("uncertainty-map-pan-left")
                .accessibilityLabel("Pan uncertainty map left")
            Button { navigation.panViewport(by: panAmount) } label: { Image(systemName: "chevron.right") }
                .accessibilityIdentifier("uncertainty-map-pan-right")
                .accessibilityLabel("Pan uncertainty map right")
            Button { navigation.zoomViewport(factor: 0.65) } label: { Image(systemName: "plus.magnifyingglass") }
                .accessibilityIdentifier("uncertainty-map-zoom-in")
                .accessibilityLabel("Zoom uncertainty map in")
            Button { navigation.zoomViewport(factor: 1.55) } label: { Image(systemName: "minus.magnifyingglass") }
                .accessibilityIdentifier("uncertainty-map-zoom-out")
                .accessibilityLabel("Zoom uncertainty map out")
            Button { navigation.resetViewport() } label: { Image(systemName: "arrow.counterclockwise") }
                .accessibilityIdentifier("uncertainty-map-viewport-reset")
                .accessibilityLabel("Reset uncertainty map viewport")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("uncertainty-map-controls")
    }

    private var filterLabel: String {
        if navigation.stateFilter.isEmpty { return "Uncertainty state filter: All states" }
        return "Uncertainty state filter: " + navigation.stateFilter.map(\.rawValue).sorted().joined(separator: ", ")
    }

    private var panAmount: Int {
        max(1, (navigation.viewport.visibleRange.upperBound - navigation.viewport.visibleRange.lowerBound) / 2)
    }

    private var laneRack: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 5) {
                ForEach(navigation.visibleScore.lanes) { lane in
                    DisclosureGroup {
                        ForEach(lane.notes) { note in
                            let address = UncertaintyAddress(laneID: lane.id, noteID: note.id)
                            Button {
                                select(address)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.title.isEmpty ? "Untitled note" : note.title)
                                        .lineLimit(2)
                                    Text("\(note.state.rawValue), lines \(note.start)–\(note.end)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("uncertainty-note-\(address.id)-rack")
                            .accessibilityLabel("\(lane.title), \(note.title.isEmpty ? "untitled note" : note.title)")
                            .accessibilityValue("\(note.state.rawValue), lines \(note.start) to \(note.end)")
                            .accessibilityAddTraits(selectedAddress == address ? [.isSelected] : [])
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(lane.title).font(.subheadline.weight(.semibold))
                            Spacer(minLength: 2)
                            Text("\(lane.notes.count)").font(.caption).foregroundStyle(.secondary)
                            Button {
                                navigation.toggleSolo(lane.id)
                            } label: { Text("S").font(.caption2.weight(.bold)) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("uncertainty-lane-\(lane.id)-solo")
                                .accessibilityLabel("Solo \(lane.title)")
                                .accessibilityValue(navigation.soloedLaneIDs.contains(lane.id) ? "On" : "Off")
                            Button {
                                navigation.toggleMute(lane.id)
                            } label: { Text("M").font(.caption2.weight(.bold)) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("uncertainty-lane-\(lane.id)-mute")
                                .accessibilityLabel("Mute \(lane.title)")
                                .accessibilityValue(navigation.mutedLaneIDs.contains(lane.id) ? "On" : "Off")
                        }
                    }
                    .accessibilityIdentifier("uncertainty-lane-\(lane.id)")
                    .accessibilityLabel("Uncertainty lane \(lane.title), \(lane.notes.count) notes")
                }
            }
            .padding(8)
        }
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
        .accessibilityIdentifier("uncertainty-lane-rack")
        .accessibilityLabel("All uncertainty lanes in producer order")
    }

    private var mapAndInspector: some View {
        let mapScore = presentationScore
        let binding = Binding<String?>(
            get: { selectedAddress.map { address in UncertaintyAddress(laneID: address.laneID, noteID: address.noteID).id } },
            set: { id in
                guard let id, let address = mapScoreAddress(for: id) else { select(nil); return }
                select(address)
            })
        return VStack(alignment: .leading, spacing: 8) {
            // The shared spine is a bounded viewport. A large braid scrolls inside this region rather than
            // pushing the beat/source surface below the fold. The score itself remains complete and the same
            // source-coordinate viewport controls (pan/zoom/reset) still apply to every visible lane.
            ScrollView(.vertical) {
                UncertaintyScoreView(score: mapScore, selectedNoteId: binding, showsSelectionDetail: false,
                                     dragProvider: { note in
                                         guard let address = mapScoreAddress(for: note.id) else { return NSItemProvider() }
                                         return dragProvider?(note, address) ?? NSItemProvider()
                                     },
                                     onSelectNote: { note in
                                         if let address = mapScoreAddress(for: note.id) { select(address) }
                                     })
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity,
                   minHeight: Self.navigatorViewportHeight, maxHeight: Self.navigatorViewportHeight)
            .background(Color.primary.opacity(0.018), in: RoundedRectangle(cornerRadius: 7))
            .accessibilityIdentifier("uncertainty-map-viewport")
            .accessibilityLabel("Shared uncertainty map viewport; scroll to inspect all lane marks")

            // The selected-thread account has its own stable home and bounded scroll. Selecting a longer note
            // never changes the map height or reflows the conversation around it.
            ScrollView(.vertical) {
                genericInspector
            }
            .frame(maxWidth: .infinity,
                   minHeight: Self.inspectorHeight, maxHeight: Self.inspectorHeight,
                   alignment: .topLeading)
            .accessibilityIdentifier("uncertainty-thread-inspector-viewport")
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// The transformed score is private to the generic renderer. The public model and all callbacks remain
    /// addressed; this compatibility projection exists only because the older drawing primitive accepts note IDs.
    private var presentationScore: UncertaintyScore {
        let visible = navigation.visibleLanes
        let range = navigation.viewport.visibleRange
        let lanes = visible.map { lane in
            let notes = lane.notes.compactMap { note -> UncertaintyNote? in
                guard note.end >= range.lowerBound && note.start <= range.upperBound else { return nil }
                let address = UncertaintyAddress(laneID: lane.id, noteID: note.id)
                return UncertaintyNote(id: address.id,
                                       start: max(note.start, range.lowerBound), end: min(note.end, range.upperBound),
                                       state: note.state, magnitude: note.magnitude, detail: note.detail,
                                       title: note.title, resolvedBy: note.resolvedBy,
                                       continuesPastEnd: note.continuesPastEnd)
            }
            return UncertaintyLane(id: lane.id, title: lane.title, isFailureAxis: lane.isFailureAxis,
                                   notes: notes, presentation: lane.presentation)
        }
        return UncertaintyScore(title: score.title, spineStart: range.lowerBound, spineEnd: range.upperBound,
                                itemCount: score.itemCount, lanes: lanes)
    }

    private func mapScoreAddress(for presentationID: String) -> UncertaintyAddress? {
        score.addresses.first { $0.id == presentationID }
    }

    private func select(_ address: UncertaintyAddress?) {
        navigation.select(address)
        selectedAddress = navigation.selection
        if let selectedAddress { onSelectAddress?(selectedAddress) }
    }

    private var genericInspector: some View {
        let note = selectedAddress.flatMap { score.note(for: $0) }
        let inspectorValue: String = {
            guard let address = selectedAddress, let note else {
                return "No uncertainty thread selected."
            }
            let detail = note.detail.isEmpty ? "No detail was recorded for this span." : note.detail
            let closure = note.resolvedBy.map { " Closure: \($0)." } ?? ""
            return "\(address.description) · \(note.state.rawValue) · lines \(note.start)–\(note.end). \(detail).\(closure)"
        }()
        return VStack(alignment: .leading, spacing: 4) {
            if let address = selectedAddress, let note {
                Text(note.title.isEmpty ? "Selected uncertainty thread" : note.title).font(.headline)
                Text("\(address.description) · \(note.state.rawValue) · lines \(note.start)–\(note.end)")
                    .font(.caption).foregroundStyle(.secondary)
                Text(note.detail.isEmpty ? "No detail was recorded for this span." : note.detail)
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
                if let resolvedBy = note.resolvedBy { Text(resolvedBy).font(.caption).foregroundStyle(.secondary) }
            } else {
                Text("No uncertainty thread selected.").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .padding(10)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("uncertainty-thread-inspector")
        .accessibilityLabel(note == nil ? "Uncertainty thread inspector, no thread selected" : inspectorValue)
    }
}
