---
name: live-surface-automation-pattern
description: The capability pattern FH routes to when a mapping project needs an agent to drive a live UI surface (web/mobile) — observe-act-verify over the running app, not code/data fetch. FH routes drivers (no-reinvention); the value is the cross-platform observe-act-verify contract, the Appium-less principle, and the hybrid-WebView vision-synthesis rule. Generalizable across mapping projects; not tied to any one project.
date: 2026-06-14
tags: [live-surface, ui-automation, observe-act-verify, appium-less, hybrid-webview, no-reinvention, mapping-acceleration]
---

# Live-Surface Automation Pattern

When a mapping project's work lives on a **live UI surface** — a running mobile app or web page whose
state cannot be reached by reading code or fetching data — FH's posture is the same as for any
capability it does not own: **detect the need and route to the best driver present, do not build a UI
engine** (no-reinvention). The value FH adds is the *contract* below, not a new automation tool.

This is the acceleration axis behind the "③ map-project acceleration" door's live-surface capability
(`[[fh-live-surface-acceleration]]`). It was first validated on web (Playwright MCP); the 2026-06-14
validation extended it to mobile (Android + iOS) and surfaced the two principles that make it work.

## The observe-act-verify contract (driver-agnostic)

Every driver fills the same six primitives; the runner above them is identical regardless of backend:

| primitive | role | verdict impact |
|---|---|---|
| launch | bring the app/page up | failure → BLOCKED |
| screenshot | vision-channel capture | evidence |
| observe | structured element tree (XML/AX/DOM) → normalized elements | candidate ranking input |
| tap | element/coordinate action | act |
| input_text | text entry | act |
| screen_signature | pre/post comparison | re-observe |

A TC/step's intent text is ranked against observed elements (text · description · role · clickable ·
bounds), the top candidate is acted on, and the post-action observation is checked **mechanically**
(target text present/absent + candidate count + adapter exit) — no judge LLM decides the verdict.

## Driver routing (no-reinvention)

| surface | driver | note |
|---|---|---|
| web | Playwright MCP (Claude-usable) / Stagehand | generic-coding-agent usable — covers users without a proprietary browser-agent app |
| Android (emulator **or** real device) | `adb` + `uiautomator dump` + `input tap` | same code path for both — see Portability below |
| iOS simulator | `idb ui describe-all` + `idb ui tap` (idb-companion + fb-idb) | native AX tree |
| hybrid WebView region | **vision channel** (screenshot + element detection) | native AX is blind here — see Hybrid rule |

FH routes; it does not reimplement these. Drivers are pluggable; the contract is fixed.

## ★ Principle 1 — Appium-less is the enabler

Going **through Appium is the failure mode**, not the solution. Appium's WebView-context switching is
flaky on hybrid apps; in one field case it burned a large automation budget without completing a single
hybrid flow (repeated run→fail→rerun). The **direct path** (`uiautomator dump` / `idb describe-all` +
coordinate tap + vision) bypasses that failure mode entirely. Appium is therefore *one regression-stage
adapter*, not the exploration/execution substrate.

## ★ Principle 2 — Hybrid WebView is opaque to native accessibility → synthesize vision

Live-measured (2026-06-14, iOS hybrid sandbox): a WKWebView's **web content does not appear in the
native accessibility tree** — only native chrome and bridge-triggered native overlays do. A tap on a
web button fired the web→native bridge and the resulting native picker *did* appear in the AX tree
(4→10 elements), confirming the boundary precisely.

→ For hybrid apps, the observe channel must be **synthesized**: native AX for native targets + **vision
(screenshot + element detection) for the WebView interior** + optionally a web-layer inspector. An
XML/AX-only agent silently misses the entire web form. This converges with the external frontier
finding that SOTA UI automation is hybrid (AX/accessibility for action targets, vision for grounding
and verification, deterministic probes for assertions).

## Portability — design on simulator, run on real device (Appium-less)

Because the Android driver uses the same `adb -s <serial>` interface for an emulator and a USB-connected
real device, a structure authored and validated on the **simulator runs unchanged on the real device**
— no per-device manual element extraction. Live-measured: a flow validated on the emulator auto-extracted
the full native element set on a real-device banking sandbox with zero code change. This portability —
sim-authored → real-device execution without Appium — is itself a meaningful capability step (a project
may ship it before any AI-prospective layer).

## Caveats (honest scope)

- Element-ranking *accuracy* (intent → correct element) is unmeasured until a project supplies real
  fixtures from its own app; the contract and loop are validated, the ranking quality is per-project.
- Native-only screens work out of the box; hybrid screens need the vision channel wired (a pluggable
  detector — FH routes to a vision model, does not build one).
- Korean / IME text entry on Android real devices via `adb input text` is unreliable (measured) — needs
  an IME-broadcast keyboard, not raw input.

## Cross-refs

`[[fh-live-surface-acceleration]]` (the capability-axis memory) · `multi_model_sidecar_strategy.md`
(surface routing) · `deep_research_capability_ladder.md` (the sibling "route, don't build" pattern for
research). The 2026-06-14 frontier survey backing the hybrid-SOTA convergence lives in the private
companion store (`paper-signals/frontier_computer_use_ui_automation_2026-06-14.md`).
