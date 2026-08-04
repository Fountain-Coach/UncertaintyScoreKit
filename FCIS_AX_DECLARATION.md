# FCIS-AX Declaration

- Standard: FCIS-AX 1.0.
- Surfaces: `UncertaintyScoreNavigatorView` and the compatibility `UncertaintyScoreView`.
- Custom-drawn views: aggregate ribbon, lane strips, braid rows, and uncertainty marks rendered with `Canvas`.
- AX identifiers: navigator controls, lane rack rows, lane actions, and marks use stable IDs derived from
  `UncertaintyAddress(laneID:noteID)`; no title or detail text participates in identity.
- AX-driven verification: `UncertaintyScoreKitTests` covers address/navigation invariants; host applications must
  perform live AX parity checks for their mounted window, including count, state, selection, and activation.
- Cross-surface identity: `UncertaintyNoteVisualIdentity` is a core token; color is reinforcement only. Hosts must
  expose selected state, stable note IDs, labels, and actions through AX and must not use color as the sole meaning.
- Known gaps: none in the shipped kit surfaces; host-specific evidence and action controls remain the producer
  adapter's responsibility.
