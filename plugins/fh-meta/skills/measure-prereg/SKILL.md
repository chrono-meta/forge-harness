---
name: measure-prereg
description: Routes a request to measure whether a rule, asset or change has an effect — «사전 등록 시작», «봉인하고 재보자», «아는 쌍으로 재», «pre-register this measurement» — to FH's existing procedure, measurement-integrity-checklist.md §Measured-Loop, with runs through scripts/sim_isolated_run.sh. A pointer only — it restates no step and blocks nothing. Boundary — sim-conductor orchestrates persona, user-reaction and audit simulations of an artifact, and steel-quench runs adversarial waves on one; either may call this procedure when one of its findings needs a measured yes/no or number. Use this skill when the request itself is «does X change Y, and by how much». Not for registering an account, sealing a release, or re-measuring a value with no claim attached.
user-invocable: true
allowed-tools: ["Read", "Bash"]
---

# measure-prereg — route a measurement to §Measured-Loop

FH already has the procedure. This skill only makes sure that procedure is the one that runs.

1. **Read `knowledge/shared/harness-core/measurement-integrity-checklist.md` §Measured-Loop now**, all
   of it, before writing a pre-registration: «다섯 걸음» (the five steps, in their order), the required
   fields of step ①, «기구 — 새로 짓지 마라» (instruments that already exist), «흔한 무효 사유 다섯»
   (the usual ways a run is voided) and its Done When. Nothing here replaces that text, and where this
   page and that section differ, that section wins.
2. **Runs go through `scripts/sim_isolated_run.sh`** in a disposable clone, never in the live repo.
   Read its header first. It keeps arms from writing into the working tree and from reading each
   other's output. It does not stop every side effect on the machine, so read its `observe` / `act`
   notes before choosing a mode.
3. **Before any number**, the checklist's §Instrument-Calibration applies — a known pair through the
   same grader, or the result is `UNCALIBRATED`.

How the operator's words map onto it: «사전 등록» / «봉인» = step ① written and sealed before any
record is opened · «아는 쌍» = calibration before the arms · «재보자» / «돌려» = the runs, only after
the first two.

Out of scope: a token run, API spend or a real-HOME run still needs its own approval — writing a
pre-registration does not grant one. The design judgment (arms, refutation condition, voiding) is the
governor's work. §Measured-Loop recommends an opus-tier session for it, so this skill pins no model.
