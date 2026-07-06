# Building Draenor-Core on a modern Linux toolchain

Notes for getting [`EyalMK/Draenor-Core`](https://github.com/EyalMK/Draenor-Core)
(WoD 6.2.3, build 20779) configuring and compiling on GCC 13 / OpenSSL 3.x /
ACE 7.1.2 / Boost 1.83. Written against a fresh `--depth 1` clone.

## Prerequisites

### System packages

Debian/Ubuntu names (adjust for Fedora/Bazzite):

```
cmake build-essential clang
libmysqlclient-dev libssl-dev libbz2-dev zlib1g-dev libreadline-dev
libace-dev libboost-dev
```

On an immutable base like Bazzite, do this inside a `toolbox`/`distrobox` container
rather than fighting the immutable base image directly. Set that up first.

### Getting the source and fixes

```bash
git clone --depth 1 https://github.com/EyalMK/Draenor-Core.git
cd Draenor-Core
git apply /path/to/draenor-core-build-fixes.patch
```

## Configure and compile

```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo -DTOOLS=0 -DWITH_WARNINGS=0
make -j$(nproc)
```

### Gotchas

- **Leave precompiled headers ENABLED. Do not pass `-DNOPCH=1`.** Disabling PCH
  produces dozens of spurious "missing include" errors across `src/server/scripts`
  that do not exist under a normal build — the project's `ScriptPCH.h` already
  includes everything those files need. Disabling it was an early over-cautious
  decision with no real justification.

- **Tight on disk?** RelWithDebInfo debug symbols make individual `.o` files 20–60 MB
  each. After configuring, strip `-g` from the compile flags:

  ```bash
  find . -name flags.make -exec sed -i 's/ -g / /g' {} +
  ```

## Fixes catalogue

Grouped by root cause. Categories 1–8 are environment/toolchain issues; category 9 is
genuine content/API bugs in the codebase itself.

### 1. OpenSSL 3.x opaque types
`EVP_CIPHER_CTX` / `HMAC_CTX` were stack-allocatable structs in OpenSSL 1.x; in 3.x
they are opaque and must be heap-allocated via `_new()` / freed via `_free()`.
- Files: `ARC4.{h,cpp}`, `HMACSHA1.{h,cpp}`

### 2. OpenSSL 3.x version macro layout
`FindOpenSSL.cmake`'s version-string parser assumed a single-line `#define`, which 3.x
no longer emits. Guarded against the resulting empty regex match.
- Files: `FindOpenSSL.cmake`

### 3. `my_bool` removed in MySQL Connector/C 8.0+
Shimmed back as `typedef bool my_bool` in the Database layer.

### 4. C++14 requirement from modern ACE
Modern ACE requires C++14. Bumped from `-std=c++0x`. Also removed two places
(`cmake/compiler/{gcc,clang}/settings.cmake`) that silently re-forced `-std=c++11`
immediately afterward — the *last* `-std=` flag on the command line wins, so those
were quietly overriding the bump.

### 5. `CR_UNUSED_1` macro collision
MySQL's `errmsg.h` and WoW's `CombatRating` enum both define this name. `#undef`'d it
after the MySQL include in `Field.h`.

### 6. `#pragma region` / `#pragma endregion` inside enum bodies
Legal (non-standard) under MSVC; a hard compile error under GCC/Clang because pragmas
aren't valid at that grammar position at all. Stripped from `Opcodes.h` (18 instances).
The 4 other files using these pragmas *outside* enum bodies were left alone — harmless
there.

### 7. Case-sensitive filesystem issues
`Gilneas.h` (referenced) vs. `gilneas.h` (actual on disk). Classic Windows-dev →
Linux-build breakage. Fixed one `CMakeLists.txt` reference and three `#include`
directives.

### 8. Vendored Boost missing `preprocessor/debug/`
Root cause: the repo's `.gitignore` has an overly broad `[Dd]ebug/` rule (intended for
Visual Studio build-output folders) that also matches this legitimately-named Boost
source subdirectory — so those 3 files silently never got committed. Copied them in
from system Boost (this part of Boost is untouched across decades of releases, so a
version mismatch is a non-issue).

> **Watch for recurrence:** anywhere else in the repo that same gitignore rule could
> have swallowed real files. All of `dep/` was checked for other directories literally
> named `debug` and this was the only one, but not every possible pattern match was
> exhaustively checked.

### 9. Genuine content / API bugs (not environment issues)

- **`Unit::CastWithDelay(delay, target, spellId, triggered)`** was called in 23+ places
  across script files but never existed on `Unit`. Implemented it using the existing
  `EventProcessor` / `BasicEvent` pattern already used elsewhere in the codebase (see
  `Unit::CastWithDelay` in `Unit.cpp`). It looks up the target by GUID at execution
  time rather than storing a raw pointer, so it stays safe if the target despawns
  before the delay elapses.

- **`Unit::m_cloudStacks`** — referenced by `spell_generic.cpp`'s login effect but
  never declared. Added as a plain public `uint32` counter. Not wired to any gameplay
  mechanic yet; just makes the reference-on-login compile and behave sanely.

- **`Creature::SetSeerGUID`** doesn't exist — `stormwind_city.cpp` had the call
  backwards. The vision-sharing mechanic lives on `Player` as `SetSeer(WorldObject*)`.
  Fixed to `owner->ToPlayer()->SetSeer(me)`.

- **Missing `#include`s** for symbols otherwise reachable via `ScriptPCH.h` under a
  normal (non-`NOPCH`) build. Left the includes in place anyway — harmless, and they
  make the files self-sufficient.

## Open items and risk areas

### Bot population system
No Playerbots-equivalent bot-population system exists anywhere in this codebase — a gap
for the "solo populated server" goal shared with the WotLK project. The WoD
private-server scene does not appear to have a maintained equivalent for 6.2.3.

### Gameplay-completeness gaps (per the upstream maintainer's own notes)
These do **not** block compiling — they are gameplay gaps, not build errors — but expect
to hit them once the server actually runs:

- Pathfinding / movement generators
- Area triggers (still the old system rather than Legion-era)
- Pet battles
- Phasing (old phasemask system)
- Most actual Draenor-zone content, including Hellfire Citadel
