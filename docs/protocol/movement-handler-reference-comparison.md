# Movement Handler Reference Comparison

Comparison date: 2026-07-08

Local Core baseline inspected:

- Repository: `/home/blizz/Draenor-Core`
- Branch: `phase3-20779-movement-probe`
- Committed baseline: `8926fff2e3ab0c7079e921a8f643e887e2e798bc`
- Working tree note: local Core currently has probe/logging and prior control-packet changes in `Player.cpp`, `MovementHandler.cpp`, and `WorldSocket.cpp`. This comparison separates behavior from logging-only probe scaffolding.

No code was changed for this comparison.

Reference rules:

- Only exact WoD 6.2.3 / 20779-family projects are valid numeric opcode comparison targets.
- TrinityCore current, Legion, MoP, Cata, and WotLK projects are structure-only references.
- Do not import or commit client assets, DB dumps, leaked binaries, patched executables, or private artifacts.

Phase 3E evidence (full trace in [movement-probe-20779.md](movement-probe-20779.md)):

- Recognized movement CMSGs reach `HandleMovementOpcodes` or `HandleMoveTimeSkippedOpcode`.
- For `CMSG_MOVE_HEARTBEAT` and `CMSG_MOVE_FALL_LAND`, the handler completes without early return, anti-cheat returns to the handler, and `UpdatePosition` is reached.
- Parsed `MovementInfo` position equals the current player position in every observed trace.
- The client is generating movement packets with stationary coordinates; the server is not rejecting them. Phase 3E does not justify opcode aliases or handler behavior changes.

## Files Inspected

Requested local files:

- `src/server/game/Handlers/MovementHandler.cpp`
- `src/server/game/Server/WorldSocket.cpp`
- `src/server/game/Entities/Player/Player.cpp`
- `src/server/game/Movement/MovementInfo.*`

Local path note:

- This WoD tree does not have `src/server/game/Movement/MovementInfo.*`.
- The `MovementInfo` struct is in `src/server/game/Entities/Object/Object.h:691`.
- Movement read/write serialization is in `src/server/game/Handlers/MovementHandler.cpp:685` and `:959`.
- Opcode-to-movement-sequence selection is in `src/server/game/Movement/MovementStructures.h:147`.

References inspected:

- WoD exact-family: `EyalMK/Draenor-Core` `940e0fbc7f2eaf6179a75271178c6945826cc7a2`.
- Structural current: `TrinityCore/TrinityCore` `561b566485ba346def656663b5046cb108633e37`.
- Structural Legion: `AshamaneProject/AshamaneCore` `b09c1c393cf2e01bc5e857ea6117680d2aaeadb0`.
- Structural MoP: `ProjectSkyfire/SkyFire_548` `044446fe58f2196273a1cb36ffd203af9b407e90`.

## 1. Summary Of Our Current Movement Handler

Packet intake:

- `WorldSocket.cpp:486` decrypts and decodes the world packet header.
- The encrypted world header is treated as a 13-bit opcode plus shifted size at `WorldSocket.cpp:497-499`.
- The payload is fully read before `ProcessIncoming(m_RecvWPct)` at `WorldSocket.cpp:604`.
- The current working tree has `PROBE_UNKNOWN_CLIENT_OPCODE` immediately before dispatch at `WorldSocket.cpp:577-603`; this is logging-only.

Normal movement path:

- `HandleMovementOpcodes` starts at `MovementHandler.cpp:302`.
- The handler uses the server-side active mover pointer, `m_Player->m_mover`, at `MovementHandler.cpp:307`.
- It does not independently look up an active mover by packet GUID before parsing.
- It returns early while teleporting at `MovementHandler.cpp:320-325`.
- It returns early for `GetIgnoreMovementCount()` at `MovementHandler.cpp:329-335`.
- It parses the full movement payload through `ReadMovementInfo` at `MovementHandler.cpp:337-340`.
- `ReadMovementInfo` gets the opcode-specific sequence from `GetMovementStatusElementsSequence` at `MovementHandler.cpp:694`.
- Parsed mover GUID comes from `MSEGuid` using `readPackGUID` at `MovementHandler.cpp:714-716`.
- Parsed position fields are read at `MovementHandler.cpp:730-743`.
- Parsed GUID and transport GUID are assigned back to `MovementInfo` at `MovementHandler.cpp:883-884`.

Validation and rejection:

