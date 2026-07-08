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
