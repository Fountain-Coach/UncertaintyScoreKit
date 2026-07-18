# Overview — what UncertaintyScoreKit is, in plain language

UncertaintyScoreKit is a visual dashboard for showing exactly where an AI reading is **trustworthy, doubtful,
genuinely ambiguous, or simply broken** — aligned to the source it read.

It is **not** an AI model. It does not read a book, classify material, or decide what anything means. Another system —
for example a semantic-reading pipeline — does that work and produces a self-assessment. UncertaintyScoreKit takes
that assessment and turns it into a browsable SwiftUI view.

Think of it as an **X-ray viewer for an AI reading**. The reading system says: *"I examined these 560 lines. Here is
where I found strong evidence, where my support is thin, where the text permits two readings, and where I may have
failed altogether."* UncertaintyScoreKit makes that report visible.

> New here for the engineering? [`ARCHITECTURE.md`](ARCHITECTURE.md) is the technical design; the [`README`](../README.md)
> has the API and commands. This page is the plain-language tour.

## The problem it solves

Normally an AI system reads something and returns an answer — *"This scene is about Stephen's conflict with
authority."* That answer sounds equally confident whether it is directly supported by the passage, a debatable
interpretation, based on too little evidence, or partly invented.

A single confidence number — *82% confident* — does not fix this. The system might be certain who appears in the
scene, unsure of a pronoun, weakly supported in its interpretation, and flatly wrong about a quoted detail. **Those are
different problems.** UncertaintyScoreKit refuses to compress them into one score; it shows uncertainty in **separate
lanes**, all aligned to the same position in the source.

## Why it is called a "score"

"Score" in the musical sense. The source runs left-to-right, like time in a score. Each row is a different
instrument — here, a different **kind** of uncertainty.

```text
Source position     1────────100────────200────────300────────400────────500
Grounding           ───────────────░░████░───────────────────────░░───────
References          ─────▓▓▓───────────────────────────────────────────────
Interpretation      ──────────▓▓▓──────────────▓▓▓─────────────────────────
Fabrication risk    ─────────────────────██─██─────────────────────────────
```

Possible lanes might ask: did the system actually cover the passage? Are its claims grounded in specific text? Is it
clear who *he* / *she* / *it* refers to? Are relationships between events understood? Is the interpretation well
supported? Did it preserve a real ambiguity? Might it have invented something?

The lanes vary with the producing system. **UncertaintyScoreKit supplies the visual grammar, not the intellectual
taxonomy** — it never dictates what the dimensions must be.

## The four states

Every marked span of a lane carries one of four meanings (`UncertaintyState`), ordered by how much attention they owe:

1. **Settled** — checked, and reasonably confident. Rendered as a *faint hum*, never blank space, so you can tell
   *"checked and found no problem"* from *"never checked at all."* That distinction is one of the library's strongest
   ideas.
2. **Thin** — something is there, but the support is weak (one indirect detail). Not necessarily wrong; it needs
   reinforcement. Rendered as a low single bar.