- Packet mover GUID must equal current server mover GUID at `MovementHandler.cpp:349-354`.
- Invalid position returns early at `MovementHandler.cpp:355-360`.
- Transport offset greater than 50 on any axis returns early at `MovementHandler.cpp:363-372`.
- Invalid combined transport/map coordinate returns early at `MovementHandler.cpp:374-380`.
- There is no explicit root/stun/dead/server-controlled/disable-move/lost-control early return in `HandleMovementOpcodes`.
- `ReadMovementInfo` strips invalid movement flags, including root, hover, contradictory movement, unauthorized water-walk/feather-fall/fly flags, at `MovementHandler.cpp:886-956`.
- `sAnticheatMgr->StartHackDetection` is called at `MovementHandler.cpp:459-460`, but this call does not return a handler-level accept/reject value.

Position update:

- The handler writes and broadcasts `SMSG_MOVE_UPDATE` before assigning `m_movementInfo` and before `UpdatePosition`, at `MovementHandler.cpp:466-477`.
- It then assigns `l_Mover->m_movementInfo` at `MovementHandler.cpp:479`.
- Vehicle movers return after orientation update at `MovementHandler.cpp:482-488`; this can consume a movement packet without position assignment.
- Non-vehicle movers call `l_Mover->UpdatePosition(l_MovementInfo.pos)` at `MovementHandler.cpp:490`.
- The return value of `UpdatePosition` is not checked. If `Unit::UpdatePosition` rejects or normalizes the position internally, this handler can consume the packet while leaving current position unchanged.

Observed opcode paths:

- `CMSG_MOVE_HEARTBEAT` routes to `HandleMovementOpcodes` at `Opcodes.cpp:1444`.
- `CMSG_MOVE_FALL_LAND` routes to `HandleMovementOpcodes` at `Opcodes.cpp:1438`.
- `CMSG_MOVE_TIME_SKIPPED` routes to `HandleMoveTimeSkippedOpcode` at `Opcodes.cpp:1440`.
- `HandleMoveTimeSkippedOpcode` is in `MiscHandler.cpp:1305`; it reads a packed mover GUID and a `uint32` time at `:1307-1311`, then does not apply or broadcast the skipped time.

Movement sequence selection:

- `MovementStructures.h:154-201` maps normal movement opcodes, including `CMSG_MOVE_FALL_LAND` and `CMSG_MOVE_HEARTBEAT`, to `MovementGlobalSequence`.
- `CMSG_MOVE_TIME_SKIPPED` is not in that sequence because it is not parsed as `MovementInfo`.
- Server movement updates use `PlayerMoveSequence` for `SMSG_MOVE_UPDATE` and related SMSGs at `MovementStructures.h:204-216`.

Control grants in current working tree:

- `SendInitialPacketsAfterAddToMap` calls `SetClientControl(this, true)` at `Player.cpp:28417`.
- `SetClientControl` writes packed GUID, one bit, and flushes bits at `Player.cpp:29719-29721`.
- `SetMover` sends `SMSG_MOVE_SET_ACTIVE_MOVER` with `appendPackGUID(target->GetGUID())` at `Player.cpp:33209-33210`.

## 2. Differences From WoD References

Exact WoD-family comparison against `EyalMK/Draenor-Core` `940e0fbc7f2e`:

- `HandleMovementOpcodes` is behavior-equivalent to the local committed baseline. Eyal anchors: `MovementHandler.cpp:258`, `:286`, `:295-303`, `:401-430`.
- `ReadMovementInfo` and `WriteMovementInfo` are behavior-equivalent to the local committed baseline. Eyal anchors: `MovementHandler.cpp:621`, `:630`, `:650-680`, `:819-820`, `:895`.
- `MovementStructures.h` maps `CMSG_MOVE_FALL_LAND` and `CMSG_MOVE_HEARTBEAT` to the same global sequence. Eyal anchors: `MovementStructures.h:147`, `:167`, `:170`.
- `WorldSocket` header and payload flow is behavior-equivalent to the local committed baseline. Eyal anchors: `WorldSocket.cpp:83`, `:483`, `:491-492`, `:573`, `:592`.

Differences from the local working tree:

- Current local `MovementHandler.cpp` has `PROBE_MOVEMENT_HANDLER` logging around start, parse, early returns, anticheat, update, and completion. Eyal does not have this probe.
- Current local `WorldSocket.cpp` has `PROBE_UNKNOWN_CLIENT_OPCODE` before dispatch. Eyal does not have this probe.
- Current local `Player.cpp` has control-grant and outgoing-control probes, and the added `SetClientControl(this, true)` call after map add. Eyal has `SetClientControl` and `SetMover` functions, but not the local logging probes.

