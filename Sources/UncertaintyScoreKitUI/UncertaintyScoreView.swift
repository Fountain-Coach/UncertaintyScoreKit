import SwiftUI
import UncertaintyScoreKit

// The score, drawn. One row per dimension over a shared spine. Reader surfaces may show the whole texture;
// authoring surfaces may additionally offer solo/mute controls.
//
// Colour carries STATE, never dimension identity (the lane's row + label already name the dimension), so the palette
// is two validated status hues + neutral ink — checked colourblind-safe in light and dark by the dataviz validator.
// Every state is ALSO a distinct shape, so the encoding survives greyscale, forced-colours, and print:
//   · settled   — a faint hum line
//   · thin      — a low single bar
//   · ambiguity — a HELD DYAD: two bars, one above one below, the two readings sounded together
//   · failure   — a LOUD broken block with a silence cut through it and a caret; "not read", not "hard to read"
// That last distinction is the whole point: failure must read as different in kind from honest ambiguity.

// MARK: - Palette (validated: light #3E63DD/#D93A4A, dark #5B86E8/#EA5566 — CVD-safe, ≥3:1 on both surfaces)

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

private struct UncertaintyPalette {
    let ambiguity: Color
    let failure: Color

    init(_ scheme: ColorScheme) {
        ambiguity = scheme == .dark ? Color(hex: 0x5B86E8) : Color(hex: 0x3E63DD)
        failure = scheme == .dark ? Color(hex: 0xEA5566) : Color(hex: 0xD93A4A)
    }

    func stroke(for state: UncertaintyState) -> Color {
        switch state {
        case .settled: return .secondary
        case .thin, .ambiguity: return ambiguity
        case .failure: return failure
        }
    }

    func label(for state: UncertaintyState) -> String {
        switch state {
        case .settled: return "settled"
        case .thin: return "thin"
        case .ambiguity: return "ambiguity"
        case .failure: return "not read / ungrounded"
        }
    }
}

// MARK: - View

/// THE COLOUR A BRAIDED THING IS KNOWN BY, everywhere it appears.
///
/// A braid draws many things at once, and a bar's position tells you WHERE it runs but not WHICH it is. Colour
/// gives each one an identity that survives leaving the map: the host paints the same thing — the passage it
/// covers, its row in a list, a chip on a card — with the same colour, and the writer never has to re-find it.
///
/// Hues walk by the golden angle, so neighbours in a packed row are far apart on the wheel however many there are,
/// and the walk is deterministic: the same index is the same colour on every render and across relaunches.
extension View {
    /// Apply a modifier only when the optional it depends on is present — used so a score without a drag provider
    /// carries no drag gesture at all rather than an inert one.
    @ViewBuilder func ifLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value { transform(self, value) } else { self }
    }
}

/// WHERE EACH MARK IS ON SCREEN, for a host that needs to draw to it.
///
/// A map that can be dragged from is a map things LEAVE, and what they leave has to be drawn from where the mark
/// actually is — a wire that starts at the panel instead of at the bar is a wire to nothing in particular. The view
/// publishes each drawn mark's frame; the host reads them with `overlayPreferenceValue` and draws whatever it likes.
public struct UncertaintyNoteAnchorsKey: PreferenceKey {
    public static let defaultValue: [String: Anchor<CGRect>] = [:]
    public static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

public enum UncertaintyBraidPalette {
    public static func tint(index: Int, scheme: ColorScheme = .light) -> Color {
        let hue = (Double(index) * 0.6180339887).truncatingRemainder(dividingBy: 1)
        return scheme == .dark
            ? Color(hue: hue, saturation: 0.55, brightness: 0.86)
            : Color(hue: hue, saturation: 0.62, brightness: 0.74)
    }

