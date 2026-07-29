# Movement Protocol Probe: WoD 6.2.3.20779

Date: 2026-07-07

## Scope

- Branch: `phase3-20779-movement-probe`
- Client build: WoD 6.2.3.20779
- Goal: log unknown encrypted client opcodes safely, run a marked movement
  matrix, and identify evidence-backed alias candidates only.
- Alias implementation: not done.

## Files Changed

- `/home/blizz/Draenor-Core/src/server/game/Server/WorldSocket.cpp`
  - Safe unknown client-opcode probe in the encrypted client-packet path.
- `docs/protocol/movement-probe-20779.md`
  - This report.

No opcode table, movement handler, bot, garrison, population, or gameplay files
were changed for this probe.

## Instrumentation

Location:

- File: `/home/blizz/Draenor-Core/src/server/game/Server/WorldSocket.cpp`
- Function: `WorldSocket::handle_input_payload`
- Placement: after the full encrypted client payload has been read and asserted,
  immediately before `ProcessIncoming(m_RecvWPct)`.
- Current local lines: approximately `577-604`.

Logged marker:

```text
PROBE_UNKNOWN_CLIENT_OPCODE
```

Fields logged:

- opcode hex and decimal
- packet size
- first 32 payload bytes in hex
- account id when a session exists
- player name when a player exists
- player GUID low when a player exists
- current player position when a player exists

Safety checks:

- Does not call packet read/extract methods.
- Does not mutate the packet read position.
- Does not parse `MovementInfo`.
- Does not change dispatch.
- Does not log known opcodes.
- Null-checks session/player before reading optional context.

## Build Result

Command:

```bash
podman exec draenor-devbox bash -lc 'cd /home/blizz/Draenor-Core/build && cmake --build . --target worldserver -j2'
```

Result: success. The build reached `[100%] Built target worldserver`.

Note: CMake printed the existing repository-signature warning and continued.

## Launch And Stability

Initial recovery:

- Host `pkill -x worldserver` did not kill the containerized process because the
  running process was inside the container/user namespace.
- The process was killed from inside `draenor-devbox`.
- Port `8085` was clear before restart.

Launch method used:

```bash
podman exec draenor-devbox bash -lc '
cd /home/blizz/Draenor-Core/run-world &&
rm -f console.fifo &&
mkfifo console.fifo &&
exec 9<>console.fifo &&
exec ./worldserver < console.fifo >> worldserver-live.log 2>&1
'
```

Verification after rebuild/restart:

- Exactly one actual `./worldserver` process was running.
- `0.0.0.0:8085` was listening.
- Log reached `World initialized in 0 minutes 13 seconds`.
- No immediate `Halting process` followed initialization.

Worldserver stayed stable during the client login and matrix run.

## Client Session

Client process:

- Launched with `runtime/launch-client-gamescope.sh`.
- `Wow-64.exe` established TCP sessions to `:1119` and `:8085`.

Character state before matrix:

| Character | Map | X | Y | Z | Online |
|---|---:|---:|---:|---:|---:|
| `Blizz` | 0 | -8833.07 | 622.778 | 93.9317 | 1 |

Character state after matrix:

| Character | Map | X | Y | Z | Online |
|---|---:|---:|---:|---:|---:|
| `Blizz` | 0 | -8833.07 | 622.778 | 93.9317 | 1 |

## Current-run Unknowns Before Matrix

These occurred after the rebuilt server initialized and during client
login/init, before the marked action matrix. They are not action-correlated.

| Opcode | Decimal | Size | First payload bytes | Count in current run before matrix | Notes |
|---:|---:|---:|---|---:|---|
| `0x006C` | 108 | 0 | empty | 1 | no player object at log time |
| `0x0A32` | 2610 | 0 | empty | 1 | login/init noise candidate |
| `0x10E3` | 4323 | 0 | empty | 1 | login/init noise candidate |
| `0x05EF` | 1519 | 5 | `00 16 00 00 00` | 1 | login/init noise candidate |
| `0x05EF` | 1519 | 5 | `00 00 00 00 00` | 1 | login/init noise candidate |
| `0x0434` | 1076 | 1 | `00` | 1 | login/init noise candidate |
| `0x04CD` | 1229 | 4 | `00 00 00 00` | 1 | login/init noise candidate |
| `0x09A9` | 2473 | 0 | empty | 1 | login/init noise candidate |
| `0x05EF` | 1519 | 5 | `00 1F 00 00 00` | 1 | login/init noise candidate |

No current-run action matrix evidence ties any of these to movement.

## Matrix Run

Primary run:

- `MATRIX SESSION 2026-07-07T19:27:05-05:00 START`
- `MATRIX SESSION 2026-07-07T19:27:30-05:00 END`
- Input path: `xdotool` against the visible gamescope/XWayland session.

Extraction command:

```bash
grep -E "MATRIX|PROBE_UNKNOWN_CLIENT_OPCODE|UNKNOWN OPCODE" /home/blizz/Draenor-Core/run-world/worldserver-live.log | tail -300
```

Marker-delimited result for the primary run contained only the matrix markers.
There were no `PROBE_UNKNOWN_CLIENT_OPCODE` or `UNKNOWN OPCODE` lines between
the start and end markers.

| Action | Opcode | Size | First 32 payload bytes | Count | Repeats while held | Release-only | Position before/after |
|---|---|---:|---|---:|---|---|---|
| idle 10s | none observed | n/a | n/a | 0 | no | no | unchanged |
| W down 2s | none observed | n/a | n/a | 0 | no | no | unchanged |
| W release | none observed | n/a | n/a | 0 | no | no | unchanged |
| S down 2s | none observed | n/a | n/a | 0 | no | no | unchanged |
| S release | none observed | n/a | n/a | 0 | no | no | unchanged |
| A/D turn | none observed | n/a | n/a | 0 | no | no | unchanged |
| right-click camera/facing | none observed | n/a | n/a | 0 | no | no | unchanged |
| jump | none observed | n/a | n/a | 0 | no | no | unchanged |
| click NPC | none observed | n/a | n/a | 0 | no | no | unchanged |
| ESC/menu | none observed | n/a | n/a | 0 | no | no | unchanged |

Additional input attempt:

- `MATRIX_YDOTOOL SESSION 2026-07-07T19:28:15-05:00 START`
- `MATRIX_YDOTOOL SESSION 2026-07-07T19:28:36-05:00 END`
- Result: invalid as an input test because `ydotoold` was not running:
  `/run/user/1000/.ydotool_socket` did not exist.
- The only nearby known packet was `CMSG_TIME_SYNC_RESP`; no unknown movement
  opcode was produced.

## Click NPC And ESC

In the primary marker-delimited run:

- `click NPC` produced no unknown opcode.
- `ESC/menu` produced no unknown opcode.

Because the input path was automated and did not move the character, this does
not prove that a real manual click or ESC action produces no packet. It only
means this automated matrix did not generate action-correlated unknown packets.

## Alias Candidates

Proposed 20779 alias candidates: none.

Reason: no opcode was observed between action markers, no opcode repeated while a
movement key was held, no release-only movement opcode was observed, and the
server-side position stayed unchanged.

The observed login/init unknowns remain ledger entries only. They must not be
aliased until a manual or native-Windows real-input matrix ties them to specific
movement actions.

## Phase 3B Manual Matrix

Date: 2026-07-07

Purpose: rerun the movement matrix with human physical input in the focused
gamescope/WoW window. The earlier `xdotool` run was inconclusive because it
produced no unknown opcode probes, no movement, and no proof that WoW received
the synthetic input. The earlier `ydotool` run was invalid because `ydotoold`
was not running and `/run/user/1000/.ydotool_socket` did not exist.

### Server And Client State

- Branch: `phase3-20779-movement-probe`
- Draenor-Core commit: `bf3df8a`
- draenor-dit commit before this report update: `8b746af`
- Worldserver launch method: FIFO-managed foreground session from
  `/home/blizz/Draenor-Core/run-world`
- Worldserver state: stable, one `./worldserver`, `0.0.0.0:8085` listening
- Client launch path: `runtime/launch-client-gamescope.sh`
- Client state: `Wow-64.exe` established TCP sessions to `:1119` and `:8085`

Position before the manual matrix:

| Character | Map | X | Y | Z | Online |
|---|---:|---:|---:|---:|---:|
| `Blizz` | 0 | -8833.07 | 622.778 | 93.9317 | 1 |

Position after the manual matrix:

| Character | Map | X | Y | Z | Online |
|---|---:|---:|---:|---:|---:|
| `Blizz` | 0 | -8833.07 | 622.778 | 93.9317 | 1 |

### Manual Run Markers

- `MANUAL_MATRIX SESSION 2026-07-07T19:37:46-05:00 START`
- `MANUAL_MATRIX SESSION 2026-07-07T19:38:52-05:00 END`

The matrix was driven by desktop notifications and physical user input. No
`xdotool` or `ydotool` input was used as evidence for this run.

### Marker-delimited Packet Result

Within the manual matrix markers, no `PROBE_UNKNOWN_CLIENT_OPCODE` lines and no
`UNKNOWN OPCODE` lines appeared.

Known client packets observed inside the marker-delimited window:

| Packet | Opcode | Size | Count | Notes |
|---|---:|---:|---:|---|
| `CMSG_PING` | `0x0828` | 8 | 3 | background keepalive |
| `CMSG_TIME_SYNC_RESP` | `0x119D` | 8 | 5 | background time sync |
| `CMSG_UITIME_REQUEST` | `0x0567` | 0 | 2 | UI/background request |
| `CMSG_QUEST_GIVER_STATUS_QUERY` | `0x001A` | 10 | 2 | non-movement NPC/object status query; appeared before the explicit click marker, so action timing is ambiguous |

### Action Table

| Physical action | Unknown opcode | Size | First 32 payload bytes | Count | Repeats while held? | Release-only? | Position change |
|---|---|---:|---|---:|---|---|---|
| idle 10s | none observed | n/a | n/a | 0 | no | no | no |
| W down 2s | none observed | n/a | n/a | 0 | no | no | no |
| W release | none observed | n/a | n/a | 0 | no | no | no |
| S down 2s | none observed | n/a | n/a | 0 | no | no | no |
| S release | none observed | n/a | n/a | 0 | no | no | no |
| A/D turn | none observed | n/a | n/a | 0 | no | no | no |
| right-click camera/facing | none observed | n/a | n/a | 0 | no | no | no |
| jump | none observed | n/a | n/a | 0 | no | no | no |
| click NPC/object | none observed | n/a | n/a | 0 | no | no | no |
| ESC menu | none observed | n/a | n/a | 0 | no | no | no |

### Click And ESC Behavior

The log did not show an unknown opcode for click or ESC. Two known
`CMSG_QUEST_GIVER_STATUS_QUERY` packets appeared in the manual matrix window
before the explicit click marker, which means the client/server session can
still produce known UI/NPC-related client packets during the manual run. The
timing is not clean enough to assign those packets to the click marker.

No separate ESC-specific unknown packet was observed.

### Conclusion

The Phase 3B manual matrix still does not justify any 20779 movement aliases.
No unknown opcode repeated while W/S/A/D was held, no release-only unknown opcode
appeared, and the stored player position did not change.

This run is stronger than the automated `xdotool` run because the client session
did produce normal known packets during the manual window. However, it still did
not produce movement-shaped unknown packets. The next useful discriminator is a
native Windows/manual matrix with visual confirmation recorded alongside the log,
or a focused check of whether the client is receiving/granting movement input at
all after `SetClientControl(this, true)`.

Proposed 20779 alias candidates from Phase 3B: none.

## Phase 3C Client Control / Active Mover Verification

Date: 2026-07-07

Purpose: verify whether the server grants active mover and client-control state
to a 6.2.3.20779 client before considering any movement opcode aliases. No
opcode values, dispatch behavior, movement handlers, or `MovementInfo` parsing
were changed.

### Files Changed

- `/home/blizz/Draenor-Core/src/server/game/Entities/Player/Player.cpp`
  - Added logging-only `PROBE_CONTROL_GRANT` instrumentation.
