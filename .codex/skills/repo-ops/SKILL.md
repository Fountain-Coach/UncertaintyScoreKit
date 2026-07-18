# Skill: repo-ops

Purpose: Build, test, and visually verify UncertaintyScoreKit.

When to use: any change to the core, the renderer, or the fixtures — especially anything that touches an encoding
(shape or colour) or a status hue.

Steps:
1. Build everything: `swift build`.
2. Run the core tests: `swift test`. The core is pure, so these are fast and deterministic.
3. Render the fixtures and LOOK at them: `swift run UncertaintyScoreDemo ./out`. Open the PNGs. Confirm on sight:
   - `failure` reads as a LOUD, broken, red block with a silence cut through it — an absence, not a chord;
   - `ambiguity` reads as a calm blue held dyad (two bars sounded together);
   - `settled` is a faint hum; `thin` a low single bar;
   - the `stacked` ribbon spikes red exactly where failures pile up.
4. If a status hue changed, re-validate colourblind-safety on BOTH surfaces before shipping (light and dark each get
   their own steps, validated against that mode's surface — never an automatic flip). A pair failing CVD separation
   or the contrast floor is not shippable.

Output contract: a green `swift test`, four PNGs under `./out`, and — for any encoding change — a one-line note of
what was re-verified by eye and, if colours moved, the validation result for both modes.
