# PLANS.md

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