    /// Stable identity tint shared by every surface that names a lane.
    /// State is still encoded separately by the score's mark shape and status color.
    public static func tint(laneID: String, scheme: ColorScheme = .light) -> Color {
        let value = laneID.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        return tint(index: abs(value % 17), scheme: scheme)
    }
}

public struct UncertaintyScoreView: View {
    public let score: UncertaintyScore
    /// Reader surfaces may show the complete map without offering controls that hide lanes.
    public let showsMixer: Bool
    /// Called when the reader clicks a mark, with the note under the click.
    ///
    /// The map names an openness over a span of the spine; only the HOST knows what that span is — a passage, a
    /// beat, a log window — so only the host can show it in the reader's own terms. Without this the selection died
    /// inside the view: the detail line named the span, and nothing else on screen moved.
    ///
    /// Hands back the core `UncertaintyNote`, never anything of the host's, so the core stays ignorant of any
    /// producer's domain (AGENTS invariant 2). The view keeps owning its own selection — this reports, it does not
    /// delegate. Called synchronously from the gesture on the main actor, so keep the work cheap.
    public let onSelectNote: ((UncertaintyNote) -> Void)?

    @Environment(\.colorScheme) private var scheme
    @State private var muted: Set<String> = []
    @State private var soloed: Set<String> = []
    @State private var internalSelection: UncertaintyNote?
    /// WHEN THE HOST SHOWS THE SAME NOTES SOMEWHERE ELSE, THERE IS ONLY ONE SELECTION.
    ///
    /// A lane of many things needs its names shown outside the map — a list, a panel — and two selections for one
    /// set of things means clicking a name and clicking its bar disagree about what is chosen. Bound, the map and
    /// the host's own view of the same notes stay one thing; unbound, the view keeps owning its selection as before.
    private var selectionBinding: Binding<String?>?

    private var selection: UncertaintyNote? {
        if let id = selectionBinding?.wrappedValue {
            return score.lanes.flatMap(\.notes).first { $0.id == id }
        }
        return internalSelection
    }

    private func select(_ note: UncertaintyNote) {
        if let binding = selectionBinding { binding.wrappedValue = note.id } else { internalSelection = note }
        onSelectNote?(note)
    }

    public init(score: UncertaintyScore, showsMixer: Bool = true,
                onSelectNote: ((UncertaintyNote) -> Void)? = nil) {
        self.score = score
        self.showsMixer = showsMixer
        self.onSelectNote = onSelectNote
        self.selectionBinding = nil
    }

    public init(score: UncertaintyScore, selectedNoteId: Binding<String?>,
                showsSelectionDetail: Bool = true,
                showsMixer: Bool = true,
                dragProvider: ((UncertaintyNote) -> NSItemProvider)? = nil,
                onSelectNote: ((UncertaintyNote) -> Void)? = nil) {
        self.score = score
        self.showsMixer = showsMixer
        self.onSelectNote = onSelectNote
        self.selectionBinding = selectedNoteId
        self.showsSelectionDetail = showsSelectionDetail
        self.dragProvider = dragProvider
    }

    /// THE MARK ITSELF IS THE HANDLE. A host that can do something with a note — hand it to something else, cite
    /// it, wire it up — should let the writer take hold of the THING, not of a label that stands next to it. The
    /// drawn span is what they are looking at, so the drawn span is what they pick up.
    private var dragProvider: ((UncertaintyNote) -> NSItemProvider)?

    /// WHEN THE HOST ALREADY SHOWS THE NAMES, THE MAP MUST NOT SHOW THEM AGAIN. The same sentence printed twice on
    /// one screen is not emphasis, it is noise competing with itself — and it costs the room the map needs.
    private var showsSelectionDetail: Bool = true

    private static let gutterWidth: CGFloat = 176
    private static let laneHeight: CGFloat = 34
    /// Tall enough to hit with a pointer, short enough that fifteen rows still fit on a stage.
    private static let braidRowHeight: CGFloat = 22

    private var visibleLanes: [UncertaintyLane] {
        guard showsMixer else { return score.lanes }
        if !soloed.isEmpty { return score.lanes.filter { soloed.contains($0.id) } }
        return score.lanes.filter { !muted.contains($0.id) }
    }