3. **Ambiguity** — the material genuinely supports more than one reading (*"this may refer to Buck Mulligan or to
   Stephen; the passage does not decide"*). A legitimate result. Rendered as a **held dyad** — two bars sounded
   together, both readings held at once.
4. **Failure** — the reading process broke down: a span went unexamined, a claim is unsupported, evidence is cited
   outside the passage, or there is a fabrication risk. Rendered **loud and broken** — a block with a silence cut
   through it — deliberately more aggressive than ambiguity.

The central rule:

> **Ambiguity means the material remains open. Failure means the reading broke down.**

The whole package exists to keep those two from being confused — enforced by shape, by colour, and by a type rule:
**absence is explicit** (a span that was never assessed has *no* mark, distinct from an explicit `settled` hum).

### Why that distinction matters

Suppose a reading of *Ulysses* cannot decide whether a phrase is sincere or ironic. That may be *excellent* reading —
Joyce may have built the phrase so both stay active. It should be recorded as **ambiguity preserved**, not *model
failed to determine the answer*.

But suppose the reading claims *"Molly enters the room"* when Molly is not in the passage. That is not ambiguity — it
is a grounding/fabrication **failure**.

Without this distinction a system can fail in two damaging ways: hide failures behind polite language (*"the text is
ambiguous"*), or destroy genuine literary ambiguity by forcing a definite answer. UncertaintyScoreKit gives those
situations visibly different forms — and makes failure the *louder* one, so a small unread or ungrounded span never
hides inside an otherwise good result.

## What you actually see — a mixing desk

The interface is a multitrack mixer. You can **solo** the grounding lane and inspect grounding across the whole text;
**mute** settled material so only the unresolved areas remain; and read the combined **`stacked` ribbon** above the
lanes to see where several kinds of uncertainty accumulate. A span where grounding, reference, interpretation, and
fabrication risk all light up stands out as needing attention — and one severe failure spikes the ribbon on its own,
so it cannot disappear.

It is therefore both a **reading** interface (examine individual uncertainties) and a **triage** interface (decide
where to spend expensive model calls or human attention).

## "Who could close it" — a routing table, not a verdict

An uncertainty note can carry a recommended next action:

> **Problem:** claims cite no source line in this range. **Resolved by:** re-observe the passage.

Others might be: ask a stronger model to adjudicate; retrieve the surrounding chapter; ask a human; compare two
interpretations; verify a name against the source; leave the ambiguity open; rerun extraction for just this span.

So the map is not merely a warning display — it is a **routing table**. Each unresolved item says what operation
should happen next. That connects directly to cost: instead of re-sending a whole book to an expensive model, the
system can say *"most of this is adequate; these twelve spans need better grounding, these three need interpretive
adjudication, these two need human judgement, and these six ambiguities should stay open"* — and spend intelligence
selectively.

## What the package contains

Three pieces, in a Functional-Core / Imperative-Shell split (see [`ARCHITECTURE.md`](ARCHITECTURE.md)):

- **`UncertaintyScoreKit`** — the pure data model: the score, a lane, a note, the four states, and calculations like
  how open or severe a position is ([`Sources/UncertaintyScoreKit`](../Sources/UncertaintyScoreKit)). It is
  independent of any reading system — it does not know what *Ulysses*, semantic indexing, or close reading are.
- **`UncertaintyScoreKitUI`** — draws the score in SwiftUI: lanes, shapes, colours, solo/mute, the triage ribbon
  ([`Sources/UncertaintyScoreKitUI`](../Sources/UncertaintyScoreKitUI)).
- **`UncertaintyScoreDemo`** — renders prepared fixtures to PNG so the visual language can be *looked at* in light and
  dark ([`Sources/UncertaintyScoreDemo`](../Sources/UncertaintyScoreDemo)).

## What it deliberately does not contain

It does **not** convert any producer's output into a score automatically. The producer supplies an **adapter** that
translates its own records into the generic form. In plain terms: UncertaintyScoreKit provides the blank musical
notation paper and knows how to display it; the producer decides which instruments exist and writes the notes.

An adapter might translate `unsupported_entity_name` into *Lane: Fabrication risk · State: Failure · lines 291–330 ·
Repair: re-read and verify named entities*; or *two plausible speaker referents* into *Lane: Referential clarity ·
State: Ambiguity · lines 102–118 · Repair: preserve both readings unless later context resolves them*.

## Status — solid vs. experimental

Version **0.1.0**, a first cut. The data model, the SwiftUI renderer, and the snapshot harness exist, and the encoding
is proven by eye in light and dark. The visual **density** and **severity mapping** have been tuned against designed
fixtures, not large real datasets. So this is a coherent, implemented **visual language** — not yet a mature analytics
product validated on thousands of readings. Before `1.0`: tune against real projections, add a DocC catalog, and
review the public API (see [`PLANS.md`](../PLANS.md)).

## The deepest idea

The most important part is not the SwiftUI rendering — it is the **changed contract** with the first-pass model.

The usual contract: *"Read this and give me the answer."* This one: *"Read this and give me a disciplined account of
what you know, what you only weakly support, what the source genuinely leaves open, and where your own reading
failed."* The first pass no longer has to impersonate final intelligence.

```text
Source text
    ↓  cheap or on-device first reading
Structured uncertainty score
    ↓  selective repair, routed by each note:
       · local re-reading      · cached evidence
       · a stronger model call  · human judgement
       · deliberate preservation of ambiguity
    ↓
Trusted semantic memory
```

So UncertaintyScoreKit is the missing **control surface** between an inexpensive first reading and more expensive,
more authoritative later work. Its practical promise:

> Don't spend flagship-model intelligence everywhere. First make uncertainty **visible, classified, and actionable** —
> then spend intelligence exactly where it is needed.

## Where to go next

- [`ARCHITECTURE.md`](ARCHITECTURE.md) — the technical design: states, encodings, the mixer, the producer seam.
- [`README.md`](../README.md) — usage, the API, and how to build, test, and snapshot.
- [`PLANS.md`](../PLANS.md) — the first-cut plan and what remains before `1.0`.