- `docs/protocol/movement-probe-20779.md`
  - Added this Phase 3C report.

### Instrumentation Locations

Current local locations in `Player.cpp`:

| Location | Purpose |
|---|---|
| `27986-28018` | `LogControlGrantProbe(...)` helper |
| `28154` | login call-site probe immediately before `SetMover(this)` in `SendInitialPacketsBeforeAddToMap()` |
| `28370` | login call-site probe immediately before `SetClientControl(this, true)` in `SendInitialPacketsAfterAddToMap()` |
| `29677` | direct `SMSG_CLIENT_CONTROL_UPDATE` send probe in `Player::SetClientControl()` after packet construction and before send |
| `32146` | `SMSG_TIME_SYNC_REQUEST` probe in `Player::SendTimeSync()` after packet construction and before send |
| `33164` | direct `SMSG_MOVE_SET_ACTIVE_MOVER` send probe in `Player::SetMover()` after packet construction and before send |

Search found additional `SetClientControl(...)` and `SetMover(...)` callers in
scripts/unit control paths, but the actual packet construction/sends for these
two opcodes are centralized in `Player::SetClientControl()` and
`Player::SetMover()`.

### Build And Launch Result

Build command:

```bash
podman exec draenor-devbox bash -lc 'cd /home/blizz/Draenor-Core/build && cmake --build . --target worldserver -j2'
```

Result: success. The rebuild reached `[100%] Built target worldserver`.

Worldserver launch method:

```bash
podman exec draenor-devbox bash -lc 'cd /home/blizz/Draenor-Core/run-world && rm -f console.fifo && mkfifo console.fifo && exec 9<>console.fifo && exec ./worldserver < console.fifo >> worldserver-live.log 2>&1'
```

Runtime verification:

- One actual `./worldserver` process was running.
- `0.0.0.0:8085` was listening.
- The log reached `World initialized in 0 minutes 17 seconds`.
- No immediate `Halting process` followed initialization.

### Login Result

- Client launch path: `runtime/launch-client-gamescope.sh`
- `Wow-64.exe` established TCP sessions to `100.111.220.11:1119` and
  `100.111.220.11:8085`.
- `Blizz` entered world and the character DB row showed `online=1`.

Character state at extraction:

| Character | Map | X | Y | Z | Orientation | Online |
|---|---:|---:|---:|---:|---:|---:|
| `Blizz` | 0 | -8833.07 | 622.778 | 93.9317 | 0.6771 | 1 |

### Control Packet Sequence

Latest-run log anchor: latest `World initialized` line was
`worldserver-live.log:4103321`.

| Order | Function | Opcode name | Opcode value | Payload | In world? | Active mover is player? |
|---:|---|---|---:|---:|---:|---:|
| 1 | `Player::SendInitialPacketsBeforeAddToMap` | `CALL_Player_SetMover_this` | `0x0175` / 373 | 0 | 0 | 1 |
| 2 | `Player::SetMover` | `SMSG_MOVE_SET_ACTIVE_MOVER` | `0x0175` / 373 | 5 | 0 | 1 |
| 3 | `Player::SendTimeSync` | `SMSG_TIME_SYNC_REQUEST` | `0x0101` / 257 | 4 | 1 | 1 |
| 4 | `Player::SendInitialPacketsAfterAddToMap` | `CALL_Player_SetClientControl_this_true` | `0x07D0` / 2000 | 0 | 1 | 1 |
| 5 | `Player::SetClientControl` | `SMSG_CLIENT_CONTROL_UPDATE` | `0x07D0` / 2000 | 6 | 1 | 1 |
| 6 | `Player::SetMover` | `SMSG_MOVE_SET_ACTIVE_MOVER` | `0x0175` / 373 | 5 | 1 | 1 |

The first active-mover send happens before map add (`inWorld=0`). Time sync,
the explicit client-control call, the client-control packet send, and the
second active-mover send happen after map add (`inWorld=1`).

### Player State Flags

All control probes for `Blizz` reported:

- `guidLow=1`
- `targetGuidLow=1`
- `moverGuidLow=1`
- `activeMoverIsPlayer=1`
- `movementFlags=0x00000000`
- `unitFlags=0x00000008`
- `unitFlags2=0x00000800`
- `alive=1`
- `root=0`
- `stunned=0`
- `deadState=0`
- `controlled=0`
- `lostControl=0`
- `notMove=0`
- `cannotTurn=0`
- `serverControlled=0`
- `disableMove=0`

No obvious server-side root, stun, death, control-loss, no-move, cannot-turn,
server-controlled, or disable-move blocker was present in this probe.

### Time Sync And Unknowns

Time sync continued after the control packet sequence. The latest extracted run
contained `CMSG_TIME_SYNC_RESP 0x119D (4509)` responses after
`SMSG_TIME_SYNC_REQUEST 0x0101 (257)`.

Unknown client opcodes in this login/init slice:

| Opcode | Decimal | Size | Count |
|---:|---:|---:|---:|
| `0x006C` | 108 | 0 | 1 |
| `0x0434` | 1076 | 1 | 1 |
| `0x04CD` | 1229 | 4 | 1 |
| `0x05EF` | 1519 | 5 | 3 |
| `0x09A9` | 2473 | 0 | 1 |
| `0x0A32` | 2610 | 0 | 1 |
| `0x10E3` | 4323 | 0 | 1 |

These remain login/init observations only. This phase did not run a new
movement matrix and does not justify movement aliases.

### Conclusion

`SetMover(this)` ran and sent `SMSG_MOVE_SET_ACTIVE_MOVER 0x0175 (373)`.
`SetClientControl(this, true)` ran and sent
`SMSG_CLIENT_CONTROL_UPDATE 0x07D0 (2000)`. The active mover GUID matched the
player GUID, the packets were sent both before and after map add as shown
above, and time sync still worked afterward.

Phase 3C therefore does not support the hypothesis that the server entirely
failed to send active mover or client-control state. The remaining likely
directions are to verify whether the 20779 client accepts the exact
active-mover/client-control packet encoding, and to keep input delivery as a
separate hypothesis. No 20779 alias candidates are proposed from Phase 3C.

## Phase 3D-A Outgoing Control Packet Bytes

Date: 2026-07-07

Purpose: log the exact outgoing payload bytes for the server-to-client control
packets involved in the active-mover/client-control sequence. No delayed resend,
opcode changes, aliases, dispatch changes, movement handler changes, or
`MovementInfo` parsing changes were made.

### Files Changed

- `/home/blizz/Draenor-Core/src/server/game/Entities/Player/Player.cpp`
  - Added logging-only `PROBE_OUTGOING_CONTROL_PACKET` instrumentation.
- `docs/protocol/movement-probe-20779.md`
  - Added this Phase 3D-A report.

### Instrumentation Location

Current local locations in `Player.cpp`:

| Location | Purpose |
|---|---|
| `28020-28064` | `LogOutgoingControlPacketProbe(...)` helper |
| `29724` | `SMSG_CLIENT_CONTROL_UPDATE` payload dump immediately before `GetSession()->SendPacket(&l_Data)` |
| `32194` | `SMSG_TIME_SYNC_REQUEST` payload dump immediately before `GetSession()->SendPacket(&data)` |
| `33213` | `SMSG_MOVE_SET_ACTIVE_MOVER` payload dump immediately before `GetSession()->SendPacket(&data)` |

The helper filters internally to only:

- `SMSG_MOVE_SET_ACTIVE_MOVER`
- `SMSG_CLIENT_CONTROL_UPDATE`
- `SMSG_TIME_SYNC_REQUEST`

It reads `WorldPacket::size()` and `WorldPacket::contents()` only. It does not
mutate packet read/write positions, consume bytes, alter payload encoding, or
log unrelated traffic.

### Build And Runtime Result

Build command:

```bash
podman exec draenor-devbox bash -lc 'cd /home/blizz/Draenor-Core/build && cmake --build . --target worldserver -j2'
```

Result: success. The rebuild compiled `Player.cpp` and reached
`[100%] Built target worldserver`.

Worldserver launch method:

```bash
podman exec draenor-devbox bash -lc 'cd /home/blizz/Draenor-Core/run-world && rm -f console.fifo && mkfifo console.fifo && exec 9<>console.fifo && exec ./worldserver < console.fifo >> worldserver-live.log 2>&1'
```

Runtime verification:

- One actual `./worldserver` process was running.
- `0.0.0.0:8085` was listening.
- The log reached `World initialized in 0 minutes 13 seconds`.
- No immediate `Halting process` followed initialization.
- `Blizz` entered world and the character DB row showed `online=1`.

Latest-run log anchor: latest `World initialized` line was
`worldserver-live.log:4271461`.

### Outgoing Packet Bytes

| Packet | Opcode | Payload size | First payload bytes | Count in latest run | Notes |
|---|---:|---:|---|---:|---|
| `SMSG_MOVE_SET_ACTIVE_MOVER` | `0x0175` / 373 | 5 | `01 A0 01 04 08` | 2 | sent once before map add and once after `SetClientControl(this, true)` |
| `SMSG_CLIENT_CONTROL_UPDATE` | `0x07D0` / 2000 | 6 | `01 A0 01 04 08 80` | 1 | sent after map add |
| `SMSG_TIME_SYNC_REQUEST` | `0x0101` / 257 | 4 | `00 00 00 00`, then incrementing little-endian counters | 15 | observed sequence included `00 00 00 00` through `0D 00 00 00` |

The active-mover and client-control payloads used the same packed player GUID
prefix:

```text
01 A0 01 04 08
```

The client-control payload adds one final bit-flushed byte:

```text
80
```

### Time Sync

`CMSG_TIME_SYNC_RESP 0x119D (4509)` continued arriving after the outgoing
`SMSG_TIME_SYNC_REQUEST` packets. The latest-run receive count at extraction was
12.

### Manual Input Check

After world render, the focused client was given a short manual input check:
ESC/menu once, W/S/A/D, and jump once. The latest run produced known movement
CMSG receive lines:

| Packet | Opcode | Size | Count |
|---|---:|---:|---:|
| `CMSG_MOVE_TIME_SKIPPED` | `0x18B9` / 6329 | 9 | 2 |
| `CMSG_MOVE_HEARTBEAT` | `0x1512` / 5394 | 69 | 2 |
| `CMSG_MOVE_FALL_LAND` | `0x149D` / 5277 | 48 | 1 |

The character DB row still showed the stored position unchanged at extraction:

| Character | Map | X | Y | Z | Orientation | Online |
|---|---:|---:|---:|---:|---:|---:|
| `Blizz` | 0 | -8833.07 | 622.778 | 93.9317 | 0.6771 | 1 |

### Unknown Opcodes

Unknown probes in the latest run remained the known login/init-style ledger:

| Opcode | Decimal | Size | First payload bytes | Count |
|---:|---:|---:|---|---:|
| `0x006C` | 108 | 0 | empty | 1 |
| `0x0A32` | 2610 | 0 | empty | 1 |
| `0x10E3` | 4323 | 0 | empty | 1 |
| `0x05EF` | 1519 | 5 | `00 16 00 00 00` | 1 |
| `0x05EF` | 1519 | 5 | `00 00 00 00 00` | 1 |
| `0x0434` | 1076 | 1 | `00` | 1 |
| `0x04CD` | 1229 | 4 | `00 00 00 00` | 1 |
| `0x09A9` | 2473 | 0 | empty | 1 |
| `0x05EF` | 1519 | 5 | `00 1F 00 00 00` | 1 |

No unknown movement-shaped opcode was identified in this phase. The movement
traffic observed after manual input was known `CMSG_MOVE_*` traffic, not an
unknown opcode requiring an alias.

### Conclusion

The outgoing control packet byte probe confirms the exact payloads sent for the
active-mover/client-control/time-sync sequence. Time sync still round-trips
after the byte probe, so the logging did not break the session.

Most importantly, after manual input the 20779 client did emit known movement
CMSGs (`CMSG_MOVE_TIME_SKIPPED`, `CMSG_MOVE_HEARTBEAT`, and
`CMSG_MOVE_FALL_LAND`). That means Phase 3D-A does not support "client never
generates movement packets" as the current explanation. The next discriminator
should stay evidence-based: inspect how the known movement handlers process or
reject these received packets and why the stored/player-visible position does
not advance. No opcode aliases are justified from Phase 3D-A.

