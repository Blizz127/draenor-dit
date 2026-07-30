# Phase 4A: WoD 20779 Gameplay Baseline Smoke Test

Status: **Planned — no Phase 4A playthrough has been run yet**

Scope: WoD 6.2.3.20779 gameplay compatibility inventory and evidence collection

Reference client: [Supported Client Baseline: WoD 6.2.3.20779 enUS](../client/20779-enUS-baseline.md)

Phase 3J established that the supported client can log in, chat, move, and
interact with an NPC. Phase 4A must re-test those prerequisites with a fresh
character before expanding into gameplay. Firestorm-client results are not
reference-client results, and the closed movement investigation must not be
reopened unless the supported clean-client baseline produces a new,
reproducible movement failure.

This document is a test plan and result ledger. An unchecked item means **not
yet tested in Phase 4A**, not failed.

## Environment

Record the exact environment at the start of each run. If it changes during a
run, stop and begin a new run record.

| Field | Phase 4A baseline |
|---|---|
| Client build | WoD 6.2.3.20779 |
| Locale | enUS text and audio |
| Executable | `Wow-64-Patched-Offline.exe` |
| Portal | `localhost` |
| Client launcher | `bash runtime/launch-client-gamescope.sh` |
| Runtime | gamescope + umu; see the supported client baseline for the validated prefix and Proton details |
| Server core | Draenor-Core `e49b878fac7e1cb731a6ab07f37bb24ecd19ede4` (`Remove temporary 20779 movement probes`) |
| Database revision | Live `world.version`: `db_version=FirestormDB Febuary 2016`, `cache_id=81`, `core_revision=unknown` |
| Test character | Not created |
| Test date/time | `YYYY-MM-DD HH:MM:SS TZ` |
| Operator | |
| Server log window | `start line/time` → `end line/time` |
| Client log window | `file` and modification time |

The database value is recorded exactly as returned by the live database,
including its spelling. It is an identity marker, not proof that every schema
or content update is present.

### Inherited Phase 3J prerequisites

These are confirmed for the supported client baseline, but still require
fresh-character Phase 4A coverage:

| Behavior | Prior result | Phase 4A status |
|---|---|---|
| Login and character selection | Confirmed in Phase 3J | Not yet re-tested |
| In-game chat | Confirmed in Phase 3J | Not yet re-tested |
| Movement with changing position | Confirmed in Phase 3J | Not yet re-tested |
| NPC selection/gossip/questgiver interaction | Confirmed in Phase 3J | Not yet re-tested |

## Result rules

- Check an item only after observing it with the supported client during the
  recorded test window.
- Record what happened, not what the code or database suggests should happen.
- A missing observation is **Not tested**, not Pass or Fail.
- Attach a server log line/time, client log entry, screenshot, or concise
  reproduction for every failure.
- Do not infer an opcode problem from a gameplay symptom. Use `Unknown` until
  packet evidence establishes a protocol cause.
- Do not use GM teleport, quest-complete, level, item, or spell commands during
  the initial path.
- Do not compare against the Firestorm executable as a reference client.

Recommended result notation:

- `[x]` — confirmed working in the recorded run
- `[ ]` — not yet tested
- `FAIL` beside an unchecked item — confirmed failure with an issue entry
- `BLOCKED` beside an unchecked item — could not reach the test because of an
  earlier confirmed issue

## Phase 4A Milestone 1

Goal:
Complete the first 30 minutes of normal Human Warrior progression.

Success criteria:

- Create character
- Enter world
- Complete Northshire opening quests
- Kill creatures
- Loot items
- Equip items
- Train if naturally available
- Turn in quests
- Reach first Elwynn progression

No expectation:

- Garrison
- Draenor systems
- Dungeons
- Endgame systems

## Server Health Baseline

Before creating the test character:

- [ ] authserver running without errors
- [ ] worldserver running without errors
- [ ] database connections healthy
- [ ] no repeated SQL errors during startup
- [ ] no client connection warnings during login

Record:

| Field | Value |
|---|---|
| authserver start time | |
| worldserver start time | |
| first client login time | |
| relevant log locations | |

## Core Login Test

- [ ] Auth login
- [ ] Character list
- [ ] Enter world
- [ ] Logout
- [ ] Reconnect
- [ ] Character creation

Notes/evidence:

| Item | Result | Evidence |
|---|---|---|
| | | |

## Basic Player Test

- [ ] Movement
- [ ] Jumping
- [ ] Swimming
- [ ] Combat
- [ ] Auto attack
- [ ] Spell casting
- [ ] Resource generation
- [ ] Death/release
- [ ] Resurrection

Notes/evidence:

| Item | Result | Evidence |
|---|---|---|
| | | |

## World Interaction Test

- [ ] NPC interaction
- [ ] Vendors
- [ ] Trainers
- [ ] Quest accept
- [ ] Quest completion
- [ ] Loot
- [ ] Mail
- [ ] Flight paths

Notes/evidence:

| Item | Result | Evidence |
|---|---|---|
| | | |

## Quest/Content Test

Test in normal play order. Do not skip ahead when an earlier step is broken.

- [ ] Starting zone quests
- [ ] First hub progression
- [ ] Quest objectives update from kills
- [ ] Quest objectives update from loot
- [ ] Quest objectives update from object interaction
- [ ] Quest turn-in and rewards
- [ ] Phasing changes
- [ ] Scripted events

For each quest tested, record:

| Quest name/ID | Accept | Objectives | Completion | Reward | Phase/script | Evidence |
|---|---|---|---|---|---|---|
| | | | | | | |

## WoD Systems

