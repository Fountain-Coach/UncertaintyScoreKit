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