## Phase 3E Movement Handler Trace

Date: 2026-07-07

Purpose: trace the normal movement-handler path for recognized movement
packets. This phase does not change movement behavior, patch opcodes, implement
aliases, bypass validation, or manually apply position.

### Files Changed

- `/home/blizz/Draenor-Core/src/server/game/Handlers/MovementHandler.cpp`
  - Added logging-only `PROBE_MOVEMENT_HANDLER` instrumentation around the
    existing `WorldSession::HandleMovementOpcodes` path.
- `/home/blizz/Draenor-Core/src/server/game/Handlers/MiscHandler.cpp`
  - Added logging-only `PROBE_MOVEMENT_HANDLER` instrumentation to
    `WorldSession::HandleMoveTimeSkippedOpcode`.
- `docs/protocol/movement-probe-20779.md`
  - Added this Phase 3E report.

### Instrumentation Location

Current local locations:

| File | Location | Purpose |
|---|---:|---|
| `MovementHandler.cpp` | `30-72` | `LogMovementHandlerProbe(...)` helper |
| `MovementHandler.cpp` | `302-340` | handler entry, pre-parse state, and normal `ReadMovementInfo` result |
| `MovementHandler.cpp` | `320-379` | existing early returns for teleport, ignore count, mover GUID mismatch, invalid position, and transport validation |
| `MovementHandler.cpp` | `459-494` | anti-cheat call, movement update send, `m_movementInfo` assignment, and `UpdatePosition` boundary |
| `MovementHandler.cpp` | `548`, `564` | under-map special-case return and normal completion |
| `MiscHandler.cpp` | `1305-1353` | `CMSG_MOVE_TIME_SKIPPED` parsed mover GUID/time with unchanged TODO behavior |

The probe reads state already available in the normal handler path. It does not
consume packet bytes twice, add alternate parsing, mutate dispatch, suppress
validation, or change position assignment.

### Build And Runtime Result

Build command:

```bash
podman exec draenor-devbox bash -lc 'cd /home/blizz/Draenor-Core/build && cmake --build . --target worldserver -j2'
```

Result: success. The rebuild compiled `MiscHandler.cpp` and
`MovementHandler.cpp`, linked `worldserver`, and reached
`[100%] Built target worldserver`.

Worldserver launch method:

```bash
podman exec -d draenor-devbox bash -lc 'cd /home/blizz/Draenor-Core/run-world && rm -f console.fifo && mkfifo console.fifo && exec 9<>console.fifo && exec ./worldserver < console.fifo >> worldserver-live.log 2>&1'
```

Runtime verification:

- One actual `./worldserver` process was running.
- `0.0.0.0:8085` was listening.
- The log reached `World initialized in 0 minutes 7 seconds`.
- No immediate `Halting process` followed initialization.

Latest-run log anchor: latest `World initialized` line was
`worldserver-live.log:4439852`.

### Movement Packets Observed

From the latest rebuilt run after `worldserver-live.log:4439852`:

| Packet | Opcode | Size | Receive count | Handler probe count |
|---|---:|---:|---:|---:|
| `CMSG_MOVE_HEARTBEAT` | `0x1512` / 5394 | 69 | 2 | 2 full handler passes |
| `CMSG_MOVE_FALL_LAND` | `0x149D` / 5277 | 48 | 1 | 1 full handler pass |
| `CMSG_MOVE_TIME_SKIPPED` | `0x18B9` / 6329 | 9 | 1 | 1 time-skipped TODO probe |

A clean repeat marker was added at `worldserver-live.log:4445338`; no movement
packets appeared after that marker during the short poll window. The usable
handler trace above is still from the current rebuilt Phase 3E run, but it
landed before the manual marker, so the action boundary is not as clean as the
probe boundary.

### Handler Path Result

For `CMSG_MOVE_HEARTBEAT` and `CMSG_MOVE_FALL_LAND`:

| Check | Result |
|---|---|
| Handler ran | Yes |
| `ReadMovementInfo` parsed | Yes |
| Parsed mover GUID | `1` |
| Active mover GUID | `1` |
| Player GUID | `1` |
| Map / inWorld | `0` / `1` |
| Transport GUID | `0` |
| Root/stunned/dead/serverControlled/disableMove/notMove/cannotTurn/lostControl | all `0` |
| Anti-cheat call returned to handler | Yes, `after_anticheat` logged |
| Early return | None observed |
| `UpdatePosition` reached | Yes |
| Player position after handler | unchanged |

Representative heartbeat trace:

```text
opcode=CMSG_MOVE_HEARTBEAT 0x1512 packetSize=69
beforePos=[-8833.070,622.778,93.932,0.677]
parsedPos=[-8833.070,622.778,93.932,0.677]
afterPos=[-8833.070,622.778,93.932,0.677]
movementFlags=0x00000800 extraMovementFlags=0x0000/0x0800
```

Representative fall-land trace:

```text
opcode=CMSG_MOVE_FALL_LAND 0x149D packetSize=48
beforePos=[-8833.070,622.778,93.932,0.677]
parsedPos=[-8833.070,622.778,93.932,0.677]
afterPos=[-8833.070,622.778,93.932,0.677]
movementFlags=0x00000000 extraMovementFlags=0x0800
```

`CMSG_MOVE_TIME_SKIPPED` parsed mover GUID `1` and `timeSkipped=192`, but the
local handler remains a TODO and does not update position. That behavior was
only logged, not changed.

### Conclusion

The normal movement handler is not rejecting the observed recognized movement
packets. For heartbeat and fall-land, mover GUID validation passes, no
root/stun/dead/control-state blocker is present, no transport/coordinate
early-return is observed, anti-cheat returns to the handler, and
`UpdatePosition` is reached.

The reason position does not advance in this trace is that the parsed
`MovementInfo` position is already identical to the current player position.
The server is applying the position the client reports, but the client is
reporting stationary coordinates for these packets. Phase 3E therefore does
not justify opcode aliases or movement dispatch changes. The next smallest
probe should inspect why the 20779 client is not producing changed coordinates
after control grant, with attention to movement speed/control/root state sent
to the client and client-side input/physics acceptance.

## Phase 3F Client Movement Input Generation

Date: 2026-07-07 (primary run); re-verified 2026-07-08

Purpose: discriminate between local keybinding/WTF state, gamescope/umu input
capture, direct Wine input capture, and client movement-control state as causes
for stationary movement packets. No opcode values, opcode aliases, movement
parsing, dispatch, validation, C++ behavior, or gameplay systems were changed.

### WTF Backup And Keybinding Inspection

Initial backup before cache reset:

```bash
/home/blizz/Projects/draenor-dit/wod/WTF.backup.phase3f.20260707_210656
```

Re-verification backup before Phase 3F doc commit:

```bash
/home/blizz/Projects/draenor-dit/wod/WTF.backup.phase3f.20260707_220019
```

Binding inspection (re-run 2026-07-08):

```bash
find /home/blizz/Projects/draenor-dit/wod/WTF -iname "*binding*" -o -iname "*bindings*"
grep -R "MOVEFORWARD\|MOVEBACKWARD\|TURNLEFT\|TURNRIGHT\|STRAFELEFT\|STRAFERIGHT\|JUMP\|TOGGLEAUTORUN" /home/blizz/Projects/draenor-dit/wod/WTF
```

Result:

- No binding-named files were found under `WTF`.
- No movement binding action strings were found before or after the cache reset.
- `WTF/Config.wtf` and `WTF/Firestorm.wtf` were preserved. They contain the
  local portal/realm settings, including `100.111.220.11`.

Clean-input reset action:

- Moved only `*cache*` files out of `WTF`.
- Did not remove the whole `WTF` directory.
- Did not touch client binaries, patched client files, `Config.wtf`, or
  `Firestorm.wtf`.

Moved files were preserved locally under:

```bash
/home/blizz/Projects/draenor-dit/wod/WTF.phase3f.moved.20260707_210656
```

Moved file list:

```text
Account/5/Banshee Realm/Blizy/cache.md5
Account/5/Banshee Realm/Blizy/chat-cache.txt
Account/5/Banshee Realm/Blizy/config-cache.wtf
Account/5/Banshee Realm/Blizz/cache.md5
Account/5/Banshee Realm/Blizz/chat-cache.old
Account/5/Banshee Realm/Blizz/chat-cache.txt
Account/5/Banshee Realm/Blizz/config-cache.old
Account/5/Banshee Realm/Blizz/config-cache.wtf
Account/5/Banshee Realm/Cfbfs/cache.md5
Account/5/Banshee Realm/Cfbfs/chat-cache.txt
Account/5/Banshee Realm/Cfbfs/config-cache.wtf
Account/5/Banshee Realm/Test/cache.md5
Account/5/Banshee Realm/Test/chat-cache.txt
Account/5/Banshee Realm/Test/config-cache.wtf
Account/5/cache.md5
Account/5/config-cache.old
Account/5/config-cache.wtf
```

### Server Baseline

Worldserver was restarted cleanly after the WTF backup/reset:

- Latest fresh-run anchor: `worldserver-live.log:4610081`.
- The log reached `World initialized in 0 minutes 7 seconds`.
- One `./worldserver` process was running.
- `0.0.0.0:8085` was listening.

### Test A: Gamescope / umu

Launch method:

```bash
./runtime/launch-client-gamescope.sh
```

Process evidence:

- `gamescope -W 1920 -H 1080 -f --force-grab-cursor -- umu-run ...`
- `Wow-64.exe` was running under gamescope/umu.

Keyboard-to-chat confirmation (Test A):

- Operator opened chat, typed `wasd space arrow test`, confirmed text appeared,
  then closed chat.
- Log marker placed after confirmation:
  `worldserver-live.log:4615571` `=== PHASE3F chat-keyboard-confirmed ===`
- Conclusion: keyboard input reaches the client UI/chat layer under gamescope/umu.
  The movement issue is not explained by total keyboard failure to reach the client.

Observed before the timed marker sequence:

- The client entered world.
- Known movement packets still appeared after the cache reset.
- Representative parsed movement remained stationary:

```text
CMSG_MOVE_HEARTBEAT 0x1512 size 69
beforePos=[-8833.070,622.778,93.932,0.677]
parsedPos=[-8833.070,622.778,93.932,0.677]
afterPos=[-8833.070,622.778,93.932,0.677]
```

Timed marker sequence:

| Marker | Log line |
|---|---:|
| `PHASE3F input W` | `4615653` |
| `PHASE3F input S` | `4615657` |
| `PHASE3F input A-D-turn` | `4615661` |
| `PHASE3F input arrow-up` | `4615665` |
| `PHASE3F input arrow-down` | `4615751` |
| `PHASE3F input space` | `4615753` |
| `PHASE3F input autorun` | `4615757` |
| `PHASE3F input both-mouse-buttons` | `4615761` |
| `PHASE3F input right-click-turn` | `4615846` |
| `PHASE3F input click-to-move` | `4615850` |

Extraction from the marked Test A window found no `CMSG_MOVE_*` receive lines
and no `PROBE_MOVEMENT_HANDLER` lines. This makes the per-input Test A marker
window inconclusive. It does not override the earlier same-run observation that
gamescope/umu still produced stationary recognized movement packets after the
cache reset.

### Test B: Direct Wine, No Gamescope

Launch method:

```bash
./runtime/launch-wow-lutris.sh
```

This path uses a direct Wine window and does not use gamescope or umu. The
script also sets Wine DirectInput/raw-input registry keys before launching.

Process evidence:

- `Wow-64.exe` was running under the direct Wine prefix.
- The selected character in this run was `Cfbfs`, not `Blizz`.
- Character state in probes:
  - player GUID: `3`
  - map: `1`
  - position: `[10311.300,832.463,1326.410,5.696]`

Timed marker sequence:

| Marker | Log line |
|---|---:|
| `PHASE3F TEST B input W` | `4625440` |
| `PHASE3F TEST B input arrow-up` | `4626022` |
| `PHASE3F TEST B input autorun` | `4626559` |
| `PHASE3F TEST B input both-mouse-buttons` | `4626573` |
| `PHASE3F TEST B input click-to-move` | `4626640` |

Packet receive counts in marked windows, using exact `Receive opcode` markers:

| Input window | `CMSG_MOVE_TIME_SKIPPED` | `CMSG_MOVE_HEARTBEAT` | `CMSG_MOVE_FALL_LAND` | Non-stationary parsed `MovementInfo` |
|---|---:|---:|---:|---|
| W | 265 | 0 | 0 | none observed |
| arrow-up | 261 | 0 | 0 | none observed |
| autorun | 0 | 0 | 0 receive lines in window; 2 time-skipped probes and 1 fall-land handler pass landed there | none observed |
| both mouse buttons | 32 | 0 | 1 | none observed |
| click-to-move | 0 | 0 | 0 | none observed |

Representative direct-Wine parsed movement:

```text
CMSG_MOVE_FALL_LAND 0x149D size 48
beforePos=[10311.300,832.463,1326.410,5.696]
parsedPos=[10311.300,832.463,1326.410,5.696]
afterPos=[10311.300,832.463,1326.410,5.696]
```

The direct-Wine path changed the packet mix: the marked W and arrow-up windows
produced many `CMSG_MOVE_TIME_SKIPPED` packets, but no `CMSG_MOVE_HEARTBEAT`
with changed coordinates. The only normal parsed MovementInfo packet in the
marked direct-Wine windows was stationary.

### Phase 3F Matrix Result

| Question | Result |
|---|---|
| Keyboard input reaches chat? | Yes. Confirmed under gamescope/umu; marker at log line `4615571`. |
| Movement keybind files existed? | No binding-named files found under `WTF`. |
| Movement binding action strings existed in WTF? | No `MOVEFORWARD` / `MOVEBACKWARD` / turn / strafe / jump / autorun strings found. |
| Reset bindings/cache changed behavior? | Cache reset did not produce non-stationary coordinates. There were no binding files to reset. |
| W/S/A/D generated non-stationary MovementInfo? | No. Test A marked windows captured zero movement receives. Test B W produced 265 `CMSG_MOVE_TIME_SKIPPED` receives and zero heartbeat/fall-land with position delta. |
| Arrow keys generated non-stationary MovementInfo? | No. Test A arrow windows captured zero movement receives. Test B arrow-up produced 261 time-skipped receives only. |
| Autorun generated non-stationary MovementInfo? | No. Test B autorun window had probe activity but no parsed heartbeat/fall-land with changed coordinates. |
| Both mouse buttons generated non-stationary MovementInfo? | No. Test B window had 32 time-skipped and 1 fall-land receive; fall-land parsed position equaled current position. |
| Click-to-move generated non-stationary MovementInfo? | No packets observed in either Test A or Test B click-to-move windows. |
| No-Gamescope changed behavior? | Yes. Direct Wine (`launch-wow-lutris.sh`) generated many `CMSG_MOVE_TIME_SKIPPED` packets during W/arrow-up windows, but still no non-stationary `MovementInfo`. |

### Conclusion

Phase 3F does not support a simple bad local keybinding file as the cause:
there were no binding files or movement binding strings under `WTF`, and moving
cache files aside did not cause the client to send position deltas.

Phase 3F also does not support gamescope as the only discriminator. Direct Wine
changed the packet mix and generated many movement-time-skipped packets, but it
still did not produce non-stationary `MovementInfo` in the marked windows.

The current evidence remains: recognized movement traffic can reach the server,
the handler accepts stationary coordinates, and alternate input paths still do
not produce changed coordinates. The next smallest non-fix probe should inspect
client-side movement-control prerequisites sent by the server, especially
speed/update-field state and any client-visible movement disable/root/spline
state, without changing opcodes or movement handling.

## Phase 3G Server Movement Prerequisites After Login

Date: 2026-07-08

Purpose: inspect server-sent movement prerequisites at login/spawn/teleport without
changing opcodes, dispatch, parsing, validation, handler behavior, speed formulas,
root/spline/control logic, or packet serialization.

Scope: static analysis plus existing Phase 3D control-grant probes already present
in the local Core worktree. No new C++ was added for Phase 3G.

### Repository State At Start

Docs repo (`draenor-dit`): clean on `phase3-20779-movement-probe`.

Core repo (`/home/blizz/Draenor-Core`): dirty with unrelated build/script/runtime
changes from prior phases. Phase 3G did not modify Core files.

Existing trace helpers reused (already in local Core, not committed separately here):

| Helper | File | Purpose |
|---|---|---|
| `LogControlGrantProbe` | `Player.cpp:27986-28017` | Logs server-side mover/control/state at grant sites |
| `LogOutgoingControlPacketProbe` | `Player.cpp:28020-28063` | Logs raw bytes for control/time-sync packets |

### Login / Spawn Paths Inspected

Initial character login (`CharacterHandler.cpp`):

1. `pCurrChar->SendInitialPacketsBeforeAddToMap()` (`CharacterHandler.cpp:1147`)
2. `pCurrChar->GetMap()->AddPlayerToMap(pCurrChar)` (`CharacterHandler.cpp:1180`)
3. `pCurrChar->SendInitialPacketsAfterAddToMap()` (`CharacterHandler.cpp:1206`)

Inside those functions (`Player.cpp`):

| Step | Function | Movement-relevant action |
|---|---|---|
| Before map add | `SendInitialPacketsBeforeAddToMap:28200-28201` | `SetMover(this)` → `SMSG_MOVE_SET_ACTIVE_MOVER` |
| Map add | `Map::AddPlayerToMap:467-492` | `player->AddToWorld()`, `SendInitSelf()` → `SMSG_UPDATE_OBJECT` create |
| After map add | `SendInitialPacketsAfterAddToMap:28271-28272` | `ResetTimeSync()`, `SendTimeSync()` → `SMSG_TIME_SYNC_REQUEST` |
| After map add | `SendInitialPacketsAfterAddToMap:28274` | `CastSpell(this, 836, true)` login effect |
| After map add | `SendInitialPacketsAfterAddToMap:28294-28301` | clear movement forces; root only if stun/root auras present |
| After map add | `SendInitialPacketsAfterAddToMap:28416-28417` | local probe addition: `SetClientControl(this, true)` |

Teleport/worldport ack (`MovementHandler.cpp`):

1. `SendInitialPacketsBeforeAddToMap()` (`MovementHandler.cpp:129`)
2. `AddPlayerToMap()` (`MovementHandler.cpp:130`)
3. `SendInitialPacketsAfterAddToMap()` (`MovementHandler.cpp:168`)
4. `SMSG_MOVE_UPDATE` with current `m_movementInfo` (`MovementHandler.cpp:171-177`)
5. `UpdateSpeed(UnitMoveType(i), true)` for `i = 0..8` (`MovementHandler.cpp:233-234`)

Important structural difference: the teleport-ack path sends an explicit
`SMSG_MOVE_UPDATE` and forced speed updates. The initial CharacterHandler login
path does neither.

Reference check: `EyalMK/Draenor-Core` `940e0fbc` matches this split. Eyal does
not call `UpdateSpeed` or send `SMSG_MOVE_UPDATE` on initial login either; it
only runs the speed loop on teleport ack (`MovementHandler.cpp:190`).

Local-only addition vs Eyal: `SetClientControl(this, true)` at the end of
`SendInitialPacketsAfterAddToMap`. Eyal ends after mount/account packets without
this call. This local addition should enable client input rather than disable it.

### Control / Mover / Time Sync Evidence

Representative login trace for `Blizz` (`worldserver-live.log` lines `4610325`,
`4610424`, `4610425-4610426`, `4271808`, `4271810`):

```text
PROBE_CONTROL_GRANT: function=Player::SendInitialPacketsBeforeAddToMap opcode=CALL_Player_SetMover_this
  targetGuidLow=1 moverGuidLow=1 activeMoverIsPlayer=1
  movementFlags=0x00000000 unitFlags=0x00000008 unitFlags2=0x00000800
  root=0 stunned=0 deadState=0 controlled=0 lostControl=0 notMove=0 cannotTurn=0
  serverControlled=0 disableMove=0

PROBE_CONTROL_GRANT: function=Player::SendInitialPacketsAfterAddToMap opcode=CALL_Player_SetClientControl_this_true
  (same state flags as above)

PROBE_OUTGOING_CONTROL_PACKET: opcode=SMSG_CLIENT_CONTROL_UPDATE payload bytes=[01 A0 01 04 08 80]
PROBE_OUTGOING_CONTROL_PACKET: opcode=SMSG_MOVE_SET_ACTIVE_MOVER payload bytes=[01 A0 01 04 08]
PROBE_OUTGOING_CONTROL_PACKET: opcode=SMSG_TIME_SYNC_REQUEST payload bytes=[00 00 00 00] then [01 00 00 00] ...
```

Interpretation:

| Prerequisite | Observed | Notes |
|---|---|---|
| Active mover | Yes | `SMSG_MOVE_SET_ACTIVE_MOVER` sent before and after map add; mover GUID = player GUID |
| Client control enabled | Yes | `SMSG_CLIENT_CONTROL_UPDATE` sent with trailing control bit set (`0x80`) |
| Wrong mover attached | No | `targetGuidLow=1`, `moverGuidLow=1`, `activeMoverIsPlayer=1` |
| Time sync | Yes | `SMSG_TIME_SYNC_REQUEST` counter starts at 0 and increments |
| Root / unroot packets | No root sent | zero `SMSG_MOVE_ROOT` / `SMSG_MOVE_UNROOT` lines in full log |
| Server-side root/stun/disable | No | all probe flags `0` except normal unit flags |
| `UNIT_FIELD_FLAGS` | `0x00000008` | `UNIT_FLAG_PVP_ATTACKABLE` only |
| `UNIT_FIELD_FLAGS_2` | `0x00000800` | `UNIT_FLAG2_REGENERATE_POWER` only |
| Movement flags at grant | `0x00000000` | no root/hover/flying flags on server mover state |

Same pattern repeated for `Cfbfs` at map 1 (`worldserver-live.log:4623555-4623565`).

Login packet order around spawn (`worldserver-live.log:4103609-4103670` excerpt):

```text
SMSG_LOGIN_VERIFY_WORLD
SMSG_LOGIN_SET_TIME_SPEED
SMSG_MOVE_SET_ACTIVE_MOVER
SMSG_UPDATE_OBJECT (create self)
SMSG_TIME_SYNC_REQUEST
SMSG_CLIENT_CONTROL_UPDATE
SMSG_MOVE_SET_ACTIVE_MOVER
```

No `SMSG_MOVE_ROOT`, `SMSG_MOVE_UNROOT`, or `SMSG_MOVE_SET_*_SPEED` observed in
the login window or anywhere else in `worldserver-live.log`.

### Speed State Analysis

Server-side defaults (`Unit.cpp:276`, `Unit.cpp:81-92`):

- `m_speed_rate[i] = 1.0f` for all move types at construction.
- `playerBaseMoveSpeed` defaults: walk `2.5`, run `7.0`, run-back `4.5`, swim
  `4.722222`, turn `3.141594`, flight `7.0`, etc.

`Unit::SetSpeed` (`Unit.cpp:14764-14961`) sends explicit `SMSG_MOVE_SET_*_SPEED`
packets to players only when called while `IsInWorld()` is true and the rate
changes. `UpdateAllStats()` during DB load happens before the player is in world,
so load-time stat refresh does not emit speed packets.

Log search result:

```bash
rg -n "SMSG_MOVE_SET_(WALK|RUN|SWIM|FLIGHT|TURN|PITCH)" worldserver-live.log | wc -l
# 0
```

The only `SMSG_MOVE_SET_*` packets in the entire log are
`SMSG_MOVE_SET_ACTIVE_MOVER` (45 occurrences).

This means the 20779 test sessions never emitted explicit walk/run/swim/flight
speed packets to the client. That matches the Eyal login path: initial login does
not call `UpdateSpeed`; only teleport ack does. No teleport-ack speed flush was
observed in the current log corpus.

