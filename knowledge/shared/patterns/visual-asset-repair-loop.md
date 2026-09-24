---
name: visual-asset-repair-loop
description: Techniques for repairing raster animation assets (sprite/APNG frames) with an operator in the loop — measure before tuning, reconstruct past transforms as controls, prefer direction-separable warps over cut-and-paste, and make "does it shake / is it clean" a gate instead of an eye test. Distilled from one night of desktop-pet art repair (2026-09-24) where the operator caught every visual defect first.
type: reference
tags: [pattern, visual-assets, animation, instrument-calibration, operator-in-the-loop, field-harness]
---

# Visual asset repair loop

**Provenance.** One night, one field harness (a desktop-pet app whose states are APNG loops), ~12 merged
art fixes. The operator reviewed every change in a browser preview and **caught every defect before the
governor did** — outline chips, head/body proportion, a trapezoid face, torn shoulders, frame-to-frame
shake (twice). Self-catch count: 0. This file is what that night teaches, stated so another harness can
reuse it without the character, the app, or the company.

## 1. The review surface is part of the instrument

- **Serve the bytes the app will read, and prove it.** A preview page that shows an old file is worse than
  no preview. After starting it, fetch each changed asset back through the page's own URL rule and
  byte-compare with the repo copy — and request a nonexistent file to confirm the comparison can fail
  (a 404 control). Twice that night the first comparison was wrong for instrument reasons: a port already
  held by an older preview server (answering 200 for a different directory), and an extraction that pulled
  empty URLs and "compared" nothing.
- **Look at the operator's scale and background.** Zoomed crops find pixel faults the operator cannot see
  and hide shape faults they can. Render both, and judge at the size the operator reported from.
- **A crop claim must contain what it claims.** Derive every crop box from the target's own bounding box
  and label it. The governor once reported "joints are clean" from a crop framed on the cheek. Say what the
  crop shows, not what it was meant to show.
- **An animated image drawn to a canvas is one frame.** Capturing "several loop phases" that way silently
  yields the same frame N times.

## 2. Measure before you tune — and calibrate each measure on a known pair

| Question | Instrument that answered it | Controls that proved it alive |
|---|---|---|
| Is the new outline the same thickness as the old? | distance-transform ridge width of the dark mask (2 × EDT at local maxima), split by distance from the head | synthetic bars of 6 px and 10 px read back 6.0 and 10.0 |
| Is the head still an oval? | IoU between the head mask and the ellipse with the same second moments; plus upper-vs-lower width ratio for trapezoid drift | true ellipse 0.999 · trapezoid 0.758 |
| Does the whole body slide between frames? | per-row left/right contour x, median shift vs frame 0, averaged; range over frames | arm-only motion reads 0 · 2 px body shift reads 2 · real file-read path reads 2 |

Two failure shapes to avoid, both hit that night:
- **Extreme points confuse motion with drift.** Left/right-most pixel amplitude moved "3 → 1 → 3" across
  versions and answered nothing — a waving arm and a sliding body look identical to it. Row-median contour
  shift separates them.
- **A self-check that feeds data directly skips the path the bug lives on.** The first body-sway tool read
  frames with `list(ImageSequence.Iterator(im))`, which returns the same object repeatedly (every frame
  became the last one → all motions read 0.0). Its self-check passed because it built frame lists in memory.
  The fix added a leg that writes a synthetic APNG and reads it back through the real path.
- **Carry-over numbers are not measurements.** A stroke width measured on a different motion with a loose
  threshold (8 px) was reused; the true value was 6 px, and the redrawn outline came out visibly heavy.

## 3. When every repair round creates a new artifact, change the question

Head-only shrinking (to fix a head that read too large) was attempted seven ways: cut-and-paste with seam
patching, redrawing the outline, rule-based gap filling, and three partial warps. Every one tore the
shoulders somewhere, because **"shrink the head, keep the shoulders fixed" forces a discontinuity at the
joint** — any fill is invented content, any partial pull bends lines.

What worked was a **direction-separable warp**: uniform scale on one axis for the whole figure (so no
relative distortion anywhere), and on the other axis scale only above the neck with a short smooth ramp.
A smooth monotone mapping in one variable cannot kink a line, so the joints stayed the original art. The
cost (body 7 % narrower) was stated with numbers and accepted by the operator.

Heuristic: if two consecutive rounds each introduce a *new* defect class at the same place, stop patching
that place and ask what constraint makes the place impossible. (Same shape as this repo's convergence rule:
if it does not converge, loosen or reframe — do not tighten.)

## 4. Reconstruction as a control — exact fixes without re-rendering

A batch resize had applied the same scale to every frame but a **different integer offset per frame**
(it re-centered each frame on its own bounding box), which made still poses shake. To fix only position:
re-run the old transform from the pre-change originals and require the result to equal the current file
**pixel for pixel**. Where it matches (9 of 10 motions), the per-frame offsets it computes are exact, and the
fix is integer shifts — no resampling, pixels untouched. Where it does not match (1 motion), do not touch it:
the transform is not the whole story there.

Corollaries:
- **Batch normalization must use one offset per motion** (union bounding box), never per frame. Its self-check
  fixture must *contain* inter-frame motion; a fixture whose frames are already aligned passes the bug.
- **Thresholds depend on the motion type.** A 4 px cut-off correctly found shaking in lively motions and
  missed a lying-still pose where 1 px is visible.
- **"Restore the original" is not always the goal.** One motion's original itself drifted 3 px; restoring
  made it worse. The operator's intent was "hold it still", so the fix cancelled the measured drift instead.
  Judge each motion against the intent, not against provenance.

## 5. Smaller techniques worth keeping

- **Transplant, don't synthesize.** Chipped outline pixels in a few frames were repaired by copying the
  damaged band from the best-aligned clean frame of the same loop (alignment by alpha residual; refuse when
  no donor fits). A morphology repair scored better on its own metric and looked worse — the metric looked
  along the same axis as the repair.
- **Bisect a defect's origin before blaming the latest change.** The chipped outline existed in the version
  before the two most recent edits; reverting them would have fixed nothing.
- **A hole connected to the outside is not a hole.** `fill_holes` treats a transparent sliver that leaks to
  the canvas edge through a 1-px gap as "outside". Close the silhouette first, then find the interior.
- **Test the resampler hypothesis by swapping the resampler.** A white fringe blamed on Lanczos ringing
  survived a switch to box filtering — refuted; the real cause was the leaking hole above.
- **Land agreements where the next editor reads them.** A "keep the base disc fixed while the character
  turns" decision was never written down; a later batch tool broke it silently and a full search of every
  record channel found nothing. The fix restored it and wrote it into the field harness's asset map.
- **Make the eye test a gate.** After the operator caught frame shake twice, a ratchet lane (per-motion
  body-sway baseline, block on +0.5 px, block on unmeasured new motions) went into the field gate, and a
  deliberate 1 px shift of one frame was confirmed to be blocked.
