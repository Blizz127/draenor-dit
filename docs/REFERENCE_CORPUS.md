# Draenor Reference Corpus

This document maps external open-source projects that can be compared against the Draenor Preservation baseline for WoD 6.2.3.20779 movement and server protocol work.

Local comparison baseline: `/home/blizz/Draenor-Core`, branch `phase3-20779-movement-probe`, commit `8926fff2e3ab0c7079e921a8f643e887e2e798bc`. Local comparisons used `git show HEAD:<path>` so uncommitted Phase 3E work in the Core worktree was not included.

Rules:

- Only exact WoD 6.2.3 / 20779-family projects are valid numeric opcode comparison targets.
- TrinityCore current, Legion, MoP, Cata, and WotLK projects are structure-only references.
- Do not copy code until license/provenance has been checked.
- Do not import or commit client assets, DB dumps, leaked binaries, patched executables, or private artifacts.
- Unknown packet bytes and opcode meanings remain unknown until proven by logs, packet structure, or exact-build reference evidence.

Phase 3E evidence (see [movement-probe-20779.md](protocol/movement-probe-20779.md)):

- Recognized movement CMSGs (`CMSG_MOVE_HEARTBEAT`, `CMSG_MOVE_FALL_LAND`, `CMSG_MOVE_TIME_SKIPPED`) reach their handlers.
- The normal movement handler does not reject those packets on mover GUID, control state, transport, or coordinate validation.
- Parsed `MovementInfo` position equals the current player position; the client is reporting stationary coordinates.
- Phase 3E therefore does not support server-side rejection or opcode-alias fixes as the current explanation. Phase 3F should focus on why the 20779 client is not generating changed coordinates after control grant.

## Local Protocol Anchors

Current local committed values:

- `src/server/game/Server/Protocol/Opcodes.h:186`: `SMSG_CLIENT_CONTROL_UPDATE = 0x07D0`, comment says `6.2.3 20726`.
- `src/server/game/Server/Protocol/Opcodes.h:717`: `SMSG_MOVE_SET_ACTIVE_MOVER = 0x0175`, comment says `6.2.3 20726`.
- `src/server/game/Server/Protocol/Opcodes.h:1383`: `CMSG_MOVE_FALL_LAND = 0x149D`, comment says `6.2.3 20726`.
- `src/server/game/Server/Protocol/Opcodes.h:1385`: `CMSG_MOVE_TIME_SKIPPED = 0x18B9`, comment says `6.2.3 20726`.
- `src/server/game/Server/Protocol/Opcodes.h:1389`: `CMSG_MOVE_HEARTBEAT = 0x1512`, comment says `6.2.3 20726`.
- `src/server/game/Server/Protocol/Opcodes.cpp:231`: `SMSG_CLIENT_CONTROL_UPDATE` is server-side only.
- `src/server/game/Server/Protocol/Opcodes.cpp:764`: `SMSG_MOVE_SET_ACTIVE_MOVER` is server-side only.
- `src/server/game/Server/Protocol/Opcodes.cpp:1438`, `:1444`: `CMSG_MOVE_FALL_LAND` and `CMSG_MOVE_HEARTBEAT` route to `WorldSession::HandleMovementOpcodes`.
- `src/server/game/Server/Protocol/Opcodes.cpp:1440`: `CMSG_MOVE_TIME_SKIPPED` routes to `WorldSession::HandleMoveTimeSkippedOpcode`.
- `src/server/game/Entities/Player/Player.cpp:29704`: `Player::SetClientControl(Unit*, bool)` writes packed target GUID, one bit, then flushes bits.
- `src/server/game/Entities/Player/Player.cpp:33191`: `Player::SetMover(Unit*)` sends `SMSG_MOVE_SET_ACTIVE_MOVER` with `appendPackGUID(target->GetGUID())`.

## Exact WoD 6.2.3 / 20779 Comparison Targets

