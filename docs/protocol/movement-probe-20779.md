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