    private func isVisible(_ lane: UncertaintyLane) -> Bool {
        soloed.isEmpty ? !muted.contains(lane.id) : soloed.contains(lane.id)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            legend
            tuttiRibbon
            VStack(spacing: 3) {
                ForEach(score.lanes) { lane in
                    laneRow(lane)
                }
            }
            if showsSelectionDetail { selectionDetail }
        }
        .padding(18)
        .frame(minWidth: 620, alignment: .topLeading)
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: Header + legend

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(score.title).font(.system(size: 20, weight: .semibold))
            Text("What the first reading is unsure of — \(score.lanes.count) dimensions over lines \(score.spineStart)–\(score.spineEnd), from \(score.itemCount) passage\(score.itemCount == 1 ? "" : "s"). The ribbon shows where problems stack up.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var legend: some View {
        let palette = UncertaintyPalette(scheme)
        return HStack(spacing: 14) {
            ForEach(UncertaintyState.allCases, id: \.self) { state in
                HStack(spacing: 5) {
                    legendGlyph(state, palette: palette)
                    Text(palette.label(for: state)).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if showsMixer && (!muted.isEmpty || !soloed.isEmpty) {
                Button("Reset mix") { muted.removeAll(); soloed.removeAll() }
                    .buttonStyle(.link).font(.caption)
            }
        }
    }

    @ViewBuilder
    private func legendGlyph(_ state: UncertaintyState, palette: UncertaintyPalette) -> some View {
        Canvas { ctx, size in
            drawMark(&ctx, state: state, rect: CGRect(x: 0, y: 0, width: size.width, height: size.height),
                     magnitude: 1, palette: palette, selected: false)
        }
        .frame(width: 20, height: 16)
    }

    // MARK: Tutti ribbon — the triage heat strip

    private var tuttiRibbon: some View {
        let palette = UncertaintyPalette(scheme)
        let lanes = visibleLanes
        return HStack(spacing: 0) {
            Text("stacked").font(.caption2).foregroundStyle(.tertiary)
                .frame(width: Self.gutterWidth, alignment: .trailing).padding(.trailing, 8)
            GeometryReader { proxy in
                Canvas { ctx, size in
                    guard score.spineEnd > score.spineStart else { return }
                    let steps = Int(size.width)
                    for px in stride(from: 0, to: max(1, steps), by: 1) {
                        let pos = score.spineStart + Int(Double(px) / size.width * Double(score.spineEnd - score.spineStart))
                        let o = score.openness(at: pos, lanes: lanes)
                        guard o > 0.01 else { continue }
                        // Any failure in the column tints the heat red; otherwise it reads as accumulating ambiguity.
                        let failing = lanes.contains { $0.note(at: pos)?.state.isFailure == true }
                        let color = failing ? palette.failure : palette.ambiguity
                        let barH = size.height * o
                        let rect = CGRect(x: CGFloat(px), y: size.height - barH, width: 1.2, height: barH)
                        ctx.fill(Path(rect), with: .color(color.opacity(0.28 + 0.6 * o)))
                    }
                }
            }
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.035)))
        }
    }

    // MARK: Lane row

    @ViewBuilder
    private func laneRow(_ lane: UncertaintyLane) -> some View {
        if lane.presentation == .braid {
            braidLane(lane)
        } else {
            stripLane(lane)
        }
    }