Meaningful WoD-reference finding:

- The exact WoD reference does not reveal a different movement-handler rejection path for the observed movement packets.
- Phase 3E confirmed the handler matches Eyal's path and that parsed position equals current position. The remaining question is why the 20779 client reports stationary coordinates after control grant, not whether the server rejects valid movement.

## 3. Differences From TrinityCore / Ashamane / SkyFire Structure

TrinityCore current:

- Trinity uses typed movement packets: `HandleMovementOpcodes(WorldPackets::Movement::ClientPlayerMovement&)` delegates to `HandleMovementOpcode` at `MovementHandler.cpp:471-476`.
- It validates active mover through `ValidateAndGetUnitBeingMoved` before processing at `MovementHandler.cpp:148-167` and `:478`.
- It uses `ValidateMovementInfo` as a boolean gate at `MovementHandler.cpp:49-145` and `:479`.
- It logs parsed movement state with a movement-specific trace at `MovementHandler.cpp:484-486`.
- It checks teleport state and unfinished splines before transport handling at `MovementHandler.cpp:488-493`.
- It updates `mover->m_movementInfo`, then calls `mover->UpdatePosition`, then broadcasts movement update at `MovementHandler.cpp:559-585`.
- Its `HandleMoveTimeSkippedOpcode` applies skipped time and broadcasts `MoveSkipTime` at `MovementHandler.cpp:912-923`.

AshamaneCore / Legion:

- Ashamane also uses typed packet classes. `ClientPlayerMovement::Read` reads `MovementInfo` through `operator>>` at `MovementPackets.cpp:182-185`.
- Its movement serialization is centralized in `MovementPackets.cpp:25-82`.
- Its handler validates movement info, checks GUID and position, then updates position and sends a typed `MoveUpdate` at `MovementHandler.cpp:302-436`.
- Its `ControlUpdate::Write` writes GUID, bit, and flush at `MovementPackets.cpp:928-934`, matching the safe shape expected for a bit-bearing control packet.
- Its `MoveSetActiveMover::Write` writes the mover GUID as a typed GUID at `MovementPackets.cpp:780-784`; this is structural only and not a WoD packed-GUID encoding source.

SkyFire_548 / MoP:

- SkyFire factors parsing into helper functions such as `ReadMovementInfoRequest` at `MovementHandler.cpp:78-82`.
- It factors GUID/position validation into `ValidateMovementInfo` at `MovementHandler.cpp:206-220`.
- It factors transport validation into `ValidateTransportMovementInfo` beginning at `MovementHandler.cpp:223`.
- Its handler reads, validates, processes transport/fall/swim state, updates position, then writes/sends movement at `MovementHandler.cpp:482-605`.
- SkyFire is useful for separating parse/validate/process concepts, but its opcode names, packet layouts, and numeric values are not safe for WoD.

Important structural difference:

- Our WoD handler broadcasts `SMSG_MOVE_UPDATE` before `UpdatePosition`.
- Trinity, Ashamane, and SkyFire update position before broadcasting.
- This is not a fix recommendation by itself because the exact WoD reference has the same ordering as our committed baseline, but it is a useful probe point: log before send, after send, before `UpdatePosition`, and after `UpdatePosition`.

## 4. Phase 3E Probe Points (Completed)

Phase 3E logging-only probes were added and run. Result: handler accepts recognized movement packets; parsed coordinates remain stationary. The probe-point list below is retained as the instrumentation map used for that run.

High-value probe points, all logging-only:

1. `HandleMovementOpcodes` entry: opcode, packet size, player GUID, active mover GUID, current position.
2. Immediately after `ReadMovementInfo`: parsed mover GUID, parsed position, movement flags, transport GUID, transport position, timestamp.
3. Each early return:
   - teleport wait
   - ignore movement count
   - packet mover GUID mismatch
   - invalid position
   - transport offset too large
   - invalid transport coordinate
   - vehicle orientation-only return
   - content-specific under-map return
