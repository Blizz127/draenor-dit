# Protocol Compatibility Baseline: WoD 6.2.3.20779

This document tracks client/server protocol compatibility for the preservation
baseline. It is intentionally narrow: make a real WoD 6.2.3.20779 client connect,
login, enter world, render, and move normally.

## Scope

- Client build: WoD 6.2.3.20779.
- Local client path: `/home/blizz/Projects/draenor-dit/wod/Wow-64.exe`.
- Server source path: `/home/blizz/Draenor-Core`.
- Server container: `draenor-devbox`.
- World run dir: `/home/blizz/Draenor-Core/run-world`.

## Acceptance Checklist

| Step | Status | Evidence |
|---|---|---|
| connect | confirmed | client opens auth/world TCP sessions |
| login | confirmed | bnet login reaches authserver and worldserver |
| create/select character | confirmed | character `Blizz` can enter world |
| enter world | confirmed | worldserver sends world state |
| render world | confirmed | client renders Stormwind in-world scene |
| move normally | open | no safe action-correlated movement opcode mapping yet |

## Current Instrumentation

### Unknown encrypted client opcode probe

- Status: active
- Client build: 6.2.3.20779
- Issue type: instrumentation, packet/opcode
- Broken behavior: the client sends packet IDs not present in the current server table.
- Proof: worldserver logs unknown opcodes such as `0x0534`, `0x05EF`, `0x0434`,
  `0x04CD`, `0x09A9`, `0x0A32`, `0x10E3`, `0x111A`, and `0x006C` in prior sessions.
- Files changed:
  - `/home/blizz/Draenor-Core/src/server/game/Server/WorldSocket.cpp`
- Reproduce:
  1. Rebuild `worldserver`.
  2. Start the server with the FIFO foreground method in `docs/RUNTIME_NOTES.md`.
  3. Login with the 20779 client and enter world.
  4. Run the marked movement matrix.
- Verify:
  - Unknown encrypted client opcodes log as `PROBE_UNKNOWN_CLIENT_OPCODE`.
  - Known opcodes are not logged by the probe.
  - Dispatch behavior is unchanged.
- Rollback/removal:
  - Remove the probe block immediately before `ProcessIncoming(m_RecvWPct)`.
- Open questions:
  - Which unknown opcodes are movement-shaped for build 20779.
  - Which unknowns are login/init/UI noise and must not be aliased.

The active log shape is:

```text
PROBE_UNKNOWN_CLIENT_OPCODE: opcode=0x%04X (%u) size=%u accountId=%u player=%s guidLow=%u pos=[%.3f,%.3f,%.3f] bytes=[%s]
```

## Fix Records

### OpenSSL 3 RC4 runtime compatibility

- Status: fixed in local source
- Client build: 6.2.3.20779
- Issue type: build/runtime/protocol crypto
- Broken behavior: auth crypt setup could crash under OpenSSL 3 because RC4 is not
  available from the default provider.
- Proof: prior handoff records authserver crashing on accepted auth connections before
  the RC4 replacement, and surviving raw TCP/auth probes after it.
- Files changed:
  - `/home/blizz/Draenor-Core/src/server/shared/Cryptography/ARC4.cpp`
  - `/home/blizz/Draenor-Core/src/server/shared/Cryptography/ARC4.h`
  - patch copy: `runtime/arc4-openssl3-fix.patch`
- Reproduce:
  1. Build against OpenSSL 3.
  2. Start authserver.
  3. Connect a 20779 client or raw TCP probe to `:1119`.
- Verify:
  - authserver remains alive.
  - client proceeds through bnet authentication.
- Rollback/removal:
  - Only remove if the runtime explicitly loads a compatible OpenSSL legacy provider
    and auth crypt is re-tested.
- Open questions:
  - None for the current Linux baseline.

### Firestorm client routing and NGDP bootstrap

- Status: fixed for local baseline
- Client build: 6.2.3.20779
- Issue type: client patching/runtime
- Broken behavior: the stock Firestorm client expects Firestorm NGDP and bnet endpoints,
  not the local preservation server.
- Proof: after patching/routing, the client opens TCP sessions to authserver `:1119`
  and worldserver `:8085`.
- Files changed:
  - `runtime/patch_client.py`
  - `runtime/ngdp/serve.py`
  - `runtime/ngdp/dns.py`
  - `runtime/ngdp/wow_beta/versions`
  - `runtime/ngdp/wow_beta/cdns`
  - `runtime/setup-client-connect.sh`
  - `runtime/start-ngdp.sh`
  - `runtime/start-all.sh`
- Reproduce:
  1. Run `sudo bash runtime/setup-client-connect.sh`.
  2. Run `bash runtime/start-all.sh`.
  3. Launch the patched 20779 client.