    /// A LANE OF THINGS WITH LIVES — the shape only, because names do not stack.
    ///
    /// A chapter can hold forty questions at once. Writing each one beside its bar was legible at three and a wall
    /// of prose at fifteen, and shortening the names is not available: a half-question is a different question.
    /// So the map carries what a map carries — WHERE each thing runs, HOW LONG, HOW MANY at once — and the names
    /// live in the host's own list beside it, sharing one selection. Bars, not labels; the depth line above says
    /// how crowded the story is at each point without naming anything.
    ///
    /// Selecting a bar reports it, and the host highlights whatever the span means in its own terms.
    @ViewBuilder
    private func braidLane(_ lane: UncertaintyLane) -> some View {
        let palette = UncertaintyPalette(scheme)
        let visible = isVisible(lane)
        let rows = lane.rows
        HStack(alignment: .top, spacing: 8) {
            laneGutter(lane, palette: palette)
            VStack(alignment: .leading, spacing: 3) {
                depthRibbon(rows: rows, visible: visible, palette: palette)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GeometryReader { proxy in
                        Canvas { ctx, size in
                            guard visible, score.spineEnd > score.spineStart else { return }
                            let span = Double(score.spineEnd - score.spineStart + 1)
                            for (i, note) in row.enumerated() {
                                let x0 = CGFloat(Double(note.start - score.spineStart) / span) * size.width
                                let x1 = CGFloat(Double(note.end - score.spineStart + 1) / span) * size.width
                                // A bar sits INSIDE its row with air above and below. Filling the row edge to edge
                                // made six packed rows read as one solid block, and a bar you cannot separate from
                                // its neighbour is a bar you cannot follow across the chapter.
                                             let rect = CGRect(x: x0, y: 2, width: max(4, x1 - x0 - 1), height: size.height - 4)
                                drawBraidBar(&ctx, note: note, rect: rect, rowHeight: size.height,
                                             tint: UncertaintyBraidPalette.tint(index: UncertaintyNoteVisualIdentity(laneID: lane.id, noteID: note.id).colorIndex,
                                                                                scheme: scheme),
                                             selected: selection?.id == note.id,
                                             dimmed: selection != nil && selection?.id != note.id)
                                // No closing edge where nothing closed: the bar frays onward rather than ending, so
                                // "still running when the observation stopped" needs no legend. It stops at the
                                // next thing on this row — running the fray THROUGH a later note made the two read
                                // as one broken bar, which is the opposite of what the packing is for.
                                if note.continuesPastEnd {
                                    let limit: CGFloat = i + 1 < row.count
                                        ? CGFloat(Double(row[i + 1].start - score.spineStart) / span) * size.width - 3
                                        : size.width - 1
                                    var fade = Path()
                                    var x = rect.maxX + 3
                                    while x < limit {
                                        fade.addRect(CGRect(x: x, y: rect.midY - 1.5, width: 4, height: 3))
                                        x += 7
                                    }
                                    ctx.fill(fade, with: .color(UncertaintyBraidPalette.tint(index: UncertaintyNoteVisualIdentity(laneID: lane.id, noteID: note.id).colorIndex, scheme: scheme).opacity(0.55)))
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            guard visible, score.spineEnd > score.spineStart else { return }
                            let span = Double(score.spineEnd - score.spineStart + 1)
                            let pos = score.spineStart + Int(location.x / proxy.size.width * span)
                            // Within this ROW only: two things on one row never overlap, so a click is unambiguous
                            // — which is the reason for packing rather than drawing everything on one strip.
                            if let hit = row.first(where: { $0.span.contains(pos) }) { select(hit) }
                        }
                        .overlay(alignment: .leading) {
                            markAccessibilityLayer(UncertaintyLane(id: lane.id, title: lane.title,
                                                                   isFailureAxis: lane.isFailureAxis, notes: row),
                                                   visible: visible, width: proxy.size.width)
                        }
                    }
                    .frame(height: Self.braidRowHeight)
                }
            }
            .opacity(visible ? 1 : 0.28)
        }
    }

    /// HOW MANY THINGS ARE ALIVE AT EACH POINT, as a shape. The braid's rows already answer it by eye at small
    /// counts; past a dozen the rows are too many to count, and this says "the story is carrying six things here,
    /// one here" in a single glance — the texture of a chapter, before any name is read.
    @ViewBuilder
    private func depthRibbon(rows: [[UncertaintyNote]], visible: Bool, palette: UncertaintyPalette) -> some View {
        Canvas { ctx, size in
            guard visible, score.spineEnd > score.spineStart, !rows.isEmpty else { return }
            let span = Double(score.spineEnd - score.spineStart + 1)
            let notes = rows.flatMap { $0 }
            let maxDepth = max(1, rows.count)
            var bars = Path()
            for px in stride(from: 0, to: Int(size.width), by: 1) {
                let pos = score.spineStart + Int(Double(px) / size.width * span)
                let depth = notes.reduce(0) { $0 + ($1.span.contains(pos) ? 1 : 0) }
                guard depth > 0 else { continue }
                let h = size.height * CGFloat(depth) / CGFloat(maxDepth)
                bars.addRect(CGRect(x: CGFloat(px), y: size.height - h, width: 1.2, height: h))
            }
            ctx.fill(bars, with: .color(palette.stroke(for: .ambiguity).opacity(0.28)))
        }
        .frame(height: 24)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func stripLane(_ lane: UncertaintyLane) -> some View {
        let palette = UncertaintyPalette(scheme)
        let visible = isVisible(lane)
        HStack(spacing: 8) {
            laneGutter(lane, palette: palette)
            GeometryReader { proxy in
                Canvas { ctx, size in
                    // Baseline
                    let baseline = CGRect(x: 0, y: size.height - 1, width: size.width, height: 1)
                    ctx.fill(Path(baseline), with: .color(.secondary.opacity(0.12)))
                    guard visible, score.spineEnd > score.spineStart else { return }
                    let span = Double(score.spineEnd - score.spineStart + 1)
                    for note in lane.notes {
                        let x0 = CGFloat(Double(note.start - score.spineStart) / span) * size.width
                        let x1 = CGFloat(Double(note.end - score.spineStart + 1) / span) * size.width
                        let rect = CGRect(x: x0, y: 2, width: max(3, x1 - x0 - 1), height: size.height - 4)
                        drawMark(&ctx, state: note.state, rect: rect, magnitude: note.magnitude,
                                 palette: palette, selected: selection?.id == note.id)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    guard visible, score.spineEnd > score.spineStart else { return }
                    let span = Double(score.spineEnd - score.spineStart + 1)
                    let pos = score.spineStart + Int(location.x / proxy.size.width * span)
                    if let hit = lane.note(at: pos) {
                        select(hit)
                    }
                }
                // FCIS-AX: A CANVAS IS OPAQUE TO THE ACCESSIBILITY TREE. The marks were drawn pixels with a single
                // hit-test behind them, so every mark on this score was invisible and unreachable to VoiceOver, to
                // an agent, and to an automated verifier — the standard's central failure mode ("custom-drawn views
                // MUST expose their content"). Drawing is untouched; this overlays one real element per note, so a
                // mark can be found by identity, read aloud, and activated without a pointer.
                .overlay(alignment: .leading) { markAccessibilityLayer(lane, visible: visible, width: proxy.size.width) }
            }
            .frame(height: Self.laneHeight)
            .opacity(visible ? 1 : 0.28)
        }
    }

    /// One accessibility element per drawn mark, laid over the Canvas with the same geometry the drawing uses.
    ///
    /// Transparent by construction — it adds no pixels and changes no encoding; it only gives the marks the presence
    /// in the accessibility tree that FCIS-AX requires of a custom-drawn surface. Each element carries a stable
    /// identifier (`uncertainty-note-<id>`), a spoken label naming the state, span and detail, and an activation
    /// that performs exactly what a click performs — so the tree is not a parallel description of the view but the
    /// same behaviour, reachable by identity.
    @ViewBuilder
    private func markAccessibilityLayer(_ lane: UncertaintyLane, visible: Bool, width: CGFloat) -> some View {
        if visible, score.spineEnd > score.spineStart, width > 0 {
            let span = Double(score.spineEnd - score.spineStart + 1)
            // The SAME wording the legend shows, so what is spoken and what is seen never diverge.
            ZStack(alignment: .leading) {
                ForEach(lane.notes) { note in
                    let x0 = CGFloat(Double(note.start - score.spineStart) / span) * width
                    let x1 = CGFloat(Double(note.end - score.spineStart + 1) / span) * width
                    markElement(note, lane: lane, width: max(3, x1 - x0 - 1)).offset(x: x0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// One mark's presence outside the Canvas: reachable by identity, activatable, draggable, and publishing
    /// where it is so a host can draw to it. Extracted because the whole thing in one expression stopped
    /// type-checking in reasonable time.
    @ViewBuilder
    private func markElement(_ note: UncertaintyNote, lane: UncertaintyLane, width: CGFloat) -> some View {
        let naming = UncertaintyPalette(scheme)
        let spokenName = note.title.isEmpty ? note.detail : note.title
        let label = "\(lane.title), \(naming.label(for: note.state)), lines \(note.start) to \(note.end)"
            + (spokenName.isEmpty ? "" : ". \(spokenName)")
        // NOT `Color.clear`: a fully transparent view takes no hover, so the tooltip never appeared over a band
        // (driven and checked — four seconds on the bar, nothing). A fill of almost-nothing is a real drawn
        // surface, invisible on screen and present to the pointer.
        Rectangle()
            .fill(Color.white.opacity(0.001))
            .frame(width: width)
            .accessibilityElement()
            .accessibilityIdentifier("uncertainty-note-\(note.id)")
            .accessibilityLabel(label)
            .accessibilityValue(UncertaintyClosureCue.text(for: note.resolvedBy))
            .accessibilityAddTraits(selection?.id == note.id ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { select(note) }
            .contentShape(Rectangle())
            // WHAT THIS BAND IS, ON HOVER. A braid carries no labels by design — names do not stack — but a
            // wordless bar is only legible once you already know what it is. The tooltip is the cheapest way to
            // ask "and this one?" without spending the room a label would.
            .help(spokenName.isEmpty
                  ? "\(lane.title), lines \(note.start)–\(note.end)"
                  : "\(spokenName)\n\(lane.title) · lines \(note.start)–\(note.end)")
            .anchorPreference(key: UncertaintyNoteAnchorsKey.self, value: .bounds) { [note.id: $0] }
            .ifLet(dragProvider) { view, provider in
                view.onDrag { provider(note) }
            }
    }

    private func laneGutter(_ lane: UncertaintyLane, palette: UncertaintyPalette) -> some View {
        HStack(spacing: 6) {
            Circle().fill(UncertaintyBraidPalette.tint(laneID: lane.id, scheme: scheme)
                .opacity(lane.peakState == .settled ? 0.4 : 0.9))
                .frame(width: 7, height: 7)
            Text(lane.title).font(.system(size: 11, weight: lane.isFailureAxis ? .semibold : .regular))
                // A lane's title is its identity. Truncating it ("Beats — questions held o…") makes the writer
                // guess at what they are looking at, so it wraps instead and the gutter grows.
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .foregroundStyle(isVisible(lane) ? .primary : .secondary)
            Spacer(minLength: 0)
            if showsMixer {
                mixButton("S", on: soloed.contains(lane.id)) { toggle(&soloed, lane.id) }
                mixButton("M", on: muted.contains(lane.id)) { toggle(&muted, lane.id) }
            }
        }
        .frame(width: Self.gutterWidth, alignment: .leading)
        .help(lane.isFailureAxis ? "A failure here means the span was not read or could not be grounded." : lane.title)
    }

    private func mixButton(_ label: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: 9, weight: .bold))
                .frame(width: 15, height: 15)
                .background(RoundedRectangle(cornerRadius: 3).fill(on ? Color.accentColor.opacity(0.85) : Color.primary.opacity(0.08)))
                .foregroundStyle(on ? Color.white : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ set: inout Set<String>, _ id: String) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
    }

    // MARK: Selection detail

    @ViewBuilder
    private var selectionDetail: some View {
        if let note = selection {
            let palette = UncertaintyPalette(scheme)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("lines \(note.start)–\(note.end)").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    Text(palette.label(for: note.state)).font(.caption.weight(.semibold))
                        .foregroundStyle(note.state == .failure ? palette.failure : (note.state == .settled ? Color.secondary : palette.ambiguity))
                }
                // THE DIAGNOSIS IS THE POINT OF THE WHOLE SCORE, so it is sized like one. Set in .callout it read as
                // a caption under a chart — the ribbon looked like the finding and the sentence looked like a
                // footnote, when the sentence is what the reading actually has to say. One step under the score's
                // own title (20pt), which is the largest a line may be without outranking the thing it belongs to.
                Text(note.detail.isEmpty ? "No detail was recorded for this span." : note.detail)
                    .font(.system(size: 17, weight: .regular))
                    .fixedSize(horizontal: false, vertical: true)
                let closureCue = UncertaintyClosureCue.text(for: note.resolvedBy)
                if !closureCue.isEmpty {
                    Text(closureCue).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.04)))
        } else {
            Text("Tap a mark to see what's open there and who could close it.")
                .font(.caption).foregroundStyle(.tertiary)
        }
    }

    // MARK: Mark drawing — the shape half of the encoding

    /// A BEAT IS A THING WITH A LIFE, SO IT IS DRAWN AS ONE SOLID RUN.
    ///
    /// `drawMark` draws a strip lane's *measurement* — a held dyad, two hairlines with a gap, which says "two
    /// readings sounded at once" and is right for that. On a braid it read as a pair of threads that were never
    /// there, and at row height it read as nothing at all. Here one bar is one thing, running for as long as it
    /// runs.
    ///
    /// Selection has to be unmissable: the whole row lights behind the chosen bar, the bar takes the accent, and
    /// everything else steps back. A 1.5-point outline on a 9-point bar was a selection only its author could see.
    private func drawBraidBar(_ ctx: inout GraphicsContext, note: UncertaintyNote, rect: CGRect, rowHeight: CGFloat,
                              tint: Color, selected: Bool, dimmed: Bool) {
        let base = tint
        if selected {
            let halo = CGRect(x: rect.minX - 3, y: 0, width: rect.width + 6, height: rowHeight)
            ctx.fill(Path(roundedRect: halo, cornerRadius: 4), with: .color(base.opacity(0.22)))
        }
        // The colour IS the identity, so selection cannot recolour it — it lights it and steps the others back.
        let body = base
        let strength = selected ? 1.0 : (dimmed ? 0.34 : 0.72 + 0.24 * note.magnitude)
        ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(body.opacity(strength)))
        if selected {
            ctx.stroke(Path(roundedRect: rect.insetBy(dx: -1.5, dy: -1.5), cornerRadius: 4),
                       with: .color(.primary.opacity(0.75)), lineWidth: 2)
        }
        // The state still has to survive greyscale: a thin darker keel along the foot of the bar carries it.
        let keel = CGRect(x: rect.minX, y: rect.maxY - 2, width: rect.width, height: 2)
        ctx.fill(Path(roundedRect: keel, cornerRadius: 1), with: .color(body.opacity(selected ? 1 : strength * 0.7)))
    }

    private func drawMark(_ ctx: inout GraphicsContext, state: UncertaintyState, rect: CGRect,
                          magnitude: Double, palette: UncertaintyPalette, selected: Bool) {
        let color = palette.stroke(for: state)
        switch state {
        case .settled:
            // A faint hum: a thin line at mid-height. Read, and fine.
            let y = rect.midY
            let line = CGRect(x: rect.minX, y: y - 0.75, width: rect.width, height: 1.5)
            ctx.fill(Path(roundedRect: line, cornerRadius: 0.75), with: .color(color.opacity(0.28)))

        case .thin:
            // A single low bar from the baseline.
            let h = max(3, rect.height * 0.4 * magnitude)
            let bar = CGRect(x: rect.minX, y: rect.maxY - h, width: rect.width, height: h)
            ctx.fill(Path(roundedRect: bar, cornerRadius: 2), with: .color(color.opacity(0.55)))

        case .ambiguity:
            // HELD DYAD — two bars, one high one low, with a gap: two readings sounded at once.
            let barH = max(3, rect.height * 0.32 * (0.6 + 0.4 * magnitude))
            let upper = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: barH)
            let lower = CGRect(x: rect.minX, y: rect.maxY - barH, width: rect.width, height: barH)
            ctx.fill(Path(roundedRect: upper, cornerRadius: 2), with: .color(color.opacity(0.85)))
            ctx.fill(Path(roundedRect: lower, cornerRadius: 2), with: .color(color.opacity(0.85)))

        case .failure:
            // LOUD and BROKEN — a full block with a silence cut through it and a caret above. Not a quiet chord.
            let block = rect.insetBy(dx: 0, dy: 1)
            ctx.fill(Path(roundedRect: block, cornerRadius: 2), with: .color(color.opacity(0.92)))
            // The silence: a surface-coloured gap slicing the block, so a breakdown reads as an absence.
            let gap = CGRect(x: block.midX - 1, y: block.minY, width: 2, height: block.height)
            ctx.fill(Path(gap), with: .color(Color(nsColor: .textBackgroundColor)))
            // Caret marker so the state survives greyscale / colour-blindness.
            var caret = Path()
            let cx = block.midX, cy = block.minY + 2.5
            caret.move(to: CGPoint(x: cx - 3, y: cy + 3))
            caret.addLine(to: CGPoint(x: cx, y: cy))
            caret.addLine(to: CGPoint(x: cx + 3, y: cy + 3))
            ctx.stroke(caret, with: .color(color), lineWidth: 1.5)
        }

        if selected {
            ctx.stroke(Path(roundedRect: rect.insetBy(dx: -1, dy: -1), cornerRadius: 3),
                       with: .color(.accentColor), lineWidth: 1.5)
        }
    }
}
