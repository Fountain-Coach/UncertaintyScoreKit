# Architecture

> For a plain-language introduction — what this is, who it's for, and why the four states matter — start with
> [`OVERVIEW.md`](OVERVIEW.md). This document is the technical design.

## The idea

A first pass over material — a close reading, an extraction, a classifier run — is far more reliable at reporting
**what it does and does not know** than at producing settled answers. Demanding confident, accessible results from
that pass is fighting a structural limit. So UncertaintyScoreKit changes the deliverable: the pass's product is a
**multi-dimensional map of its own uncertainty**, and later, better-equipped stages (or a person) turn that map into
answers. Every open thing carries a cue to *who could close it* — the map is a routing table, not a verdict.

## Why a score, not a bar

Uncertainty is not one axis. A single item can be perfectly grounded, referentially ambiguous, and interpretively
contested at the same time. Collapsing that to one confidence number throws away exactly what a later stage needs.
A score keeps the dimensions as parallel **lanes** (instruments) over a shared **spine** (source order / time / any
1-D coordinate) — the one thing a score does that a bar cannot.

Because a lane's row and label already carry the *dimension's* identity, colour is freed to carry **state**. The
palette is therefore just two colourblind-safe status hues plus neutral ink, and every state additionally has a
distinct **shape**, so the encoding survives greyscale, colour-blindness, forced-colours, and print.

## The four states, and the hard line

- `settled` — assessed and confident (a faint hum, not silence: evidence the item was read).
- `thin` — present but under-supported.
- `ambiguity` — genuinely open; the material supports competing readings. Drawn as a **held dyad**: two bars sounded
  together, the two readings held at once.
- `failure` — not assessed, ungrounded, or at fabrication risk. Drawn as a **loud broken block** with a silence cut
  through it.

The line the whole model exists to keep: **`ambiguity` is a result; `failure` is a breakdown.** They must read
differently in kind — failure louder, shaped as an *absence* — so a broken pass can never masquerade as honest
ambiguity. This is enforced as a type rule, not a hope: **absence is explicit.** There is no implicit `settled`
fill. A dimension never assessed for a span simply has no note there; a dimension assessed and found fine carries an
explicit `.settled` note. The two are different facts and the model keeps them different.

## Functional Core, Imperative Shell

- **Core (`UncertaintyScoreKit`)** — `UncertaintyScore`, `UncertaintyLane`, `UncertaintyNote`, `UncertaintyState`,
  and total functions (`openness(at:)`, `peakState`). Pure value types, Foundation only, no I/O, no UI. It does not
  know what a "reading" is.
- **Shell (`UncertaintyScoreKitUI`, `UncertaintyScoreDemo`)** — SwiftUI rendering, the solo/mute mixer, the triage
  ribbon, the arbitrary-lane rack, shared-spine viewport navigation, AX overlays, and the snapshot harness. All
  effects live here. Selection and viewport state are still pure `UncertaintyNavigatorState` values supplied to the
  shell.

The producer supplies the adapter from its own artifacts into `UncertaintyScore`, and that adapter stays on the
producer's side. This is the load-bearing boundary: it is what lets one view draw the uncertainty of anything —
a close reading, log triage, a labelling run — rather than one domain's.

### The reference adapter (illustrative, not shipped here)

The first producer maps a close-reading sufficiency taxonomy into the lanes: literal coverage, grounding, relations,
continuity, interpretation, ambiguity-preserved, counter-reading, adjudication, fabrication-risk, open-questions,
plus a synthesized provenance/trust lane. A scored deficiency becomes a note (its status → state, its recommended
next operation → the "who closes it" cue); an unflagged dimension becomes an explicit `settled` hum; genuine held
ambiguity (an unresolved adjudication, an equally-plausible counter-reading) becomes an `ambiguity` dyad even where
no deficiency was scored — because rendering that as settled would erase the very thing the pass worked to preserve.

## Browsing: the mixing desk

The interaction is a multitrack mixer. **Solo** a dimension to read it alone across the whole work; **mute** the
settled ones; read the `stacked` ribbon for triage — where many instruments play loud at once is where problems pile
up, and one `failure` in a column spikes the ribbon red so a single "not read" span still draws the eye.

The navigator is deliberately three resolutions of one collection: a searchable producer-ordered rack, a map whose
lanes share one source-coordinate viewport, and a stable selected-thread account. Search, state filters, focus,
solo/mute, pan, and zoom are explicit reader operations; none changes the producer order or drops data.

## Status and open questions

First cut. The encoding is proven by eye in light and dark; the magnitude→loudness mapping and lane density are
tuned against fixtures, not large real data. Before a `1.0`: tune against a real projection, add a DocC catalog, and
review the public API. See `PLANS.md`.
