# UncertaintyScoreKit — Agent Guide

Scope: A provider-independent model + SwiftUI renderer for the uncertainty of a first pass, drawn as an orchestra of
dimensions over a spine. Pure Swift, zero non-Swift dependencies.

Invariants
- Functional Core / Imperative Shell. `UncertaintyScoreKit` is the pure core: value types and total functions, no
  I/O, no UI, no dependencies (Foundation only). Effects — SwiftUI, rendering, file writes — live only in
  `UncertaintyScoreKitUI` and `UncertaintyScoreDemo`.
- The core must not depend on any producer's domain types. A producer adapts ITS artifacts into `UncertaintyScore`;
  that adapter lives on the producer's side of the boundary, never here.
- Grounded: absence is explicit. There is no implicit `settled` fill. A dimension never assessed for a span carries
  no note there; a dimension assessed and found fine carries an explicit `.settled` note. The two are different
  facts and stay different.
- `ambiguity` is a result; `failure` is a breakdown. They must render differently in kind — failure louder and
  shaped as an absence — so a broken pass can never masquerade as honest ambiguity.
- Colour carries STATE, never dimension identity (the lane's row + label already name the dimension). Every state
  also carries a distinct SHAPE, so the encoding survives greyscale, colour-blindness, forced-colours, and print.
- The status palette is validated colourblind-safe against both the light and dark surfaces (see PLANS validation).
  Changing a status hue requires re-validating both modes.
- Lane order is fixed by the caller and never cycled or repainted by a filter.
- MCP is optional capability only; repo correctness must not depend on MCP.

Routing
- For multi-step or high-risk changes, create or update `PLANS.md` before edits.
- Use skills for procedures: `.codex/skills/*/SKILL.md`.

References
- `docs/ARCHITECTURE.md` (the concept, the dimensions, the encoding, the FCIS layering)
- `README.md` (usage and commands)
