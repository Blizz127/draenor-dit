# Current Status

Date: 2026-07-07

## Proven State

- Client target: WoD 6.2.3.20779.
- Build succeeds.
- `authserver` starts.
- `worldserver` starts when launched correctly.
- The client can login.
- The client can create, select, and enter a character.
- The client renders the world after entry.
- Movement is currently broken.
- The client sends packets during movement attempts.

## Movement Blocker

Current hypothesis: the server has a mixed 20726/20779 movement opcode table.

This is a hypothesis, not a mapping. Do not patch opcode values, copy opcode
numbers from other client builds, or route all unknown opcodes into movement
handlers. Use instrumentation and a controlled movement matrix first.

`SetClientControl(this, true)` was added and should remain for now. It is part
of the current control-grant sequence, but it has not solved movement by itself.

## Unknown Client Opcodes Observed

These opcodes have been observed in unknown-client-opcode logs across sessions.
Session boundaries matter; this table is not an alias table.

| Opcode | Decimal | Size |
|---:|---:|---:|
| `0x0534` | 1332 | 99 |
| `0x05EF` | 1519 | 5 |
| `0x0434` | 1076 | 1 |
| `0x04CD` | 1229 | 4 |
| `0x09A9` | 2473 | 0 |
| `0x0A32` | 2610 | 0 |
| `0x10E3` | 4323 | 0 |
| `0x111A` | 4378 | 4 |
| `0x006C` | 108 | 0 |

## Current Rules

- Do not guess opcode mappings.
- Do not patch opcode values without action-correlated evidence.
- Do not route all unknown opcodes to movement handlers.
- Do not add bots, garrisons, custom gameplay, or population systems.
- Document every compatibility fix with proof, files changed, reproduction, and
  verification steps.