| Project | URL | Branch / commit inspected | License / provenance note | Opcode files | `CMSG_MOVE_HEARTBEAT` | `CMSG_MOVE_TIME_SKIPPED` | `CMSG_MOVE_FALL_LAND` | `SMSG_MOVE_SET_ACTIVE_MOVER` | `SMSG_CLIENT_CONTROL_UPDATE` | `MovementHandler.cpp` | `MovementInfo` serialization | `WorldSocket` packet/header handling |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| EyalMK/Draenor-Core | https://github.com/EyalMK/Draenor-Core | `master` / `940e0fbc7f2eaf6179a75271178c6945826cc7a2` | No root license file found in inspected tree. README says the core is based on TrinityCore 6.04TDB/6.2 and mentions Firestorm-leak provenance; treat copying as high-risk until provenance is resolved. | Has `src/server/game/Server/Protocol/Opcodes.h` and `.cpp`. | Same as local: `Opcodes.h:1389`, `0x1512`; handler at `Opcodes.cpp:1444`. | Same as local: `Opcodes.h:1385`, `0x18B9`; handler at `Opcodes.cpp:1440`. | Same as local: `Opcodes.h:1383`, `0x149D`; handler at `Opcodes.cpp:1438`. | Same as local: `Opcodes.h:717`, `0x0175`; server-side handler at `Opcodes.cpp:764`; `Player.cpp:33105` sends packed GUID. | Same as local: `Opcodes.h:186`, `0x07D0`; server-side handler at `Opcodes.cpp:231`; `Player.cpp:29622` writes packed GUID + bit + flush. | No meaningful difference from local committed baseline. Anchors: `src/server/game/Handlers/MovementHandler.cpp:258`, `:621`, `:895`. | No meaningful difference in `Object.h` `MovementInfo` or `ReadMovementInfo` / `WriteMovementInfo`. Anchors: `Object.h:691`, `MovementHandler.cpp:621`, `:895`. | No meaningful difference except local probe logging added after Phase 3A/3D. Anchors: `WorldSocket.cpp:83`, `:483`, `:491-492`, `:573`, `:592`. |
| fluxurion/Draenor-Core | https://github.com/fluxurion/Draenor-Core | `master` / `e2d0fe0e4430504cedfe443f70cc9f3fc66bed67` | Root `LICENSE.txt` is GPL-2.0. README carries the same WoD 6.2.3 / Firestorm-provenance warning. | Has `src/server/game/Server/Protocol/Opcodes.h` and `.cpp`. | Same: `Opcodes.h:1389`, `0x1512`; handler at `Opcodes.cpp:1444`. | Same: `Opcodes.h:1385`, `0x18B9`; handler at `Opcodes.cpp:1440`. | Same: `Opcodes.h:1383`, `0x149D`; handler at `Opcodes.cpp:1438`. | Same: `Opcodes.h:717`, `0x0175`; handler at `Opcodes.cpp:764`; `Player.cpp:33469` sends packed GUID. | Same: `Opcodes.h:186`, `0x07D0`; handler at `Opcodes.cpp:231`; `Player.cpp:29986` writes packed GUID + bit + flush. | No protocol-significant difference found. Diff is logging macro churn plus `JadeCore::IsValidMapCoord` renamed to `Trinity::IsValidMapCoord`. Anchors: `MovementHandler.cpp:258`, `:621`, `:895`. | No serialization-significant difference found. `Object.h` drift is phase helper/state plus namespace rename, not `MovementInfo`. | Same packet/header flow as EyalMK, with logging macro churn and no local probes. Anchors: `WorldSocket.cpp:83`, `:483`, `:491-492`, `:573`, `:592`. |
| leewheel/WOD623 | https://github.com/leewheel/WOD623 | `master` / `beb580cdc486498bc0faa080c46c7d09d1b1a174` | Root `LICENSE.txt` is GPL-2.0. README carries WoD 6.2.3 provenance text; still treat copying cautiously. | Has `src/server/game/Server/Protocol/Opcodes.h` and `.cpp`. | Same: `Opcodes.h:1389`, `0x1512`; handler at `Opcodes.cpp:1444`. | Same: `Opcodes.h:1385`, `0x18B9`; handler at `Opcodes.cpp:1440`. | Same: `Opcodes.h:1383`, `0x149D`; handler at `Opcodes.cpp:1438`. | Same: `Opcodes.h:717`, `0x0175`; handler at `Opcodes.cpp:764`; `Player.cpp:33514` sends packed GUID. | Same: `Opcodes.h:186`, `0x07D0`; handler at `Opcodes.cpp:231`; `Player.cpp:30011` writes packed GUID + bit + flush. | No protocol-significant difference found. Same logging macro and namespace drift pattern as fluxurion. Anchors: `MovementHandler.cpp:258`, `:621`, `:895`. | No serialization-significant difference found. | `src/server/game/Server/WorldSocket.cpp` and `.h` were absent in this inspected commit; only `src/server/game/Server/Protocol/ServerPktHeader.h` appeared. Do not use this repo for socket/header proof. |
| 6yTblJIka/DraenorWOD623 | https://github.com/6yTblJIka/DraenorWOD623 | `master` / `915cd8ea78f9aa160557a535f1777428e9b93210` | Root `LICENSE.txt` is GPL-2.0. README carries the same WoD 6.2.3 / Firestorm-provenance warning. | Has `src/server/game/Server/Protocol/Opcodes.h` and `.cpp`. | Same: `Opcodes.h:1389`, `0x1512`; handler at `Opcodes.cpp:1444`. | Same: `Opcodes.h:1385`, `0x18B9`; handler at `Opcodes.cpp:1440`. | Same: `Opcodes.h:1383`, `0x149D`; handler at `Opcodes.cpp:1438`. | Same: `Opcodes.h:717`, `0x0175`; handler at `Opcodes.cpp:764`; `Player.cpp:33469` sends packed GUID. | Same: `Opcodes.h:186`, `0x07D0`; handler at `Opcodes.cpp:231`; `Player.cpp:29986` writes packed GUID + bit + flush. | No protocol-significant difference found. Same logging macro and namespace drift pattern as fluxurion. Anchors: `MovementHandler.cpp:258`, `:621`, `:895`. | No serialization-significant difference found. | Same packet/header flow as EyalMK, with logging macro churn and no local probes. Anchors: `WorldSocket.cpp:83`, `:483`, `:491-492`, `:573`, `:592`. |
| TheGhostGroup/DynastyCore | https://github.com/TheGhostGroup/DynastyCore | `master` / `d2596357e6fad5778b4688b8d84bd3bd073a873c` | No root license file found in inspected tree. README explicitly identifies WoD 6.2.3 20779 and references external DB / patched-client material; do not copy without provenance review. | Has `src/server/game/Server/Protocol/Opcodes.h` and `.cpp`. | Same value: `Opcodes.h:1384`, `0x1512`; handler at `Opcodes.cpp:1443`. | Same value: `Opcodes.h:1380`, `0x18B9`; handler at `Opcodes.cpp:1439`. | Same value: `Opcodes.h:1378`, `0x149D`; handler at `Opcodes.cpp:1437`. | Same value: `Opcodes.h:714`, `0x0175`; handler at `Opcodes.cpp:764`; `Player.cpp:32970` sends packed GUID. | Same value: `Opcodes.h:183`, `0x07D0`; handler at `Opcodes.cpp:231`; `Player.cpp:29544` writes packed GUID + bit, but does not explicitly call `FlushBits()` in the inspected snippet. This is a meaningful payload-encoding difference to audit, not a fix to copy. | Core handler path is similar. Local baseline has extra content branches absent in DynastyCore: Rocket Rescue parachute handling and a Throne of Four Winds under-map branch. These are content-specific, not packet parse/dispatch differences. Anchors: `MovementHandler.cpp:258`, `:599`, `:873`. | `MovementInfo` struct and read/write shape match the WoD pattern in the inspected paths. | Same WoD-family header/payload flow and no local probes. Anchors: `WorldSocket.cpp:83`, `:483`, `:491-492`, `:573`, `:592`. |