These are inventory targets, not the first playthrough milestone. Do not begin
with garrison testing.

- [ ] Garrison introduction
- [ ] Followers
- [ ] Mission table
- [ ] Shipyard, if reachable
- [ ] Draenor zones
- [ ] Scenarios
- [ ] Dungeons

Record the normal-play prerequisite used to reach each system. Do not mark a
system failed merely because the first-character route has not unlocked it.

## Protocol/Errors

Record only errors observed within the marked run window:

- [ ] Server errors reviewed
- [ ] Client disconnects reviewed
- [ ] Unknown opcodes reviewed
- [ ] Missing data reviewed
- [ ] Client/server crashes reviewed
- [ ] SQL errors reviewed

| Time | Character/location | Symptom or exact error | Source | Related test/issue |
|---|---|---|---|---|
| | | | | |

An unknown opcode is evidence only when its timestamp belongs to the tested
action window. Do not map or implement it during Phase 4A.

## Issue classification

Create one entry per distinct reproducible symptom.

### Category

- **Client issue** — supported client data, UI, local configuration, or runtime
- **Server core issue** — server behavior implemented incorrectly in core code
- **Database/content issue** — missing or incorrect world/hotfix data
- **Missing script** — content exists but required scripted behavior is absent
- **Missing packet/opcode** — packet evidence identifies absent protocol support
- **Unknown** — evidence does not yet distinguish the layer

### Severity

- **Blocker** — prevents login, world entry, or all further progress on the
  selected playthrough path
- **Major** — breaks a core feature or required quest path without a normal
  workaround
- **Minor** — localized malfunction with continued progression possible
- **Cosmetic** — presentation defect without gameplay impact

### Issue entry

| Field | Value |
|---|---|
| ID | `P4A-001` |
| First observed | `YYYY-MM-DD HH:MM:SS TZ` |
| Character/class/level | |
| Map/zone/coordinates | |
| Test step | |
| Expected behavior | |
| Confirmed behavior | |
| Reproduction | |
| Reproducibility | `once`, `intermittent`, or `N/N attempts` |
| Category | Client issue / Server core issue / Database/content issue / Missing script / Missing packet/opcode / Unknown |
| Severity | Blocker / Major / Minor / Cosmetic |
| Server evidence | |
| Client evidence | |
| Notes | |

Start new issues as `Unknown` unless the evidence already establishes a
category. Reclassification is allowed when new evidence is recorded.

## First practical playthrough path

### Primary character

Create a fresh **Human Warrior** at level 1.

Why this path:

- Tests basic movement, jump, melee range, facing, auto attack, rage generation,
  damage, death, loot, equipment, NPC gossip, vendors, trainers, and quests
  without requiring pet or complex spell systems.
- Northshire provides a compact starting area and a normal route into the first
  Elwynn hub.
- It avoids garrison and Draenor-specific systems until the general gameplay
  baseline is stable.

### Route

1. Create the Human Warrior with no heirlooms, mailed items, or GM assistance.
2. Complete the opening Northshire quest chain in offered order.
3. Include at least one kill objective, loot objective, and world-object
   interaction if the normal chain offers them.
4. Buy and sell one item, repair if available, and inspect trainer interaction.
5. Continue by the normal quest route to the first Elwynn hub.
6. Test an innkeeper, mailbox, vendor, and any naturally reached travel service.
7. Continue only until the first hub progression is either confirmed or a
   reproducible blocker is documented.

Do not treat a service as failed when it is simply not present on this route.
Record it as not tested and cover it later at the first naturally reached
location.

### Follow-up characters

After the Warrior path is stable:

1. **Mage** — offensive spell casting, mana, buffs, and later teleport support.
2. **Paladin** — melee plus mana, healing, buffs, and aura-like class behavior.
3. **Hunter** — ranged combat, focus, pet acquisition/control, and pet state
   persistence.

Hunter is intentionally later because pets cross multiple server systems and
can obscure a more basic character or content failure.

## Operator checklist

Before play:

- [ ] Confirm Core HEAD and record it in Environment.
- [ ] Confirm the supported executable, enUS locale, and `portal "localhost"`.
- [ ] Start the documented MariaDB/auth/world/NGDP services.
- [ ] Confirm auth, world, and database ports are listening.
- [ ] Record server log start time and line number.
- [ ] Start with a new non-GM Human Warrior.
- [ ] Do not enable addons, use GM commands, teleport, grant levels, or grant
  items during the primary run.

During play:

- [ ] Perform one checklist action at a time.
- [ ] Record the character, location, and local time for each failure.
- [ ] Retry a suspected failure once without changing the environment.
- [ ] Capture the exact quest ID/name for quest or phasing issues.
- [ ] Capture the exact NPC/object/spell/item ID when available in normal UI or
  server logs.
- [ ] Keep confirmed results separate from assumptions.
- [ ] Stop normal progression at a Blocker and document it before exploring a
  workaround.

After play:

- [ ] Record the server and client log end times.
- [ ] Review the marked log window for server, SQL, protocol, and crash errors.
- [ ] Create issue entries for confirmed failures only.
- [ ] Mark unreachable downstream tests `BLOCKED`, not failed.
- [ ] Save evidence paths and line/time anchors.
- [ ] Review the completed checklist before proposing any fix.

## Run summary

Complete this after each run:

| Field | Result |
|---|---|
| Run ID | `P4A-R1` |
| Start/end | |
| Character path reached | |
| Checks passed | |
| Confirmed issues | |
| Blocked checks | |
| Highest-severity issue | |
| Recommended next test | |
| Fixes made during run | **None — Phase 4A is evidence-only** |