Server-side speed rates are therefore default/non-zero, but the client was never
explicitly synchronized with `SMSG_MOVE_SET_*_SPEED` during these sessions.

### Spline / Teleport / Fall State At Spawn

| Packet / state | Initial login | Teleport ack path |
|---|---|---|
| `SMSG_MOVE_UPDATE` | Not sent by CharacterHandler | Sent at `MovementHandler.cpp:171-177` |
| `SMSG_NEW_WORLD` | Not part of initial login sequence inspected | Used in map transfer flows |
| `SMSG_FLIGHT_SPLINE_SYNC` | Observed from nearby units after spawn, not player mover probes | Same possible |
| Forced speed resync | Not on initial login | `UpdateSpeed(..., true)` for all 9 move types |

No evidence that the player spawn itself starts a server spline or root state.
Probe state at control grant shows `movementFlags=0` and `root=0`.

### Phase 3G Checklist

| Question | Result |
|---|---|
| Accidentally rooted on server? | No probe or packet evidence |
| Control disabled on server? | No; `SMSG_CLIENT_CONTROL_UPDATE` sent with control bit on |
| Wrong mover / not player mover? | No; mover GUID equals player GUID |
| Zero/invalid server speed rates? | No; defaults remain `1.0` rate × normal base speeds |
| Explicit speed packets sent? | No; none in full log |
| Client-visible disable/root flags in update fields? | No blocking flags observed (`disableMove=0`, `UNIT_FLAG_DISABLE_MOVE` unset) |
| Missing control packet vs Eyal? | Local sends extra `SetClientControl`; Eyal does not |
| Version-mismatched prerequisite opcode observed? | No evidence in probes; opcodes match committed 20726-labeled table |

### Verdict

**Server sent normal movement prerequisites for control, mover assignment, time
sync, and unit movement-state flags.** The player is not server-rooted, not
control-blocked, not on the wrong mover, and not assigned zero server-side speed
rates in the probed login/spawn sequences.

**Suspicious but reference-aligned gap:** the client never received explicit
`SMSG_MOVE_SET_*_SPEED` packets during these sessions, and initial login does not
perform the post-spawn `SMSG_MOVE_UPDATE` + forced `UpdateSpeed` sequence that
teleport ack uses. This is consistent with Eyal's login path, so it is not yet
proven as a 20779-specific bug, but it remains the main server-side difference
between first login and later teleport ack.

**Not enough evidence to blame missing speed packets alone** for stationary
client `MovementInfo`, because Phase 3E/3F already show the client does emit
movement traffic after control grant; it just reports unchanged coordinates.

### Next Probe (Phase 3H, no fix yet)

1. Add trace-only `PHASE3G`-labeled logging at the login vs teleport-ack boundary
   to confirm whether a real teleport ack would emit `SMSG_MOVE_SET_RUN_SPEED` and
   `SMSG_MOVE_UPDATE` on this build.
2. Decode the player `SMSG_UPDATE_OBJECT` create block for movement-related update
   fields and compare against an Eyal login capture.
3. If login and teleport-ack sequences diverge in ways 20779 expects, test a
   logging-only post-login `UpdateSpeed`/`SMSG_MOVE_UPDATE` discriminator without
   committing behavioral changes until evidence supports it.

## Phase 3H Initial Object Update vs Teleport-Ack Movement State

Date: 2026-07-08

Purpose: trace whether the player’s initial `SMSG_UPDATE_OBJECT` create/movement
block is malformed or missing movement prerequisites, and whether the teleport-ack
path emits movement/speed state that first login does not.

Scope: static analysis plus existing logs. No C++ changes. No behavioral fixes.

### Repository Inventory

Docs repo (`draenor-dit`):

| Item | Value |
|---|---|
| HEAD | `6b8fc6a` `Record server movement prerequisites audit` |
| Working tree | clean |

Core repo (`/home/blizz/Draenor-Core`):

| Item | Value |
|---|---|
| HEAD | `3441c31` `Add 20779 movement handler trace` |
| Working tree | dirty (unrelated build/script/runtime/probe changes preserved; not modified for Phase 3H) |

Phase 3G commit `6b8fc6a` confirmed present in docs repo.

### Login Initial Object / Update Path Inspected

Character login sequence (`CharacterHandler.cpp:1147-1206`):

```text
SendInitialPacketsBeforeAddToMap()
  → SetMover(this)
AddPlayerToMap()
  → player->AddToWorld()
  → Map::SendInitSelf(player)
SendInitialPacketsAfterAddToMap()
  → ResetTimeSync(), SendTimeSync(), spell 836, SetClientControl(this, true) [local]
```

`Map::SendInitSelf` (`Map.cpp:2435-2467`):

1. Optional transport create block if player is on transport.
2. `p_Player->BuildCreateUpdateBlockForPlayer(&l_Data, p_Player)` on first map add.
3. Builds one `SMSG_UPDATE_OBJECT` packet via `UpdateData::BuildPacket`.

Player create builder chain:

| Step | Function | File |
|---|---|---|
| Equipment/items | `Player::BuildCreateUpdateBlockForPlayer` | `Player.cpp:6444-6465` |
| Unit movement + values | `Unit::BuildCreateUpdateBlockForPlayer` → `Object::BuildCreateUpdateBlockForPlayer` | `Object.cpp:200-268` |
| Movement block | `Object::BuildMovementUpdate` | `Object.cpp:321-608+` |
| Update fields | `Object::BuildValuesUpdate` | `Object.cpp:844+` |

Unit default update flags (`Unit.cpp:197`):

```cpp
m_updateFlag = UPDATEFLAG_HAS_MOVEMENT_UPDATE;
```

Self create flags (`Object.cpp:211-212`, `UpdateData.h:30-40`):

- `UPDATEFLAG_HAS_MOVEMENT_UPDATE` (`0x10`) — living movement block
- `UPDATEFLAG_THIS_IS_YOU` (`0x4000`) — self object
- `UPDATETYPE_CREATE_OBJECT2` for players (`Object.cpp:220-225`)

Not set for normal player login create:

- `UPDATEFLAG_HAS_POSITION` (`0x40`) — separate stationary-position block
- `UPDATEFLAG_HAS_TRANSPORT_POSITION`
- `UPDATEFLAG_HAS_VEHICLE_CREATE`
- `UPDATEFLAG_HAS_SERVER_TIME`

### Movement Fields In Initial Player Create Block

When `UPDATEFLAG_HAS_MOVEMENT_UPDATE` is set, `BuildMovementUpdate`
(`Object.cpp:365-458`) serializes:

| Field | Source at login | Expected login value |
|---|---|---|
| Mover GUID | `Unit::GetPackGUID()` | player GUID |
| Movement time | `getMSTime()` | current server ms |
| Position X/Y/Z/O | `GetPosition*()` / `GetOrientation()` | DB spawn coords |
| Pitch / spline elevation | `m_movementInfo.pitch`, `.splineElevation` | `0` unless aura/spline |
| Movement flags (30 bits) | `m_movementInfo.flags` | `0` in Phase 3G probes |
| Extra movement flags (16 bits) | `m_movementInfo.flags2` | `0` in Phase 3G probes |
| Transport GUID/block | `m_movementInfo.t_guid` etc. | absent unless on transport |
| Fall data | falling flags / `fallTime` | absent at normal ground spawn |
| Has spline | `Unit::IsSplineEnabled()` | `false` at login |
| Walk speed | `GetSpeed(MOVE_WALK)` | `2.5` (`1.0 × playerBaseMoveSpeed`) |
| Run speed | `GetSpeed(MOVE_RUN)` | `7.0` |
| Run-back speed | `GetSpeed(MOVE_RUN_BACK)` | `4.5` |
| Swim speed | `GetSpeed(MOVE_SWIM)` | `4.722222` |
| Swim-back speed | `GetSpeed(MOVE_SWIM_BACK)` | `2.5` |
| Flight speed | `GetSpeed(MOVE_FLIGHT)` | `7.0` |
| Flight-back speed | `GetSpeed(MOVE_FLIGHT_BACK)` | `4.5` |
| Turn rate | `GetSpeed(MOVE_TURN_RATE)` | `3.141594` |
| Pitch rate | `GetSpeed(MOVE_PITCH_RATE)` | `3.14` |
| Movement forces | count `0` | none |

Important correction vs Phase 3G wording: login does **not** rely on separate
`SMSG_MOVE_SET_*_SPEED` packets for initial speed delivery. The living movement
block inside the player `SMSG_UPDATE_OBJECT` create already embeds all nine speed
floats (`Object.cpp:450-458`).

`MovementInfo::Normalize()` before build only normalizes orientation/pitch and
clears inconsistent fall-direction bits (`Object.cpp:1734-1743`). It does not
zero speeds or inject root/disable flags.

Representative login packet order around self create (`worldserver-live.log:4103671-4103676`):

```text
Send packet [SMSG_MOVE_SET_ACTIVE_MOVER 0x175 (373)]
Send packet [SMSG_UPDATE_OBJECT 0x26B (619)]
Send packet [SMSG_UPDATE_OBJECT 0x26B (619)]
Send packet [SMSG_UPDATE_OBJECT 0x26B (619)]
...
Send packet [SMSG_CLIENT_CONTROL_UPDATE 0x7D0 (2000)]
Send packet [SMSG_MOVE_SET_ACTIVE_MOVER 0x175 (373)]
```

No root-looking server state was observed in the create window:

- `PROBE_CONTROL_GRANT` at login: `movementFlags=0`, `root=0`, `disableMove=0`
- zero `SMSG_MOVE_ROOT` / `SMSG_MOVE_UNROOT` lines in full log

### Local vs EyalMK Comparison (Movement-Relevant Only)

| Area | Result |
|---|---|
| `Object::BuildMovementUpdate` living block | **Same as reference** — line-by-line diff of `Object.cpp:321-480` vs Eyal `940e0fbc` is empty |
| `Unit::m_updateFlag = UPDATEFLAG_HAS_MOVEMENT_UPDATE` | **Same as reference** |
| `Map::SendInitSelf` create/values split | **Same as reference** |
| Embedded create-block speeds (`GetSpeed(MOVE_*)`) | **Same as reference** |
| CharacterHandler login packet order | **Same as reference** |
| Teleport-ack `SMSG_MOVE_UPDATE` + `UpdateSpeed(..., true)` loop | **Same as reference** (`MovementHandler.cpp:171-177`, `:233-234`) |
| `SendInitialPacketsAfterAddToMap` ending | **Different, probably helpful** — local adds `SetClientControl(this, true)`; Eyal does not |
| Existing movement-handler / object-update probes | **Local only** — Eyal has no `PROBE_CONTROL_GRANT` or `PROBE_MOVEMENT_HANDLER` |

No suspicious movement-relevant divergence was found in player create/update
serialization itself.

### Teleport-Ack Path (Code vs Logs)

Code path (`MovementHandler.cpp:168-234`, Eyal matches):

After `SendInitialPacketsAfterAddToMap()` on worldport ack:

1. `SMSG_MOVE_UPDATE` (`0x0439`) with current `m_movementInfo`
   (`MovementHandler.cpp:171-177`)
2. `UpdateSpeed(UnitMoveType(i), true)` for `i = 0..8`
   (`MovementHandler.cpp:233-234`)

`Unit::SetSpeed(..., forced=true)` for players emits these registered opcodes
(`Opcodes.h:677-685`, `Unit.cpp:14885-14958`):

| Move type | Opcode |
|---|---|
| Walk | `SMSG_MOVE_SET_WALK_SPEED` `0x0872` |
| Run | `SMSG_MOVE_SET_RUN_SPEED` `0x04FD` |
| Run back | `SMSG_MOVE_SET_RUN_BACK_SPEED` `0x0875` |
| Swim | `SMSG_MOVE_SET_SWIM_SPEED` `0x0961` |
| Swim back | `SMSG_MOVE_SET_SWIM_BACK_SPEED` `0x0D72` |
| Flight | `SMSG_MOVE_SET_FLIGHT_SPEED` `0x08BD` |
| Flight back | `SMSG_MOVE_SET_FLIGHT_BACK_SPEED` `0x0D0D` |
| Turn rate | `SMSG_MOVE_SET_TURN_RATE` `0x0DB6` |
| Pitch rate | `SMSG_MOVE_SET_PITCH_RATE` `0x042D` |

