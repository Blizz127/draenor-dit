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
