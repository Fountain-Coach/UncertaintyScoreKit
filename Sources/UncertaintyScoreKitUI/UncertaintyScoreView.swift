import SwiftUI
import UncertaintyScoreKit

// The score, drawn. One row per dimension over a shared spine, mixed with solo/mute — a person browses the reading's
// uncertainty the way they'd browse a multitrack: follow one instrument, or read the whole texture at once.
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

public struct UncertaintyScoreView: View {
    public let score: UncertaintyScore
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
    @State private var selection: UncertaintyNote?

    public init(score: UncertaintyScore, onSelectNote: ((UncertaintyNote) -> Void)? = nil) {
        self.score = score
        self.onSelectNote = onSelectNote
    }

    private static let gutterWidth: CGFloat = 176
    private static let laneHeight: CGFloat = 34

    private var visibleLanes: [UncertaintyLane] {
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
            selectionDetail
        }
        .padding(18)
        .frame(minWidth: 620, alignment: .topLeading)
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: Header + legend

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(score.title).font(.system(size: 20, weight: .semibold))
            Text("What the first reading is unsure of — \(score.lanes.count) dimensions over lines \(score.spineStart)–\(score.spineEnd), from \(score.itemCount) passage\(score.itemCount == 1 ? "" : "s"). Solo or mute a dimension; the ribbon shows where problems stack up.")
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
            if !muted.isEmpty || !soloed.isEmpty {
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

    /// A LANE OF THINGS WITH LIVES: each note on its own packed row, each drawn over the span it covers, each
    /// carrying its name where the name can actually be read.
    ///
    /// The strip drawing answers "how uncertain is it here?". This one answers "what is running here, and for how
    /// long?" — a different question, and the one a lane of parallel things is asked. Depth is read by looking
    /// down: three rows deep at a position means three things alive at once.
    @ViewBuilder
    private func braidLane(_ lane: UncertaintyLane) -> some View {
        let palette = UncertaintyPalette(scheme)
        let visible = isVisible(lane)
        VStack(alignment: .leading, spacing: 7) {
            laneGutter(lane, palette: palette).frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(lane.rows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 3) {
                    GeometryReader { proxy in
                        Canvas { ctx, size in
                            let baseline = CGRect(x: 0, y: size.height - 1, width: size.width, height: 1)
                            ctx.fill(Path(baseline), with: .color(.secondary.opacity(0.12)))
                            guard visible, score.spineEnd > score.spineStart else { return }
                            let span = Double(score.spineEnd - score.spineStart + 1)
                            for note in row {
                                let x0 = CGFloat(Double(note.start - score.spineStart) / span) * size.width
                                let x1 = CGFloat(Double(note.end - score.spineStart + 1) / span) * size.width
                                let rect = CGRect(x: x0, y: 1, width: max(3, x1 - x0 - 1), height: size.height - 3)
                                drawMark(&ctx, state: note.state, rect: rect, magnitude: note.magnitude,
                                         palette: palette, selected: selection?.id == note.id)
                                // No closing edge where nothing closed: the bar frays into the margin instead of
                                // ending, so "still running when the reading stopped" is visible without a legend.
                                if note.continuesPastEnd {
                                    var fade = Path()
                                    let y = rect.midY
                                    var x = rect.maxX + 2
                                    while x < size.width - 1 {
                                        fade.addRect(CGRect(x: x, y: y - 1, width: 3, height: 2))
                                        x += 7
                                    }
                                    ctx.fill(fade, with: .color(palette.stroke(for: note.state).opacity(0.45)))
                                }
                            }
                        }
                        .overlay(alignment: .leading) {
                            markAccessibilityLayer(UncertaintyLane(id: lane.id, title: lane.title,
                                                                   isFailureAxis: lane.isFailureAxis, notes: row),
                                                   visible: visible, width: proxy.size.width)
                        }
                    }
                    .frame(height: 9)
                    // EACH NAME STARTS WHERE ITS THING STARTS. A packed row can carry several notes, and a plain
                    // list beneath it leaves the reader matching labels to bars by counting. Indenting a label to
                    // its own bar's left edge ties the two without a leader line — and a name that would start so
                    // far right that it could not be read pulls back to where it can.
                    ForEach(row) { note in
                        GeometryReader { proxy in
                            let span = Double(max(1, score.spineEnd - score.spineStart + 1))
                            let x = CGFloat(Double(note.start - score.spineStart) / span) * proxy.size.width
                            noteLabel(note).offset(x: min(x, max(0, proxy.size.width - 220)))
                        }
                        .frame(height: labelHeight(note))
                    }
                }
                .opacity(visible ? 1 : 0.28)
            }
        }
    }

    /// Two lines' worth of room, or three when the name is long: a braid label wraps rather than truncating, so the
    /// row it sits in has to make room for the wrap.
    private func labelHeight(_ note: UncertaintyNote) -> CGFloat {
        note.detail.count > 90 ? 44 : (note.detail.count > 45 ? 30 : 17)
    }

    @ViewBuilder
    private func noteLabel(_ note: UncertaintyNote) -> some View {
        Button { selection = note; onSelectNote?(note) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(note.detail)
                    .font(.system(size: 11))
                    // The whole name, always. These are questions, and half a question is a different question.
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                Text(note.continuesPastEnd
                     ? "\(note.start)–\(note.end) · still open"
                     : "\(note.start)–\(note.end)")
                    .font(.system(size: 10)).monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 320, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("uncertainty-note-label-\(note.id)")
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
                        selection = hit
                        onSelectNote?(hit)
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
            let naming = UncertaintyPalette(scheme)
            ZStack(alignment: .leading) {
                ForEach(lane.notes) { note in
                    let x0 = CGFloat(Double(note.start - score.spineStart) / span) * width
                    let x1 = CGFloat(Double(note.end - score.spineStart + 1) / span) * width
                    Color.clear
                        .frame(width: max(3, x1 - x0 - 1))
                        .offset(x: x0)
                        .accessibilityElement()
                        .accessibilityIdentifier("uncertainty-note-\(note.id)")
                        .accessibilityLabel("\(lane.title), \(naming.label(for: note.state)),"
                                            + " lines \(note.start) to \(note.end)"
                                            + (note.detail.isEmpty ? "" : ". \(note.detail)"))
                        .accessibilityValue(note.resolvedBy.map { "Closed by \($0)" } ?? "")
                        .accessibilityAddTraits(selection?.id == note.id ? [.isButton, .isSelected] : .isButton)
                        .accessibilityAction {
                            selection = note
                            onSelectNote?(note)
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func laneGutter(_ lane: UncertaintyLane, palette: UncertaintyPalette) -> some View {
        HStack(spacing: 6) {
            Circle().fill(palette.stroke(for: lane.peakState).opacity(lane.peakState == .settled ? 0.4 : 0.9))
                .frame(width: 7, height: 7)
            Text(lane.title).font(.system(size: 11, weight: lane.isFailureAxis ? .semibold : .regular))
                // A lane's title is its identity. Truncating it ("Beats — questions held o…") makes the writer
                // guess at what they are looking at, so it wraps instead and the gutter grows.
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .foregroundStyle(isVisible(lane) ? .primary : .secondary)
            Spacer(minLength: 0)
            mixButton("S", on: soloed.contains(lane.id)) { toggle(&soloed, lane.id) }
            mixButton("M", on: muted.contains(lane.id)) { toggle(&muted, lane.id) }
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
                if let resolvedBy = note.resolvedBy {
                    Text("Closed by: \(resolvedBy)").font(.caption).foregroundStyle(.secondary)
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
