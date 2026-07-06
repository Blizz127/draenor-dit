# draenor-dit

Build tracking and fix documentation for getting
[`EyalMK/Draenor-Core`](https://github.com/EyalMK/Draenor-Core) (World of Warcraft:
Warlords of Draenor, patch 6.2.3, build 20779) to configure and compile on a modern
Linux toolchain — GCC 13 / OpenSSL 3.x / ACE 7.1.2 / Boost 1.83.

The upstream project targets an older Windows/Visual Studio + OpenSSL 1.x era toolchain,
so a fresh clone does not build cleanly on current Linux. The fixes needed to get it
building are catalogued in **[BUILD.md](BUILD.md)**, grouped by root cause so the same
patterns can be recognized and fixed if they recur deeper in the build.

## Status

- Configures and compiles cleanly through **~36%** of the full build.
- Zero unresolved compile errors up to that point.
- `shared`, `game`, `collision`, and `authserver` all link successfully.
- Remaining work is deep in `src/server/scripts` (world-content scripts); no known
  blockers ahead beyond possibly more of the same two bug categories (see
  [BUILD.md](BUILD.md), "Genuine content/API bugs").

## Quick start

See **[BUILD.md](BUILD.md)** for the full prerequisites, configure/compile commands,
and the important gotchas (notably: **leave precompiled headers enabled** — do not pass
`-DNOPCH=1`).