### Exact-target Findings

- All five exact WoD targets have the same numeric values for the currently observed movement CMSGs: `CMSG_MOVE_HEARTBEAT 0x1512`, `CMSG_MOVE_TIME_SKIPPED 0x18B9`, and `CMSG_MOVE_FALL_LAND 0x149D`.
- All five exact WoD targets have the same numeric values for the currently inspected control SMSGs: `SMSG_MOVE_SET_ACTIVE_MOVER 0x0175` and `SMSG_CLIENT_CONTROL_UPDATE 0x07D0`.
- The shared comments still label these values as `6.2.3 20726`; matching the WoD corpus does not prove the table is complete for `20779`.
- EyalMK is the cleanest exact file match for movement handler, `MovementInfo`, and socket/header handling.
- DynastyCore is useful because it explicitly names 20779, but it has weaker license/provenance signals and a potentially meaningful `SMSG_CLIENT_CONTROL_UPDATE` encoding difference to inspect before any fix is considered.

## Structural References Only

These repositories are for architecture, validation shape, and logging strategy. Their numeric opcode values and packet bit layouts are unsafe for WoD 6.2.3.20779.

| Project | URL | Branch / commit inspected | Useful for | Must not copy | Why numeric opcodes are unsafe | Files/functions worth comparing |
| --- | --- | --- | --- | --- | --- | --- |
| TrinityCore current/master | https://github.com/TrinityCore/TrinityCore | `master` / `561b566485ba346def656663b5046cb108633e37` | Modern movement packet class organization, `ValidateMovementInfo`, and a clean split between packet read, validation, and application. Also useful for trace vocabulary such as movement-specific logging categories. | Current retail opcode values, current packet layouts, current auth/header formats, or retail-only movement systems. | Current branch targets a different client/protocol generation. Sample values differ: `CMSG_MOVE_FALL_LAND = 0x3E0017`, `CMSG_MOVE_HEARTBEAT = 0x3E002E`, `CMSG_MOVE_TIME_SKIPPED = 0x3E0039`. | `src/server/game/Handlers/MovementHandler.cpp:49`, `:471`, `:476`, `:484`; `src/server/game/Server/Packets/MovementPackets.cpp:249`, `:919`, `:1043`, `:1063`; `src/server/game/Server/WorldSocket.cpp:336`. |
| AshamaneCore / Legion | https://github.com/AshamaneProject/AshamaneCore | `master` / `b09c1c393cf2e01bc5e857ea6117680d2aaeadb0` | Legion-era movement packet classes and control packet organization closer to modern Trinity than this WoD core. | Legion opcode values, Legion packet bit ordering, Legion-only movement systems. | Legion protocol is not WoD 20779. Sample values differ: `CMSG_MOVE_FALL_LAND = 0x39FA`, `CMSG_MOVE_HEARTBEAT = 0x3A0F`, `CMSG_MOVE_TIME_SKIPPED = 0x3A1A`. | `src/server/game/Handlers/MovementHandler.cpp:302`, `:307`; `src/server/game/Server/Packets/MovementPackets.cpp:182`, `:780`, `:908`, `:928`; `src/server/game/Server/WorldSocket.cpp:325`. |
| SkyFire_548 / MoP | https://github.com/ProjectSkyfire/SkyFire_548 | `main` / `044446fe58f2196273a1cb36ffd203af9b407e90` | Legacy handler shape with explicit `ReadMovementInfoRequest`, `ValidateMovementInfo`, and older `WorldSocket` header/payload flow. | MoP opcode table, MoP movement layouts, SkyFire logging/macros as direct replacements. | MoP 5.4.8 protocol is not WoD 20779; enum positions and packet bit ordering cannot be reused. | `src/server/game/Handlers/MovementHandler.cpp:78`, `:206`, `:482`; `src/server/game/Server/WorldSocket.cpp:69`, `:75`, `:361`, `:448`, `:595`. |
| MangosFour / MoP | https://github.com/mangosfour/server | `master` / `932e366b035349d5a8da6406ee3fa70d82e6c69b` | Older ACE socket flow and compact movement verification shape. Useful only as a sanity check for handler sequencing. | Any numeric opcode values or packet format assumptions. | The inspected comments include older build labels; example `CMSG_MOVE_TIME_SKIPPED = 0x7A0A` with a `4.3.4 15595` comment. It is not a WoD 20779 opcode source. | `src/game/WorldHandlers/MovementHandler.cpp:332`, `:608`; `src/game/Server/WorldSocket.cpp:61`, `:96`, `:557`, `:596`, `:755`. |
| FirelandsCore / Cata | https://github.com/FirelandsProject/firelands-cata | `master` / `b250899d4fdf68603e4d8a4d05b4b522d8319eb0` | Separated `MovementInfo.{h,cpp}` helper predicates and older-expansion validation/application split. | Cata opcode values, Cata movement packet shapes, AGPL code without license review. | Cata protocol is not WoD 20779. Example inspected value: `CMSG_MOVE_TIME_SKIPPED = 0x7A0A`. | `src/server/game/Handlers/MovementHandler.cpp:290`, `:300`; `src/server/game/Entities/Object/MovementInfo.cpp:24-101`; `src/server/game/Server/Packets/MovementPackets.cpp:543`; `src/server/game/Server/WorldSocket.cpp:232`. |
| AzerothCore WotLK | https://github.com/azerothcore/azerothcore-wotlk | `master` / `5239460d1027bcc5a31ba887fdc07ecdc180fc09` | Clear decomposition of `HandleMovementOpcodes`, `VerifyMovementInfo`, and `ProcessMovementInfo`; useful for future logging around early returns without changing behavior. | WotLK opcode values, WotLK packet serialization, WotLK anticheat hooks as direct drop-ins. | WotLK protocol is not WoD 20779. Example inspected value: `CMSG_MOVE_TIME_SKIPPED = 0x2CE`. | `src/server/game/Handlers/MovementHandler.cpp:354`, `:391`, `:528`, `:611`; `src/server/game/Server/WorldSocket.cpp:306`, `:437`, `:475`. |