4. Before and after `sAnticheatMgr->StartHackDetection`: prove it does or does not mutate flags/position.
5. Before `WriteMovementInfo` and `SendMessageToSet`: prove the outgoing echoed movement position.
6. Immediately before and after `l_Mover->m_movementInfo = l_MovementInfo`.
7. Immediately before and after `l_Mover->UpdatePosition(l_MovementInfo.pos)`: include before/after `GetPosition*` values and, if the method returns a value through overload resolution, log it.
8. `HandleMoveTimeSkippedOpcode`: log packed mover GUID, time skipped, current movementInfo time before/after. No behavior change yet.
9. `Player::UpdatePosition`: if Phase 3E shows `HandleMovementOpcodes` reaches `UpdatePosition` but coordinates remain unchanged, add a focused probe around `Unit::UpdatePosition` return and any position normalization/rejection.

The current local Phase 3E working tree already contains many of these probes in `MovementHandler.cpp`; the comparison supports keeping them scoped to movement packets and adding time-skipped/UpdatePosition detail only if the first run proves necessary.

## 5. Likely Early-return / Rejection Points

Confirmed in local handler:

- `player_is_being_teleported`: `MovementHandler.cpp:320-325`.
- `ignore_movement_count`: `MovementHandler.cpp:329-335`.
- `packet_mover_guid_mismatch`: `MovementHandler.cpp:349-354`.
- `invalid_position`: `MovementHandler.cpp:355-360`.
- `transport_offset_too_large`: `MovementHandler.cpp:363-372`.
- `invalid_transport_position`: `MovementHandler.cpp:374-380`.
- `mover_is_vehicle_after_orientation_update`: `MovementHandler.cpp:482-488`.
- `throne_of_four_winds_under_map`: content-specific return in current working tree around `MovementHandler.cpp:537-547`.

Not explicit early returns in local handler:

- Root state.
- Stun state.
- Dead state before movement application.
- Server-controlled flag.
- Disable-move flag.
- Lost-control state.

These states may still affect movement elsewhere, but `HandleMovementOpcodes` itself does not reject on them before `UpdatePosition`.

Can consume packet and leave position unchanged:

- `HandleMoveTimeSkippedOpcode` consumes a movement-related packet but does not update position.
- Vehicle movers consume movement and update orientation only.
- Any early return after parse consumes or partially consumes the packet without position update.
- Parsed position may equal current position, especially heartbeat or release packets.
- `l_Mover->UpdatePosition(l_MovementInfo.pos)` may fail or normalize without a checked return in this handler.
- `ReadMovementInfo` may strip invalid flags without rejecting, so packet can continue with modified flags.

## 6. Safe Ideas To Transfer

Safe structural ideas, not code copies:

- Use Trinity/Ashamane/SkyFire's separation vocabulary in probe logs: parse, validate mover, validate position, validate transport, apply movement, broadcast update.
- Add logging that explicitly names active mover validation instead of only logging "guid error".
- Add a focused log around `UpdatePosition` return/effect if the Phase 3E run reaches that line but position stays unchanged.
- Add a focused log for `HandleMoveTimeSkippedOpcode`, since it is observed in testing and currently has a TODO body.
- Keep movement-probe logs filtered to movement opcodes and known control packets.
- Keep exact WoD forks as the only numeric opcode comparison sources.

## 7. Unsafe Things Not To Transfer

Do not transfer:

- Numeric opcode values from TrinityCore, Ashamane, SkyFire, FirelandsCore, Mangos, or AzerothCore.
- Legion/MoP/Cata/WotLK movement packet layouts or bit ordering.
- Trinity/Ashamane typed packet classes as a drop-in replacement during Phase 3E.
- Different transport thresholds, such as Trinity/Ashamane's 75-yard transport offset, without WoD evidence.
- Reordered movement broadcast/update behavior without a separate evidence run.
- Time-skipped behavior changes before logging proves whether it is relevant to the 20779 symptom.
- Any anti-cheat bypass, validation suppression, or manual position assignment.

## 8. Phase 3E Outcome And Phase 3F Guidance

Phase 3E outcome:

- Existing `PROBE_MOVEMENT_HANDLER` instrumentation logged the full handler path for `CMSG_MOVE_HEARTBEAT`, `CMSG_MOVE_FALL_LAND`, and `CMSG_MOVE_TIME_SKIPPED`.
- No early return, mover GUID mismatch, or `UpdatePosition` skip was observed for heartbeat or fall-land.
- Parsed position equaled current position in every observed trace. The client is sending stationary movement payloads; the server applies them unchanged.
- Do not change dispatch, opcodes, aliases, parsing, validation, anti-cheat, or position application based on Phase 3E.

Phase 3F should focus on client-side movement input generation and control-state acceptance, not further handler instrumentation unless new non-stationary packets appear. See [movement-probe-20779.md](movement-probe-20779.md) Phase 3F section.