- Verify:
  - `ss -tnp` shows client connections to `:1119` and `:8085`.
  - client reaches realm/character flow.
- Rollback/removal:
  - Restore `Wow-64.exe.bak` and remove local DNS/NGDP routing.
- Open questions:
  - Windows/native client remains the best discriminator for Wine input problems.

### Large pre-auth world packet size allowance

- Status: fixed in local source
- Client build: 6.2.3.20779
- Issue type: packet/protocol
- Broken behavior: the world socket rejected large pre-auth client packets, including
  compressed addon/auth-session traffic.
- Proof: prior logs showed malformed packet handling for large pre-auth sizes; after the
  size allowance, the same client can complete world authentication and enter world.
- Files changed:
  - `/home/blizz/Draenor-Core/src/server/game/Server/WorldSocket.cpp`
- Reproduce:
  1. Build with the old `10240` cap.
  2. Login with the 20779 client.
  3. Observe world auth failure or malformed pre-auth packet logging.
- Verify:
  - build uses the `65535` cap for this pre-auth size check.
  - client proceeds into character/world flow.
- Rollback/removal:
  - Reverting the cap requires re-testing world auth with the 20779 client.
- Open questions:
  - None for the current 20779 client path.

### World socket handshake build hygiene

- Status: fixed operationally
- Client build: 6.2.3.20779
- Issue type: build/runtime
- Broken behavior: the client stalled during world connect when a stale object file
  left the old packed-header handshake behavior in the binary.
- Proof: clean rebuild produced a worldserver that performs handshake, auth response,
  character select, enter world, and rendering.
- Files changed:
  - no intentional source fix for this item; the fix was a clean rebuild of
    `WorldSocket.cpp` into the final binary.
- Reproduce:
  1. Run a stale worldserver binary with old `WorldSocket.cpp.o`.
  2. Login and observe the client stuck on world connect.
- Verify:
  - clean rebuild of `worldserver`.
  - client reaches in-world rendering.
- Rollback/removal:
  - Not applicable; keep rebuild verification in the test checklist.
- Open questions:
  - None.

### Client control update on world entry

- Status: active local fix
- Client build: 6.2.3.20779
- Issue type: packet/opcode/control
- Broken behavior: the client rendered the world but did not have a complete movement
  control grant sequence.
- Proof: current local source sends `SetClientControl(this, true)` after initial login
  packets; server reaches in-world render state. This is necessary but not sufficient
  because movement is still unresolved.
- Files changed:
  - `/home/blizz/Draenor-Core/src/server/game/Entities/Player/Player.cpp`
- Reproduce:
  1. Remove the call.
  2. Rebuild and login.
  3. Compare whether the client sends any control/movement-related packets after entry.
- Verify:
  - `SetClientControl(this, true)` is present in `SendInitialPacketsAfterAddToMap`.
  - client still reaches world rendering.
- Rollback/removal:
  - Do not remove until a complete 20779 control/movement trace proves it is unnecessary.
- Open questions:
  - Whether additional 20779 movement opcode aliases are required.

## Unknown Opcode Ledger

Known unknowns from prior sessions:

| Opcode | Size | Current status |
|---:|---:|---|
| `0x0534` | 99 | unknown; not action-mapped |
| `0x05EF` | 5 | unknown; observed with payload variants |
| `0x0434` | 1 | unknown |
| `0x04CD` | 4 | unknown |
| `0x09A9` | 0 | unknown |
| `0x0A32` | 0 | unknown |
| `0x10E3` | 0 | unknown |
| `0x111A` | 4 | unknown |
| `0x006C` | 0 | unknown; sometimes no player object |

Do not alias any of these until a marked matrix ties them to a specific action.

## Latest Local Matrix

Run id: `MATRIX_CODEX SESSION 2026-07-07T17:41:44-0500`

Result:

- Idle produced only known background traffic nearby.
- W/S/A/D/jump did not produce `PROBE_UNKNOWN_CLIENT_OPCODE` lines.
- Server-side character position remained `map=0`, `x=-8833.07`, `y=622.778`,
  `z=93.9317`.
- This run is not sufficient to map movement opcodes because local automated input did
  not prove real movement key delivery into WoW's raw input path.

No 20779 alias table is proposed from this run.

## Next Required Evidence

Run a manual or native Windows real-input matrix while the server probe is active.
The result must show action-correlated unknown opcodes before any alias is added.

For every candidate alias, record:

- matrix action
- opcode hex/decimal
- packet size
- first 32 payload bytes
- count and frequency
- repeats while held: yes/no
- release-only: yes/no
- position before/after
- parse result after routing to the existing movement handler

Alias implementation remains out of scope until this evidence exists.
