# draenor-dit

Build tracking and fix documentation for getting
[`EyalMK/Draenor-Core`](https://github.com/EyalMK/Draenor-Core) (World of Warcraft:
Warlords of Draenor, patch 6.2.3, build 20779) to configure and compile on a modern
Linux toolchain — GCC 13 / OpenSSL 3.x / ACE 7.1.2 / Boost 1.83.

The upstream project targets an older Windows/Visual Studio + OpenSSL 1.x era toolchain,
so a fresh clone does not build cleanly on current Linux. The fixes needed to get it
building are catalogued in **[BUILD.md](BUILD.md)**, grouped by root cause so the same
patterns can be recognized and fixed if they recur deeper in the build.

## Status (verified 2026-07-06, upstream `940e0fb`)

- ✅ **Builds to 100%** on GCC 13.3 / OpenSSL 3.0.13 / ACE 7.1.2 / Boost 1.83 / MySQL 8.0.46.
- ✅ Both binaries produced: `authserver` (677 KB) and `worldserver` (74 MB); both run.
- ✅ `authserver` **fully operational** — listens on `0.0.0.0:1119`, realm registered,
  test account created.
- ⚠️ `worldserver` builds and starts but can't reach a playable state without the
  world/characters DB import and extracted client data (see the report).
- The complete fix set is in **`draenor-core-build-fixes.patch`** (23 files).

## Documents

- **[BUILD.md](BUILD.md)** — prerequisites, exact configure/compile commands, and the full
  fix catalogue (12 categories). Notably: **leave PCH enabled** (do not pass `-DNOPCH=1`)
  and use `-j2` on low-RAM boxes.
- **[PHASE1-REPORT.md](PHASE1-REPORT.md)** — build & runtime baseline report: versions,
  binaries, what works, what's blocked, top 5 blockers, and whether it's ready for
  bot/population work (not yet).
- **`draenor-core-build-fixes.patch`** — apply against a fresh `--depth 1` clone.
- **`runtime/`** — reconstructed `auth` schema (scaffold, see report caveats) and an
  example config.
