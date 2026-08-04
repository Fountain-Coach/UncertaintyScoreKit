# PLANS.md

## Chapter 36 — addressed navigator and FCIS-AX release

- Add provider-independent composite addresses and pure navigation state.
- Add the searchable rack, shared-spine viewport, stable inspector, and AX parity to the SwiftUI shell.
- Release the additive API as `v0.8.0` through GitHub after the focused and full library tests pass.

This file defines the intent protocol for multi-step or high-risk work in this repository. Each plan states Goal,
Scope, Non-goals, Constraints, Plan (steps with status), Validation, Risks, and Results.

---

Title: UncertaintyScoreKit — first cut (2026-07-18)
Goal: Ship a provider-independent model and a SwiftUI renderer for the uncertainty of a first pass, drawn as an
orchestra of dimensions over a spine, with a snapshot harness so the encoding is verified by eye rather than asserted.
Scope: The pure core (`UncertaintyScore` / `UncertaintyLane` / `UncertaintyNote` / `UncertaintyState`, `openness`,
`peakState`); the SwiftUI view with solo/mute mixer, a triage ribbon, and shape+colour encodings; a demo/VRT harness
rendering fixtures (one close reading, one non-literary) to PNG; core unit tests; Functional-Core/Imperative-Shell
layering and FCIS repo files.
Non-goals: any producer's adapter (it lives on the producer's side — the core must stay ignorant of "readings");
audio playback; a persistence format (the score is a projection, not a store); tuning the encoding against large
real datasets (that is the next plan, and it needs real data).
Constraints: zero non-Swift dependencies; the core imports Foundation only; absence is explicit (no implicit settled
fill); `failure` must render louder and different in kind from `ambiguity`; the status palette must pass a
colourblind-safe validation on BOTH the light and dark surfaces; colour never carries dimension identity.
Plan:
- Step 1 (status: done) - Core value types + total functions; the grounded rule encoded in the initializers.
- Step 2 (status: done) - SwiftUI renderer: lane rows over the spine, the held-dyad / loud-broken-block encodings,
  the solo/mute mixer, the `stacked` triage ribbon, a selection detail with the "who closes it" cue.
