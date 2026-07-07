# Draenor Preservation Plan

This plan keeps the project focused on a reproducible WoD 6.2.3.20779
preservation baseline before adding optional gameplay or living-world layers.

## Phase 1: Reproducible Build

Goal: make the source build from a clean checkout with documented prerequisites.

- Record host and container toolchain versions.
- Document CMake options, build directory layout, and required packages.
- Preserve every source compatibility fix with file paths and proof.
- Keep patches small and attributable to build/runtime compatibility.
- Verify both `authserver` and `worldserver` binaries are produced.

Exit criteria:

- A fresh builder can reproduce the build.
- Build fixes are documented with cause, proof, files changed, and verification.

## Phase 2: Reproducible Runtime

Goal: make auth, world, database, and local client routing start consistently.

- Document database ports, schemas, and seed data.
- Document authserver and worldserver launch commands.
- Document NGDP/client routing and patched-client requirements.
- Avoid fragile shell/session patterns that shut down `worldserver`.
- Capture logs needed to prove startup health.

Exit criteria:

- `authserver` starts.
- `worldserver` reaches `World initialized`.
- Exactly one worldserver listens on `8085`.
- The 20779 client can reach login and realm flow.

## Phase 3: 20779 Protocol/Movement Correction

Goal: correct client/server protocol compatibility enough for normal movement.

- Instrument unknown client opcodes without changing dispatch.
- Run marked movement matrices against a 6.2.3.20779 client.
- Separate movement packets from login, UI, addon, and session noise.
- Add opcode aliases only after action-correlated evidence exists.
- Document packet size, first payload bytes, frequency, and position changes.

Exit criteria:

- Client can move normally.
- Movement fixes are tied to logs and reproducible tests.
- No opcode mappings are guessed.

## Phase 4: World Playability Baseline

Goal: verify the baseline world is usable after movement works.

- Confirm spawn visibility and basic interaction.
- Confirm NPC click/query behavior.
- Confirm logout/login stability.
- Confirm no crash loops or immediate disconnects during ordinary movement.
- Identify DB/content blockers separately from protocol blockers.

Exit criteria:

- A player can enter, move, interact with basic world objects/NPCs, and relog.
- Remaining issues are categorized as content, DB, script, or system gaps.

## Phase 5: WoD-specific Systems Audit

Goal: inventory WoD-specific systems before deciding restoration priorities.

- Audit garrisons, scenarios, phasing, area triggers, conversations, vignettes,
  taxis, quest flow, and spell/aura systems.
- Label each area as confirmed, broken, stubbed, unknown, or out of scope.
- Avoid implementing systems before the audit identifies what is preserved.

Exit criteria:

- WoD system status is documented with evidence and source locations.
- Restoration work can be prioritized without guessing.

## Phase 6: Restoration Work

Goal: restore broken baseline systems using evidence-backed patches.

- Fix protocol, DB, script, and content defects in small batches.
- Record reproduction and verification steps for each fix.
- Prefer upstream-like behavior over custom design.
- Keep temporary instrumentation clearly labeled and removable.

Exit criteria:

- Restored systems have acceptance tests or clear manual verification steps.
- Documentation explains what changed and why.

## Phase 7: Living-world / DIT Layer

Goal: only after preservation is stable, evaluate optional living-world features.

- Treat DIT population, bots, simulation, and custom gameplay as a separate layer.
- Keep the preservation baseline separable from optional enhancements.
- Do not let custom systems obscure protocol, DB, or content preservation work.

Exit criteria:

- Optional systems are explicitly scoped and reversible.
- Baseline preservation remains reproducible without the DIT layer.