Note: `UpdateSpeed(MOVE_WALK, ...)` returns immediately without sending
(`Unit.cpp:14630-14631`), so walk forced sync is skipped even on teleport ack.

Log evidence:

```bash
rg -n "SMSG_MOVE_UPDATE|SMSG_NEW_WORLD|CMSG_MOVE_WORLDPORT" worldserver-live.log
# no matches

rg -n "SMSG_MOVE_SET_(WALK|RUN|SWIM|FLIGHT|TURN|PITCH)" worldserver-live.log
# 0 matches
```

A console `.tele` command appears once (`worldserver-live.log:985225`), but no
`SMSG_NEW_WORLD`, `CMSG_MOVE_WORLDPORT_ACK`, `SMSG_MOVE_UPDATE`, or
`SMSG_MOVE_SET_*_SPEED` lines were logged anywhere in the corpus. Teleport-ack
behavior is therefore **code-supported but log-unproven** in the current sessions.

### Operator Live Test Instructions (If Needed)

Use this only if a fresh teleport-ack capture is required. Cursor should not
assume it can operate the client.

1. Start stack normally (`runtime/start-all.sh`).
2. Launch client, login, enter world as `Blizz` in Stormwind.
3. Before moving, append marker:
   ```bash
   echo "=== PHASE3H login baseline ===" >> /home/blizz/Draenor-Core/run-world/worldserver-live.log
   ```
4. Open chat, confirm keyboard works, close chat.
5. Hold `W` for 3 seconds. Note whether position changes visually.
6. From worldserver console (if available), run:
   ```text
   .tele name Blizz Stormwind
   ```
   or any short GM teleport that forces a loading screen/worldport if supported.
7. After reload, append:
   ```bash
   echo "=== PHASE3H post-teleport ===" >> /home/blizz/Draenor-Core/run-world/worldserver-live.log
   ```
8. Hold `W` for 3 seconds again.
9. Logout.
10. Extract:
    ```bash
    rg -E "PHASE3H|SMSG_MOVE_UPDATE|SMSG_MOVE_SET_|SMSG_NEW_WORLD|CMSG_MOVE_WORLDPORT|PROBE_MOVEMENT_HANDLER|parsedPos=" \
      /home/blizz/Draenor-Core/run-world/worldserver-live.log | tail -400
    ```

Success criteria for Phase 3H live follow-up:

- Post-teleport window shows `SMSG_MOVE_UPDATE` and at least run/swim/flight
  `SMSG_MOVE_SET_*_SPEED` packets.
- Compare whether post-teleport `parsedPos` ever differs from `beforePos` when
  holding `W`.

### Verdict

**C. Teleport-ack sends movement/speed state that login does not; next probe is
whether post-teleport input produces position deltas.**

Reasoning:

- Initial player create block appears **normal**, not malformed: living movement
  block present, self flag set, spawn position encoded, movement flags zero,
  default non-zero speeds embedded inline, no root/disable flags in probes.
- Login intentionally lacks the teleport-ack extras:
  - no standalone `SMSG_MOVE_UPDATE`
  - no separate `SMSG_MOVE_SET_*_SPEED` flush (speeds already embedded in create)
- EyalMK matches the create/update serialization; local only adds helpful
  `SetClientControl`.
- Current logs cannot confirm teleport-ack emissions because no worldport-ack
  session was captured.

Next probe: operator live test above, or minimal `PHASE3H` trace-only logging on
`Map::SendInitSelf`, `HandleMoveWorldportAckOpcode`, and `Unit::SetSpeed` if a
log capture is needed without changing behavior.

## Phase 3I Live Teleport Movement A/B Probe

Date: 2026-07-07

Purpose: determine whether movement input starts working only after a teleport
ack (`SMSG_NEW_WORLD` → `CMSG_MOVE_WORLDPORT_ACK` → `SMSG_MOVE_UPDATE` +
`SMSG_MOVE_SET_*_SPEED`), comparing fresh-login baseline against post-teleport
input on the same character.

### Commits

| Repo | HEAD |
|---|---|
| draenor-dit | `3dc59c01e6fb417198a68e99cc63a75d957ffcc6` |
| Draenor-Core | `3441c31a6ccbe8f24fb7987e18d11465805a0a0c` |

No C++ changes were made for this probe. Existing `PROBE_MOVEMENT_HANDLER` and
control probes from prior phases were relied on.

### Test Setup

| Item | Value |
|---|---|
| Character | `Blizz` |
| DB map / spawn | map `0`, `(-8833.07, 622.778, 93.9317)` (Elwynn / Northshire area) |
| Tele destination | Stormwind (`.tele name Blizz Stormwind`) |
| Log file | `/home/blizz/Draenor-Core/run-world/worldserver-live.log` |
| Session anchor | line `4629696` `=== PHASE3I SESSION 2026-07-07T22:14:12-05:00 START anchor=4629695 ===` |
| Input automation | `xdotool` — `W` held 3 s, then `space` (jump), window id `102760469` |
| Console | `/home/blizz/Draenor-Core/run-world/console.fifo` via `podman exec` (root) |

Precondition check at probe start:

```bash
mariadb ... -e "SELECT name,online,map,position_x,position_y,position_z FROM characters WHERE name='Blizz';"
# Blizz  online=0  map=0  (-8833.07, 622.778, 93.9317)

echo "account onlinelist" > console.fifo
# TC> No online players.
```

The WoW client was connected (`CMSG_PING` / `SMSG_PONG` only) but `Blizz` never
entered the world during the 3+ minute wait or the automated input windows.

### Test A — Fresh Login Baseline

Markers: `worldserver-live.log:4629710`–`:4629711`

Procedure:

1. Waited from session anchor through `account onlinelist` confirmation.
2. Sent `W` (3 s) and `space` via `xdotool` to the WoW window.

Results:

| Check | Result |
|---|---|
| Character in world (`online=1`) | **No** — remained `online=0` |
| Visual movement | **Not observable** — character not in world |
| `CMSG_MOVE_*` received | **None** between markers |
| `PROBE_MOVEMENT_HANDLER` / `parsedPos=` | **None** between markers |
| Position delta | **None** — no in-world player session |

Traffic between markers: `CMSG_PING` / `SMSG_PONG` only.

### Test B — Teleport Ack

Markers: `worldserver-live.log:4629715`–`:4629717`

Procedure:

1. Issued `.tele name Blizz Stormwind` from worldserver console.
2. Waited 3 s (no loading screen — player offline).
3. Sent `W` (3 s) and `space` via `xdotool`.

Console response (`worldserver-live.log:4629712`–`:4629714`):

```text
.tele name Blizz Stormwind
TC>CLI command under processing...
You are teleporting Blizz (offline) to Stormwind.
```

Results:

| Check | Result |
|---|---|
| Visual movement | **Not observable** — character not in world |
| `CMSG_MOVE_*` received | **None** between markers |
| `PROBE_MOVEMENT_HANDLER` / `parsedPos=` | **None** between markers |
| `SMSG_NEW_WORLD` | **None** |
| `CMSG_MOVE_WORLDPORT_ACK` | **None** |
| `SMSG_MOVE_UPDATE` | **None** |
| `SMSG_MOVE_SET_*_SPEED` | **None** |
| Position delta | **None** |

Offline `.tele` updated DB coordinates only; it did **not** exercise the
worldport-ack code path documented in Phase 3H.

### Test C — Control Comparison

Not run. Test C requires a successful in-world baseline (A) and a successful
online teleport (B); neither prerequisite was met.

### Packet / Probe Evidence Table

| Window | Log lines | `CMSG_MOVE_*` | `PROBE_MOVEMENT_HANDLER` | Teleport-ack packets | Player online |
|---|---:|---|---|---|---|
| Pre-A (anchor → A start) | `4629696`–`4629709` | 0 | 0 | 0 | No |
| A baseline (W + jump) | `4629710`–`4629711` | 0 | 0 | 0 | No |
| B post-tele (W + jump) | `4629715`–`4629717` | 0 | 0 | 0 | No |

Extraction command:

```bash
rg -n "PHASE3I|SMSG_MOVE_UPDATE|SMSG_MOVE_SET_|SMSG_NEW_WORLD|CMSG_MOVE_WORLDPORT|PROBE_MOVEMENT_HANDLER|parsedPos=|Receive opcode \[CMSG_MOVE" \
  /home/blizz/Draenor-Core/run-world/worldserver-live.log | tail -80
```

Phase 3I window matches: session markers and `account onlinelist` / offline
`.tele` console lines only. No movement or teleport-ack traffic.

### Verdict

**Probe inconclusive — character never entered world; teleport-ack path not
exercised.**

The planned A/B classification could not be applied:

- Baseline A did not capture login movement state because `Blizz` stayed
  `online=0` and only auth/ping traffic was present.
- Test B used offline GM `.tele`, which does not emit `SMSG_NEW_WORLD`,
  `CMSG_MOVE_WORLDPORT_ACK`, `SMSG_MOVE_UPDATE`, or `SMSG_MOVE_SET_*_SPEED`.
- The partial “no `CMSG_MOVE_*` either window” result is therefore **not**
  evidence that teleport ack is unrelated to movement unlock; it only shows the
  probe prerequisites were unmet.

Prior in-world sessions (Phase 3F) remain the best evidence that the client
*can* emit `CMSG_MOVE_HEARTBEAT` / `CMSG_MOVE_TIME_SKIPPED` at login with
stationary `parsedPos`; Phase 3I did not reproduce or extend that capture.

### Recommended Next Action

Re-run Phase 3I with operator confirmation before baseline A:

1. Launch client, log in, enter world as `Blizz`.
2. Verify `account onlinelist` shows the player (or DB `online=1`).
3. Append `=== PHASE3I A baseline-login ===` marker, wait 3–5 s, hold `W` 3 s,
   jump once.
4. While **online**, run `.tele name Blizz Stormwind` (or another short
   loading-screen GM tele), wait for reload, append `=== PHASE3I B
   post-teleport ===`, repeat `W` + jump.
5. Re-extract with the `rg` command above and compare `CMSG_MOVE_*` and
   `parsedPos=` deltas across both windows.

### Phase 3I Blocked — Current-Session Input Failure (2026-07-07)

Operator reported logged-in character `Blizz` could not move or type in chat.
Phase 3I movement testing is **blocked** until keyboard/UI input reach the client
and produce server-visible opcodes again.

**Scope rule:** counts below are limited to the current login session. The
failure marker is `worldserver-live.log:4642467`
(`=== PHASE3I current-session-chat-keyboard-failed ===`). No whole-log historical
counts are used.

#### Marker-window analysis (lines `4642468`–`4642561`, 94 lines after marker)

| Client opcode (requested) | Count after marker |
|---|---:|
| `Receive opcode` (any) | **0** |
| `CMSG_PING` | 0 |
| `CMSG_TIME_SYNC_RESP` | 0 |
| `CMSG_CHAT_*` / chat-related | 0 |
| `CMSG_MOVE_TIME_SKIPPED` | 0 |
| `CMSG_MOVE_START_*` | 0 |
| `CMSG_MOVE_HEARTBEAT` | 0 |
| `CMSG_SET_SELECTION` / interact / attack | 0 |
| `PROBE_UNKNOWN_CLIENT_OPCODE` | 0 |
| `PROBE_MOVEMENT_HANDLER` | 0 |

Server outbound traffic **continues normally** after the marker: `SMSG_UPDATE_OBJECT`
(18), `SMSG_FLIGHT_SPLINE_SYNC` (57), `SMSG_TIME_SYNC_REQUEST` (4), `SMSG_CHAT`
(3), `SMSG_EMOTE` (1). Control probes still show `Blizz` in-world at
`[-8833.070,622.778,93.932]` with `root=0`, `disableMove=0`,
`activeMoverIsPlayer=1`.

#### Login-to-marker context (lines `4639718`–`4642467`, same session)