## Best References

Best movement-handler references:

1. `EyalMK/Draenor-Core` `940e0fbc7f2e`, `src/server/game/Handlers/MovementHandler.cpp`: exact WoD-family match to the local committed baseline.
2. `TheGhostGroup/DynastyCore` `d2596357e6fa`, `src/server/game/Handlers/MovementHandler.cpp`: explicit 20779 project note, same core movement path, and fewer content branches.
3. `AzerothCore` `5239460d1027`, `src/server/game/Handlers/MovementHandler.cpp`: structural reference for splitting verification and processing; numeric values unsafe.

Best WorldSocket/header references:

1. `EyalMK/Draenor-Core` `940e0fbc7f2e`, `src/server/game/Server/WorldSocket.cpp`: exact WoD-family header/payload path without local probes.
2. `TheGhostGroup/DynastyCore` `d2596357e6fa`, `src/server/game/Server/WorldSocket.cpp`: same WoD-family socket shape and explicit 20779 README claim.
3. `SkyFire_548` `044446fe58f2`, `src/server/game/Server/WorldSocket.cpp`: structural-only legacy header/payload flow.

Best `MovementInfo` serialization references:

1. `EyalMK/Draenor-Core` `940e0fbc7f2e`, `src/server/game/Handlers/MovementHandler.cpp` and `src/server/game/Entities/Object/Object.h`: exact match.
2. `fluxurion/Draenor-Core` `e2d0fe0e4430`, same paths: same serializer with logging/namespace drift.
3. `AshamaneCore` `b09c1c393cf2`, `src/server/game/Server/Packets/MovementPackets.cpp` and `src/server/game/Entities/Object/MovementInfo.h`: structural packet-class reference only.

