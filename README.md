# draenor-dit

This repository tracks a World of Warcraft: Warlords of Draenor 6.2.3.20779
preservation baseline for Draenor-Core.

The current goal is to make the project reproducible enough to build, boot,
connect a real 6.2.3.20779 client, login, create or select a character, enter
world, render, move normally, and document every compatibility fix needed along
the way.

This is not a custom gameplay branch. Bots, DIT population systems, garrisons,
custom gameplay, and living-world simulation are explicitly out of scope until
the preservation baseline is proven and documented.

## Current Status

- Client target: WoD 6.2.3.20779.
- Build succeeds on the current local Linux/container toolchain.
- `authserver` starts and listens on `1119`.
- `worldserver` starts and reaches `World initialized` when launched with a
  stable foreground or managed session.
- The client can login, create/select a character, enter world, and render.
- Movement is currently broken.
- The client sends packets during movement attempts, so input is not treated as
  dead.
- Current working hypothesis: a mixed 20726/20779 movement opcode table.

Do not patch movement opcodes until action-correlated evidence exists.

## Documentation

- [docs/PRESERVATION_PLAN.md](docs/PRESERVATION_PLAN.md) - phased preservation
  plan from reproducible build through the later DIT layer.
- [docs/CURRENT_STATUS.md](docs/CURRENT_STATUS.md) - current proven state,
  known unknown opcodes, and active movement hypothesis.
- [docs/TEST_MATRIX_MOVEMENT_20779.md](docs/TEST_MATRIX_MOVEMENT_20779.md) -
  controlled movement test matrix for build 20779.
- [docs/RUNTIME_NOTES.md](docs/RUNTIME_NOTES.md) - local runtime topology,
  ports, client patching notes, and process-management warnings.
- [BUILD.md](BUILD.md) - historical build notes and toolchain fixes.
- [PHASE1-REPORT.md](PHASE1-REPORT.md) - earlier build/runtime baseline report.