Before the operator placed the failure marker, the client **had** been
transmitting:

| Opcode | Count (login → marker) |
|---|---:|
| `Receive opcode` (any) | 657 |
| `CMSG_PING` | 8 |
| `CMSG_TIME_SYNC_RESP` | 24 |
| `CMSG_CHAT_UNREGISTER_ALL_ADDON_PREFIXES` | 1 |
| `CMSG_CHAT_MESSAGE_SAY` | 1 (spawn/login only; none after) |
| `CMSG_MOVE_TIME_SKIPPED` | 514 |
| `CMSG_MOVE_HEARTBEAT` | 2 |
| `CMSG_MOVE_START_*` | 0 |
| `CMSG_SET_SELECTION` / interact / attack | 0 |

All `CMSG_MOVE_HEARTBEAT` probes in this window had stationary
`parsedPos=[-8833.070,622.778,93.932,0.677]`. Last client receive before silence:
line `4642031` (`CMSG_UPDATE_ACCOUNT_DATA`). Then **436 server-only lines** with
no client opcodes before the failure marker was written.

#### Classification

**Verdict: C. Server/client session is stuck after login.**

Evidence:

- After the failure marker, the server receives **zero** client opcodes (not
  only missing chat/move — also no `CMSG_PING`, no `CMSG_TIME_SYNC_RESP`).
- Server-to-client traffic continues; `Blizz` remains in-world server-side.
- The silence began ~436 log lines **before** the marker, not at marker
  placement time.
- Earlier in the same login (before silence), behavior matched partial **B**
  (connected, one spawn-time `CMSG_CHAT_MESSAGE_SAY`, no `CMSG_MOVE_START_*`,
  stationary heartbeats) — but the operator-reported failure state is **C**, not
  A (simple focus loss would still expect background ping/time-sync) and not
  isolated **B** (all client transmission ceased).

#### Phase 3I status (superseded)

Superseded by the console worldport probe below (same date). The session-stuck
episode at line `4642467` preceded a worldserver restart; the worldport probe
ran on a fresh login with broken in-game input.

### Phase 3I Console Worldport Probe — Blocked Input (2026-07-07)

