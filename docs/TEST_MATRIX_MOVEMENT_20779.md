# Movement Test Matrix: WoD 6.2.3.20779

This matrix is used to identify build-20779 movement packets without guessing
opcode mappings.

Run it only with safe unknown-opcode instrumentation enabled. The probe should
log unknown client opcode, packet size, first 32 payload bytes, account/player
context when available, GUID when available, and current position when available.

## Test Rules

- Start from a clean worldserver session.
- Confirm the log reaches `World initialized`.
- Confirm exactly one worldserver is listening on `8085`.
- Enter world with the 6.2.3.20779 client.
- Append a visible `MATRIX` marker before each action.
- Do not change opcode dispatch during the matrix.
- Do not parse movement payloads until candidate opcodes are identified.
- Record position before and after each action.

## Actions

1. idle
2. W down
3. W release
4. S down
5. S release
6. A/D turn
7. right-click camera/facing
8. jump
9. click NPC
10. ESC/menu

## Per-action Record

For each action, capture:

- marker timestamp
- opcode hex and decimal
- packet size
- first 32 payload bytes
- count/frequency
- whether it repeats while held
- whether it appears only on release
- position before
- position after
- notes separating movement-shaped packets from UI/login/addon noise

## Extraction Command

```bash
grep -E "MATRIX|PROBE_UNKNOWN_CLIENT_OPCODE|UNKNOWN OPCODE" \
  /home/blizz/Draenor-Core/run-world/worldserver-live.log | tail -300
```

## Acceptance Rule

No movement alias should be proposed unless the matrix ties an unknown opcode to
a specific action with repeat/release behavior and position evidence. Click NPC
and ESC/menu results should be treated as separate non-movement controls unless
the payload evidence proves otherwise.