- Step 3 (status: done) - Validated the two status hues (ambiguity vs failure) colourblind-safe and ≥3:1 on both
  surfaces (light #3E63DD/#D93A4A, dark #5B86E8/#EA5566). Every state is also a distinct shape.
- Step 4 (status: done) - Demo/VRT harness renders Telemachus + a non-literary log-triage fixture to PNG in light
  and dark. Both looked at; the failure-vs-ambiguity distinction reads on sight.
- Step 5 (status: done) - Core unit tests (grounded absence, failure-dominates-openness, state ordering, magnitude
  clamp, span normalization, peak state). All pass.
- Step 6 (status: pending) - Tune the encoding density and magnitude mapping against a large REAL projection, not a
  fixture. Requires a producer feeding real per-item, multi-dimension assessments.
- Step 7 (status: pending) - DocC catalog; a stable public API review before any `1.0`.
Validation:
- `swift build`
- `swift test`
- `swift run UncertaintyScoreDemo ./out` — inspect `uncertainty-telemachus-{light,dark}.png` by eye: failure reads as
  a loud, broken, red absence; ambiguity as a calm blue held dyad; settled as a faint hum; the ribbon spikes where
  failures stack.
Risks: the magnitude → loudness mapping and lane density are unverified against real data (fixture-tuned); a future
status-hue change silently breaks colourblind-safety unless both modes are re-validated; if an adapter ever leaks a
producer's type into the core, the "draws anything" property is lost.
Results:
- 2026-07-18: Steps 1–5 landed. Core + UI + demo build clean; 6 core tests pass; Telemachus verified in both themes.
  Promoted from a local target in the Reframe workspace to this standalone repo once the encoding was proven, exactly
  so no public API was cut around an unproven design.

---

Title: Report the selected note to the host (2026-07-27)
Goal: Let a host application react when the reader clicks a mark on the score — so the openness the map names can be
shown in the host's own terms (the passage, the beat, the line span it refers to) instead of dying inside the view.
Scope: `UncertaintyScoreKitUI` only — one optional `onSelectNote` closure on `UncertaintyScoreView`, invoked with the
core `UncertaintyNote` already resolved by the existing hit-test. Additive and source-compatible: the parameter
defaults to `nil` and the view's internal selection/detail behaviour is unchanged.
Non-goals: any knowledge of what a host does with the note (navigating, highlighting, scrolling — all the producer's
business); a selection BINDING (the view keeps owning its selection; a two-way binding would make the host
responsible for the view's internal state); reporting hover, mute or solo.
Constraints: FCIS layering — the callback hands back a CORE type, so the core still knows nothing about any
producer's domain (AGENTS invariant 2). No new dependencies. Semver: additive UI API on a pre-1.0 package → MINOR
bump to 0.2.0, per the FCIS versioning rule that additive change leaves existing requirements unchanged.
Plan:
- Step 1 (status: done) - `onSelectNote: ((UncertaintyNote) -> Void)?` on `UncertaintyScoreView`, defaulted to nil,
  called from the existing lane hit-test alongside setting `selection`.
- Step 2 (status: done) - Validation per `.codex/skills/repo-ops`: build, core tests, render the fixtures and LOOK
  (the encoding is untouched, so the PNGs must be unchanged in kind).
- Step 3 (status: done) - Tag v0.2.0.
Validation:
- `swift build`
- `swift test` — the core is unchanged, so all existing tests must still pass untouched.
- `swift run UncertaintyScoreDemo ./out` — the encoding did not change; confirm by eye that failure still reads as a
  loud broken red absence and ambiguity as a calm blue held dyad.
Risks: a host that does expensive work in the callback would do it on every mark click, on the main actor — the
closure is called synchronously from the gesture, so a host must keep it cheap. Noted here rather than defended
against, because throttling in the view would hide a host's own performance bug.
Results:
- 2026-07-27: Step 1–3 landed. Core untouched (6 tests pass unchanged); UI gained one optional closure; fixtures
  re-rendered and inspected in light and dark — encoding identical, as intended.

---

Title: Prospective closure-cue wording (2026-07-31)
Goal: Describe `resolvedBy` as the operation that could close an open note, never as a closure that already happened.
Scope: UncertaintyScoreKitUI visible detail and accessibility value, shared copy helper, focused tests, patch release.
Non-goals: renaming the compatible core field; adding Reframe ledger/want domain types; changing score encoding.
Constraints: core remains producer-independent; visual and AX copy must be identical; existing stored scores decode
unchanged.
Plan:
- Step 1 (status: completed) - Centralize and apply “Could be closed by” copy.
- Step 2 (status: completed) - Add tests and run package validation.
- Step 3 (status: completed) - Prepare v0.7.3 for Modernization Studio consumption.
Validation:
- `swift test`
- `swift build`
- `git diff --check`
Results:
- Visible detail and AX value now share `UncertaintyClosureCue`; neither claims a prospective operation already
  closed the note.
- `swift test` passed 13 tests; `swift build` passed.

---

Title: Shared note visual identity and reciprocal host selection (2026-08-04)
Goal: Give every mounted surface one stable visual identity and one selection address for the same uncertainty note.
Scope: Pure-core note visual identity token, SwiftUI palette adoption, host selection callback verification, focused
tests, FCIS release metadata.
Non-goals: Put SwiftUI colors in the core; encode semantics by color alone; change uncertainty states or producer
adapters; persist transient selection.
Constraints: Functional Core / Imperative Shell; core remains Foundation-only and producer-independent; color remains
reinforcement and every mark retains shape, label, and AX state. Additive public API on the pre-1.0 package requires
a minor release under the FCIS versioning rule.
Plan:
- Step 1 (status: completed) - Add `UncertaintyNoteVisualIdentity` and `UncertaintyScore.visualIdentity(for:)` in the
  pure core; make the identity deterministic from stable lane and note addresses.
- Step 2 (status: completed) - Make `UncertaintyScoreKitUI` render braid notes from the canonical token and expose
  the existing selection callback to the host.
- Step 3 (status: completed) - Make Reframe Copilot consume the same token and make score selection publish the same
  note address back to Copilot.
- Step 4 (status: completed) - Run package/app tests, build, AX checks, and Polyx live verification in both directions.
- Step 5 (status: completed) - Record the additive API as `v0.9.0` and update consumer pin/provenance.
Validation:
- `swift test` in this package.
- `swift build` and focused tests in Modernization Studio.
- Live AX: score mark selection reports the matching Copilot row as selected; Copilot selection focuses the matching
  score/source beat; no color-only claim is made.
Risks: changing the note tint seed changes screenshots; regenerate/inspect VRT fixtures and treat this as a deliberate
visual release change.
Results:
- One deterministic note identity now drives both the score braid and Copilot row tint.

Title: Semantic selection swell across mounted surfaces (2026-08-04)
Goal: Preserve canonical lane colors while making selection legible through a small shape swell rather than recoloring.
Scope: Score mark geometry, host Copilot row, and source Atom chrome.
Non-goals: Color as semantic authority, transient selection persistence, or changes to note state.
Constraints: FCIS-AX labels and selected state remain authoritative; color is reinforcement only; the package remains
Foundation-only in its core and keeps the UI behavior additive.
Plan:
- Step 1 (status: completed) - Keep the canonical note tint unchanged while enlarging the selected score mark.
- Step 2 (status: completed) - Apply the same tint and a 1.2% leading-edge swell to Copilot question rows.
- Step 3 (status: completed) - Apply the selected note tint to overlapping Atom cards and use a small card swell.
- Step 4 (status: completed) - Bump the pre-1.0 package minor version to `v0.10.0` and validate consumers.
Validation:
- `swift test`, `swift build`, focused app tests, and Polyx live AX verification.
Results:
- Selection no longer changes the semantic color on any surface; it swells the selected object while the exact same
  canonical color remains visible on Score, Copilot, and the related Atoms.
- Selection is explicitly handed from the score to the host as well as bound in the score view.