> **Client scope:** This probe used the **Firestorm** client with dead in-game
> input. Worldport did not unlock Firestorm input. That does **not** imply the
> clean English client lacks movement; see
> [Phase 3J Clean English Client Validation](#phase-3j-clean-english-client-validation-2026-07-29).

Date: 2026-07-07 (evening session)

Purpose: while the in-game input layer was broken (no chat/move opcodes from
operator keypresses), run a **cross-map console GM teleport** on an **online**
`Blizz` to test whether worldport-ack delivers the Phase 3H-predicted extra
movement/speed state and whether that unlocks input afterward.

Procedure variant: modified Phase 3I runbook using worldserver console/FIFO
instead of in-game GM chat. No WTF reset. No C++ changes.

#### Preconditions and setup notes

- Worldserver had halted (`Halting process...` in log) and was restarted via
  `runtime/start-all.sh` before this probe.
- NGDP/DNS/socat were brought back up for client reconnect.
- Operator confirmed keyboard works for login UI and character select; in-game
  Enter/W produced no server-visible chat or movement opcodes.
- `Interface/` had been deleted earlier (addon sanity check); symptoms unchanged.

#### Markers and log anchors

| Marker | Log line | Time (local) |
|---|---|---|
| `input-broken-before-console-worldport` | `4821293` | 22:51:29 |
| `.tele name Blizz Orgrimmar` (console) | `4824472` | ~22:58:09 |
| `after-console-worldport-loaded` | `4825701` | 22:58:41 |
| `after-console-worldport-input-test-done` | `4825964` | 22:59:12 |

All counts below are **marker-window scoped only** (no whole-log historical
counts).

#### Window A — `input-broken-before-console-worldport` → tele

Lines `4821294`–`4824471` (3178 lines). Covers fresh login after server
restart through operator in-world with broken input.

| Check | Count |
|---|---:|
| `CMSG_MOVE_START_*` | **0** |
| `CMSG_CHAT_MESSAGE_SAY` | **0** |
| `CMSG_CHAT_UNREGISTER_ALL_ADDON_PREFIXES` | 1 |
| `CMSG_MOVE_HEARTBEAT` | 2 receives |
| `parsedPos` (heartbeats) | All stationary `[-8833.070,622.778,93.932,0.677]` |

**Input broken before tele: confirmed.** No operator-driven chat or movement
opcodes.

#### Window B — tele → `after-console-worldport-loaded`

Lines `4824472`–`4825701` (1230 lines). Console output:
`You are teleporting Blizz to Orgrimmar.` Operator visually confirmed Orgrimmar
landing.

| Worldport packet | Seen? |
|---|---|
| `SMSG_TRANSFER_PENDING` | **Yes** (1) |
| `SMSG_NEW_WORLD` | **Yes** (1) |
| `CMSG_WORLD_PORT_RESPONSE` | **Yes** (1) |
| `SMSG_MOVE_UPDATE` | **Yes** (1) |
| `SMSG_MOVE_SET_RUN_BACK_SPEED` | **Yes** (1) |
| `SMSG_MOVE_SET_SWIM_SPEED` | **Yes** (1) |
| `SMSG_MOVE_SET_SWIM_BACK_SPEED` | **Yes** (1) |
| `SMSG_MOVE_SET_FLIGHT_SPEED` | **Yes** (1) |
| `SMSG_MOVE_SET_FLIGHT_BACK_SPEED` | **Yes** (1) |
| `SMSG_MOVE_SET_RUN_SPEED` | **No** |

Post-teleport server state: map `1`, position `[1569.970,-4397.410,16.047]`,
`root=0`, `disableMove=0`, `activeMoverIsPlayer=1`. Control and mover
re-granted after load.

This exercised the **real worldport-ack path** (not offline DB `.tele` or
near-teleport `CMSG_MOVE_TELEPORT_ACK`).

#### Window C — `after-console-worldport-loaded` → `input-test-done`

Lines `4825702`–`4825964` (263 lines). Operator tested Enter, W, A/D, and both
mouse buttons for ~30 s after loading screen finished.

| Check | Count |
|---|---:|
| `CMSG_MOVE_START_*` | **0** |
| `CMSG_MOVE_HEARTBEAT` | **0** |
| `CMSG_CHAT_MESSAGE_SAY` / chat-related | **0** |
| `CMSG_TIME_SYNC_RESP` | 3 |
| `CMSG_PING` | 1 |

**Input remains dead after worldport.** Only background keepalive opcodes; no
input-driven chat or movement.

#### Required-check summary

| Question | Answer |
|---|---|
| Cross-map worldport packets? | **Yes** — full `TRANSFER_PENDING` → `NEW_WORLD` → `WORLD_PORT_RESPONSE` |
| `SMSG_MOVE_UPDATE` + explicit speeds? | **Yes** — `MOVE_UPDATE` + 5 explicit `SMSG_MOVE_SET_*_SPEED` (no `RUN_SPEED`) |
| Chat after worldport? | **No** |
| Movement after worldport? | **No** — no `CMSG_MOVE_START_*`, no non-stationary `MovementInfo` |
| Input still dead? | **Yes** |

#### Verdict

**B. Worldport-ack sends movement/speed state that login does not; it does not
unlock the broken in-game input layer.**

Evidence:

- Phase 3H predicted login omits explicit `SMSG_MOVE_UPDATE` / forced speed
  packets that `HandleMoveWorldportAckOpcode` sends — **confirmed in this live
  capture**.
- Operator could not produce chat or move opcodes **before** or **after**
  worldport despite visual confirmation of a successful Orgrimmar reload.
- The movement investigation root cause remains **client-side in-game input
  encoding** (or a client state gate after world entry), not missing server
  worldport prerequisites.

Phase 3I A/B classification for “does teleport unlock movement?”: **No.** Input
was broken at login and stayed broken after worldport.

#### Recommended next action

Shift probe focus away from teleport-ack repair. Next investigations:

1. Client in-game input/UI state after `CMSG_LOAD_SCREEN` / control grant (why
   login UI keyboard works but world Enter/W do not).
2. Whether unknown post-login opcodes (`0x05EF`, `0x10E3`, `0x0A32`, etc.) need
   20779 server handlers (separate from movement alias work).
3. WTF/layout reset only if operator wants a UI-corruption sanity check (not
   required for this verdict).

Extraction command for marker windows:

```bash
rg -n "PHASE3I input-broken|PHASE3I after-console|tele name Blizz Orgrimmar|\
SMSG_TRANSFER_PENDING|SMSG_NEW_WORLD|CMSG_WORLD_PORT_RESPONSE|SMSG_MOVE_UPDATE|\
SMSG_MOVE_SET_|CMSG_MOVE_START|CMSG_CHAT_MESSAGE|PROBE_MOVEMENT_HANDLER|parsedPos=" \
  /home/blizz/Draenor-Core/run-world/worldserver-live.log | tail -120
```

## Phase 3J Firestorm Client-State Isolation (2026-07-07)

> **Client scope (do not generalize):** This section records the **Firestorm**
> client only (`wod/Wow-64.exe` / `WTF/Firestorm.wtf`). Its dead in-game input
> and stationary-only heartbeat conclusions are **Firestorm-client-specific**.
> They are **not** a general server movement failure. Superseding clean-client
> validation: [Phase 3J Clean English Client Validation](#phase-3j-clean-english-client-validation-2026-07-29).

Date: 2026-07-07

Purpose: test whether a **full WTF + Cache reset** on the Firestorm WoD client
(with `Interface` kept empty) restores in-game input (Esc menu, Enter/chat,
W/A-D movement, mouse movement). Login/character-select keyboard already worked;
in-game input remained dead through Phase 3I.

### Client inventory

| Item | Value |
|---|---|
| Client root | `/home/blizz/Projects/draenor-dit/wod/` |
| Binary | `Wow-64.exe` (strings: **6.2.3.20779**) |
| `.build.info` | **6.2.3.20886** (metadata mismatch) |
| NGDP served | **6.2.3.20779** |
| Launcher | `runtime/launch-client-gamescope.sh` (Gamescope + umu/Proton) |
| Client type | **Firestorm** (`WTF/Firestorm.wtf`, `SET accounttype "WD"`) |

### Backup and reset performed

| Action | Path / note |
|---|---|
| WTF backup | `wod/WTF.backup.phase3j.20260707_230509` (152K) |
| Cache backup | `wod/Cache.backup.phase3j.20260707_230509` (5.7M) |
| WTF reset | Deleted; restored **only** `Firestorm.wtf` + `Config.wtf` (portal/realm/graphics); removed saved `accountName` |
| Cache reset | Deleted; empty dir recreated |
| Interface | Kept empty (no AddOns) |

**Setup note:** Server stack had to be restarted cleanly before login (stale
worldserver/auth processes caused disconnects during earlier reset attempts).
Operator also manually deleted `WTF`/`Cache` once without minimal
`Firestorm.wtf`, which broke portal login until restored.

### Session scope

Formal `PHASE3J` console markers were not written (watch script timed out during
server restarts). Analysis window: **`CMSG_PLAYER_LOGIN` through end of session**
after the clean reset login.

| Anchor | Log line |
|---|---|
| Stack restart (clean) | `5313380` |
| `CMSG_PLAYER_LOGIN` (Phase 3J test login) | `5314112` |
| Session end (analysis time) | `5318460` (approx.) |

Spawn position after login: **Orgrimmar** map `1`,
`[1569.970,-4397.410,16.047]` (DB position from prior Phase 3I worldport).

### Opcode counts (login → session end, marker-window scoped)

| Opcode | Count |
|---|---:|
| `CMSG_MOVE_START_*` | **0** |
| `CMSG_CHAT_MESSAGE_SAY` | **0** |
| `CMSG_CHAT_UNREGISTER_ALL_ADDON_PREFIXES` | 1 |
| `CMSG_MOVE_HEARTBEAT` | 2 receives (18 probe lines) |
| `CMSG_MOVE_TIME_SKIPPED` | 2 |
| `CMSG_PING` | 1 |
| `CMSG_TIME_SYNC_RESP` | 4 |

All `CMSG_MOVE_HEARTBEAT` probes: **stationary**
`parsedPos=[1569.970,-4397.410,16.047,0.543]`.

Server control at login: `SetClientControl` + `SMSG_CLIENT_CONTROL_UPDATE` sent;
`root=0`, `disableMove=0`, `activeMoverIsPlayer=1`.

Post-login unknown client opcodes (same cluster as prior phases):
`0x05EF`, `0x10E3`, `0x0A32`, `0x09A9`, `0x04CD`, `0x0434`.

### Operator UI report (same session)

Operator confirmed login succeeded but in-game state remained **bugged** (same
symptoms as pre-reset: broken chat UI, no movement, no usable Enter/W input in
world). Login-screen and character-select keyboard continued to work.

### Verdict

**B. Reset WTF/Cache does not fix input on Firestorm client; next test is clean
full 20779 client.**

Evidence:

- Full WTF/Cache wipe + empty `Interface` did **not** produce any
  `CMSG_MOVE_START_*` or `CMSG_CHAT_MESSAGE_SAY` after world entry.
- Heartbeats remained **stationary** at spawn coordinates.
- Server prerequisites unchanged and normal (control grant, not rooted).
- Fresh WTF regenerated only minimal account cache files
  (`config-cache.wtf`, `chat-cache.txt`, `cache.md5`) — no restored
  `layout-local.txt` or SavedVariables from prior sessions.
- Rules out local layout/cache corruption as the primary blocker.

### Recommended next action

1. Obtain and test a **clean full 6.2.3.20779 retail client** (not Firestorm
   portal-patched) against the same server stack.
2. If clean retail also fails → verdict **C** path: server post-world-entry
   protocol/UI handshake becomes primary suspect.
3. Keep unknown post-login opcode investigation (`0x05EF` cluster) as a parallel
   track; do not implement opcode aliases without 20779 reference proof.

Extraction command:

```bash
rg -n "CMSG_PLAYER_LOGIN|CMSG_MOVE_START|CMSG_CHAT_MESSAGE|CMSG_MOVE_HEARTBEAT|\
PROBE_MOVEMENT_HANDLER|parsedPos=|PROBE_UNKNOWN_CLIENT_OPCODE|SetClientControl" \
  /home/blizz/Draenor-Core/run-world/worldserver-live.log | tail -80
```

## Phase 3J Clean English Client Validation (2026-07-29)

Date: 2026-07-29

Purpose: determine whether the Firestorm client was the primary blocker for
dead in-game chat/movement by validating a **clean English WoD 6.2.3.20779**
client against the same server stack. No C++ / opcode / movement / serialization
changes. Docs only.

### Contrast with prior Firestorm results

| Client | Login / char-select keyboard | In-game chat | In-game movement | Notes |
|---|---|---|---|---|
| Firestorm (`Wow-64.exe` + `Firestorm.wtf`) | Works | Dead (no `CMSG_CHAT_MESSAGE_SAY` from operator tests) | Dead (no `CMSG_MOVE_START_*`; stationary heartbeats) | WTF/Cache reset (earlier Phase 3J) did not repair; Phase 3I full worldport + explicit move/speed refresh did not repair |
| Clean English (`Wow-64-Patched*.exe`, enUS) | Works | Works | Works | This section |

Earlier Phase 3F–3I and Firestorm Phase 3J “dead input / stationary-only”
observations remain valid **as Firestorm-client evidence**. They must not be
treated as proof that server login movement prerequisites, worldport-ack, or
movement handlers are broken in general.

### Supported client baseline (use this going forward)

Full inventory (sizes, Wine ProgramData, sanitized Config hashes, client vs
repack-server separation): **`docs/client/20779-enUS-baseline.md`** (Phase 3J-B).

| Item | Value |
|---|---|
| Build | **6.2.3.20779** (`VersionsName=6.2.3.20779`, `BuildId=20779`) |
| Locale | **enUS** (`Login … locale=enUS`; WTF `textLocale` / `audioLocale` = `enUS`) |
| Binary (validated) | **`Wow-64-Patched-Offline.exe`** (also `Wow-64-Patched.exe`; not Firestorm `Wow-64.exe`) |
| SHA256 `Wow-64-Patched.exe` | `8a67fba97eccc87585ae22833d28ff87d15fd745a71f5d143ced81892ec1175f` |
| SHA256 `Wow-64-Patched-Offline.exe` | `042c7c24af68ca16bfa3010a2ee9e1355c7686bee6b5ffb2442164749fa8e50d` |
| PE `FileVersion` | `6.2.3.20779` |
| Client directory (canonical pack) | `/home/blizz/Games/World of Warcraft 6.2.3.20779 enUS/` |
| Workspace copy (validated session) | `wod/` — launch via `runtime/launch-client-gamescope.sh` |
| Wine prefix | `/var/home/blizz/Games/umu/umu-default/pfx` |
| Portal | **Confirmed** `SET portal "localhost"` |
| Explicitly unsupported as reference | Firestorm-branded `Wow-64.exe` / Firestorm portal-locked client |

Do not publish or commit copyrighted client files. Record paths, build, locale,
and hashes only. Do not import any pack-bundled private-server stack.

### Markers and analysis scope

| Marker | Log line (`worldserver-live.log`) |
|---|---|
| `CMSG_PLAYER_LOGIN` (session) | `22797` |
| `=== PHASE3J clean-english-client-login-complete ===` | `25550` |
| `=== PHASE3J clean-english-client-input-test-done ===` | `25551` |

Note: the two PHASE3J markers were written on consecutive lines (empty formal
window). Operator-confirmed input tests and matching server evidence landed
**after** `input-test-done`. Counts below use the **post-marker current session**
(`25552` → analysis time), with operator confirmation that chat and movement
worked in-game. Prior empty-window-only analysis was recorded as insufficient
until this closeout.

### Opcode / MovementInfo evidence (post-marker session)

Player `Blizz`, accountId `5`, map `1`.

| Check | Count / result |
|---|---|
| `CMSG_CHAT_MESSAGE_SAY` (`0x3BE`) | **≥3** receives (e.g. lines `26497`, `26503`, `26597`) |
| `CMSG_MOVE_START_FORWARD` | **10** receives / probe starts |
| `CMSG_MOVE_STOP` | **10** receives / probe starts |
| `CMSG_MOVE_START_TURN_LEFT` | **17** |
| `CMSG_MOVE_START_TURN_RIGHT` | **16** |
| `CMSG_MOVE_STOP_TURN` | **33** |
| `CMSG_MOVE_START_STRAFE_*` | 0 (not required; A/D observed as turn in this run) |
| `CMSG_MOVE_JUMP` | 0 (not observed in this capture) |
| `CMSG_MOVE_HEARTBEAT` | **16+** receives |
| `CMSG_MOVE_TIME_SKIPPED` | 0 |
| Non-stationary `PROBE_MOVEMENT_HANDLER` `after_parse` (`movementFlags != 0`) | **86** |
| Interaction | `CMSG_SET_SELECTION`, `CMSG_GOSSIP_HELLO`, `CMSG_QUESTGIVER_HELLO`, `CMSG_CLOSE_INTERACTION` present |

Position delta (first → late movement complete):

- Before: `[10322.208,827.134,1326.373,5.458]` (map `1`)
- After: `[10326.717,833.891,1326.349,2.907]` (map `1`)

Example early forward parse (line `25643`): `movementFlags=0x00000011`,
`parsedPos` yaw changed vs before; later `CMSG_MOVE_STOP` completes at
`[10326.062,826.939,1326.372,…]` — server accepted non-stationary movement and
updated coordinates.

### Operator confirmation

- Clean English client logs in successfully.
- In-game chat works (`/say` and related UI).
- In-game movement works (W / turn / mouse-driven motion).
- Contrasts with Firestorm: login UI keyboard worked there, but world chat and
  movement input stayed dead even after worldport (Phase 3I) and WTF/Cache reset
  (Firestorm Phase 3J).

### Final verdict

**A. Clean English client has working in-game input and movement.**

1. The **Firestorm client was incompatible or otherwise unsuitable** as the
   20779 reference client for movement/input validation.
2. **Server movement prerequisites, initial movement state, worldport path, and
   movement handling are functional** with this clean English client (chat and
   move opcodes received and applied; coordinates change).
3. Earlier dead-input and stationary-only conclusions apply to the **Firestorm
   client** and must **not** be treated as a general server failure.
4. **Stop** the movement-protocol “server handshake broken” investigation path
   that assumed Firestorm symptoms were universal. Establish this clean English
   client as the **supported baseline** for future tests.
5. Unknown post-login opcode cleanup and unrelated content work remain separate
   tracks; do not implement movement opcode aliases without 20779 reference
   proof.

### Instrumentation disposition (not removed this phase)

Existing probe logging remains in Draenor-Core (not modified here):

| Marker | Location |
|---|---|
| `PROBE_UNKNOWN_CLIENT_OPCODE` | `WorldSocket.cpp` (encrypted client path) |
| `PROBE_MOVEMENT_HANDLER` | `MovementHandler.cpp`, `MiscHandler.cpp` (`TIME_SKIPPED`) |
| `PROBE_CONTROL_GRANT` / `PROBE_OUTGOING_CONTROL_PACKET` | `Player.cpp` |

**Recommendation:** keep temporarily for regression against the new baseline and
any remaining Firestorm comparison notes; remove in a later dedicated cleanup
phase once probe noise is no longer needed. **Do not remove in Phase 3J.**

Extraction command:

```bash
rg -n "PHASE3J clean-english|CMSG_CHAT_MESSAGE_SAY|CMSG_MOVE_START_FORWARD|CMSG_MOVE_STOP|\
CMSG_MOVE_START_TURN|PROBE_MOVEMENT_HANDLER|parsedPos=" \
  /home/blizz/Draenor-Core/run-world/worldserver-live.log | awk -F: '$1+0>=25550' | head -120
```

## Phase 3J-B Working 20779 English Client Baseline (2026-07-29)

Date: 2026-07-29

Purpose: **preserve** the working clean English 6.2.3.20779 client as the
supported local baseline (inventory + docs only). No C++ / opcode changes. No
import of any pack-bundled private-server binaries, databases, or credentials.
No redistribution of copyrighted client files.

### Verdict carried forward

- Clean English client: **working** login, chat, movement, NPC interaction
  (Phase 3J).
- Firestorm findings: **client-specific**; not a general server failure.
- This enUS 20779 pack + `Wow-64-Patched*.exe` is the **supported test baseline**.

### Baseline pointer

Canonical inventory document:

**[`docs/client/20779-enUS-baseline.md`](../client/20779-enUS-baseline.md)**

Summary:

| Field | Value |
|---|---|
| Canonical dir | `/home/blizz/Games/World of Warcraft 6.2.3.20779 enUS/` (~29 GiB, 408 files) |
| Active `wod/` | `/home/blizz/Projects/draenor-dit/wod/` (validated session; same exe hashes) |
| Exe | `Wow-64-Patched-Offline.exe` (live) / `Wow-64-Patched.exe` |
| Build / locale | 6.2.3.20779 / enUS |
| Portal | `SET portal "localhost"` confirmed |
| Wine prefix | `/var/home/blizz/Games/umu/umu-default/pfx` |
| ProgramData | `$WINEPREFIX/drive_c/ProgramData/Blizzard Entertainment/Battle.net/Cache` (`.auth` modules) |
| Launch | `bash runtime/launch-client-gamescope.sh` |

### Client vs pack server material

| Keep / use | Do not use |
|---|---|
| Patched WoW exe + CASC `data/` + enUS WTF + ProgramData `.auth` zip/cache | Any leaked/repacked **server** stack (worldserver/authserver, SQL dumps, pack credentials) |
| Draenor-Core under `/home/blizz/Draenor-Core/` | Pointing core config at pack-bundled DB/binaries |
| This baseline for future protocol/content tests | Firestorm `Wow-64.exe` as reference |

Local multi-part `.7z` listing for this pack is a **client tree**; still treat
any future sibling server dump from the same community source as out of scope.