Best logging/probe references:

1. `EyalMK/Draenor-Core` `940e0fbc7f2e`, `src/server/game/Server/WorldSocket.cpp` and `src/server/game/Handlers/MovementHandler.cpp`: best clean baseline for deciding where local probes were added and how to keep them removable.
2. `TrinityCore` `561b566485ba`, `src/server/game/Handlers/MovementHandler.cpp:484`: structural reference for movement-specific trace logging around parsed movement state.
3. `AzerothCore` `5239460d1027`, `src/server/game/Handlers/MovementHandler.cpp:528` and `:611`: structural reference for logging validation/processing boundaries if Phase 3E needs clearer early-return vocabulary.

## Phase 3F Reference Use

Phase 3E comparison against this corpus is complete. See [movement-handler-reference-comparison.md](protocol/movement-handler-reference-comparison.md) for the handler diff summary.

Before Phase 3F, use this corpus as follows:

1. Keep exact WoD forks as the only numeric opcode comparison sources. Do not borrow Trinity/Legion/MoP/Cata/WotLK opcode values or packet layouts.
2. Use structural references only for logging vocabulary and handler sequencing ideas.
3. If Phase 3F needs server-side control-state evidence, compare outgoing control packets against EyalMK and DynastyCore `Player::SetClientControl` / `Player::SetMover` only. Pay special attention to DynastyCore's missing explicit `FlushBits()` in `SetClientControl` if control-packet encoding becomes relevant.
4. Do not use leewheel/WOD623 for socket/header proof because `WorldSocket.cpp/.h` were absent in the inspected commit.
