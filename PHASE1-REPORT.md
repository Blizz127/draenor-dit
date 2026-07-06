# Draenor-Core — Phase 1 build & runtime baseline report

Date: 2026-07-06 · Core: [`EyalMK/Draenor-Core`](https://github.com/EyalMK/Draenor-Core)
@ `940e0fbc7f2eaf6179a75271178c6945826cc7a2` (master) · Client target: WoD 6.2.3 build 20779

## TL;DR

The core **builds to 100% on a modern Linux toolchain** and both binaries run.
`authserver` is **fully operational** (listening on the WoD login port, realm registered,
test account created). `worldserver` **builds and starts** but cannot reach a playable
state in this environment because the **world/characters databases and extracted client
data are not available here** — and Phase 2 (in-client testing) additionally needs the
actual WoD 6.2.3 game client, which is a proprietary artifact that must run on your host.

## Environment / toolchain (verified at runtime)

| Component | Version |
|---|---|
| Compiler | GCC (g++) 13.3.0 (Ubuntu 24.04) |
| OpenSSL | 3.0.13 |
| Boost | 1.83.0 |
| ACE | 7.1.2 |
| MySQL client library | 8.0.46 (libmysqlclient-dev) |
| DB server (this env) | MariaDB 10.11.14 |
| CMake | 3.28.3 |
| Host | Ubuntu 24.04 cloud container (not the Bazzite host; no distrobox needed here) |

ACE 7.1.2 and OpenSSL 3.0.13 are confirmed loaded by the running binaries
(`Using ACE version: 7.1.2`, `Using SSL version: OpenSSL 3.0.13`), so the toolchain
compatibility fixes work at runtime, not just at compile time.

## Exact configure / build commands

```bash
git clone --depth 1 https://github.com/EyalMK/Draenor-Core.git
cd Draenor-Core
git apply /path/to/draenor-core-build-fixes.patch      # the patch in this repo
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo -DTOOLS=0 -DWITH_WARNINGS=0
find . -name flags.make -exec sed -i 's/ -g / /g' {} +  # optional: drop debug syms to save disk
make -j2                                                # -j2, NOT -j$(nproc), see note
```

**PCH stayed enabled** (`Build core w/PCH: Yes`, `Build scripts w/PCH: Yes`); `-DNOPCH=1`
was never passed.

**Note on parallelism:** on a 15 GB / 4-core box, `make -j4` OOM-killed `cc1plus`
(`internal compiler error: Bus error`) on the largest PCH translation units
(`Player.cpp`, `DB2Stores.cpp`, `ObjectMgr.cpp`), especially with anything else using
RAM. `make -j2` builds cleanly. With more RAM, `-j$(nproc)` is fine.

## Final binaries produced

| Binary | Path (under `build/`) | Size | Runs? |
|---|---|---|---|
| authserver | `src/server/authserver/authserver` | 677 KB | ✅ yes — listens on `0.0.0.0:1119` |
| worldserver | `src/server/worldserver/worldserver` | 74 MB | ✅ starts; aborts at world-DB init (see blockers) |

Both link cleanly (all shared libraries resolved via `ldd`).

## Fixes applied (the patch)

23 files changed, 226 insertions(+), 62 deletions(−). See `draenor-core-build-fixes.patch`
and `BUILD.md` for the full catalogue. Every fix is classified below using the requested
taxonomy.

### Reproduced from the handoff notes (the original `.patch` file did not survive the prior sandbox, so these were re-derived by hitting the same errors)

| # | Fix | Class |
|---|---|---|
| 1 | `ARC4` / `HMACSHA1`: `EVP_CIPHER_CTX` / `HMAC_CTX` heap-allocated via `_new`/`_free` (OpenSSL 3.x opaque types) | modern Linux/toolchain compat |
| 2 | `FindOpenSSL.cmake`: guard the version parser against OpenSSL 3.x's multi-line `OPENSSL_VERSION_NUMBER` macro | build-system cleanup |
| 3 | `Field.h`: shim `typedef bool my_bool` (removed in MySQL Connector/C 8.0+) | modern Linux/toolchain compat |
| 4 | C++14: bump root `-std=c++0x`→`c++14`, remove the `-std=c++11` re-force in gcc/clang settings (last flag wins) | modern Linux/toolchain compat |
| 5 | `Field.h`: `#undef CR_UNUSED_1` after the MySQL include (collision with `CombatRating` enum) | modern Linux/toolchain compat |
| 6 | `Opcodes.h`: strip 18 `#pragma region`/`endregion` inside enum bodies (hard error under GCC/Clang) | modern Linux/toolchain compat |
| 7 | Case-sensitive includes: `gilneas.h` (Gilneas x3 + CMakeLists) | modern Linux/toolchain compat |
| 8 | Vendored Boost `preprocessor/debug/{assert,error,line}.hpp` restored (swallowed by the repo's overly-broad `.gitignore` `[Dd]ebug/` rule) | build-system cleanup |
| 9 | `Unit::CastWithDelay` implemented (EventProcessor/BasicEvent, GUID-resolved target); `Unit::m_cloudStacks` stub; `Creature::SetSeerGUID`→`Player::SetSeer` | real source/API bug |

### New blockers found beyond the handoff (build never reached these before — prior run stopped ~36%)

| # | Fix | Class |
|---|---|---|
| 10 | `tanaan_jungle_100.cpp`: `#include "Tanaan_jungle_100.h"`→`tanaan_jungle_100.h` | modern Linux/toolchain compat (case) |
| 11 | `gorgrond.cpp`: `#include "Gorgrond.hpp"`→`gorgrond.hpp` | modern Linux/toolchain compat (case) |
| 12 | `Player.cpp`: add explicit template instantiations `Player::UpdateVisibilityOf<AreaTrigger>` and `<Conversation>` (undefined references at worldserver link); add the two includes so the types are complete | real source/API bug |

A full scan of `src/server/scripts` for case-mismatched `#include` targets (both `.h` and
`.hpp`) found **only** the two above beyond the handoff's Gilneas fix.

## Runtime baseline (Phase 1)

| Step | Result |
|---|---|
| 1. authserver & worldserver build | ✅ both build, 100% |
| 2. Configure DBs & config files | ✅ `auth`/`world`/`characters` DBs + `trinity`/`trinity` user; configs from `.conf.dist` (default creds already match) |
| 3. Start authserver | ✅ **running**, `DatabasePool 'auth' opened successfully`, `Added realm "Draenor"`, listening `0.0.0.0:1119` |
| 3b. Start worldserver | ⚠️ starts, loads ACE/OpenSSL/config, then **aborts** at world-DB init: `Cannot connect to world database` (all `world.*` tables missing) |
| 4. Create a test account | ✅ account `TEST` (id 1, expansion 5 = WoD) created; realm registered → build 20779 |
| 5. Client login / realm / char create / enter world | ⛔ **not possible in this environment** — needs the WoD 6.2.3 game client (see blockers) |

### How authserver was brought up

The repo ships **no auth schema** (no `account`/`realmlist` tables — those live only in the
external `milleniumstudio/docker-wod` image's baked DB). I reconstructed a minimal `auth`
schema **directly from the 200 prepared statements the server dumps at startup**
(`runtime/auth_schema_reconstructed.sql`), then added the startup-queried tables
(`bnet_allowed_build`, `firewall_farms`). With that in place authserver reaches ready state.
**This reconstructed schema is a scaffold, not the canonical DB — see "suspicious fixes".**

## Top 5 blockers (to a playable world)

1. **World database not populated.** worldserver aborts immediately at world-DB init because
   every `world.*` table is missing. The world *data* is shipped as SQL
   (`sql/base/worldlive` ≈ 404 MB, `sql/base/worldpvp` ≈ 321 MB) but is **not imported** and
   was never imported here. *Class: database/content.* *Smallest fix: import those SQL sets
   into the `world` DB.*
2. **Characters DB schema is absent from the repo.** No `characters` base schema ships (only
   two tiny update files). worldserver needs it to start fully. *Class: database/content.*
   *Fix: obtain the characters schema from the upstream/Docker DB dump.*
3. **Auth/characters schemas only exist in the external Docker DB.** The canonical
   Firestorm/Project-Hellscream auth+characters DB is baked into `milleniumstudio/docker-wod`,
   not in git. My reconstructed auth schema unblocks authserver but is not authoritative.
   *Class: database/content / config.*
4. **No extracted client map data.** Only `dbc/` ships (1030 `.dbc`/`.db2` — enough for data
   stores). `maps/`, `vmaps/`, `mmaps/` are absent, so movement, LOS and pathfinding cannot
   work even once the DB is up. *Class: client data/version.* *Fix: run the map extractors
   (`-DTOOLS=1`) against a WoD 6.2.3 client.*
5. **No WoD 6.2.3 game client here (headless container).** Phase 2 — login, zone entry,
   quests, loot, XP — requires the actual client connecting to the realm. *Class: client
   data/version.* This must be done on your Bazzite host where the client lives.

## Smallest next fix

Import the shipped world SQL into the `world` DB and obtain the `characters` schema, then
re-run `worldserver` and capture the next blocker:

```bash
cat "sql/base/worldlive/"*.sql | mysql -u trinity -ptrinity world
# then import worldpvp, then the characters schema from the upstream DB dump
```

Everything past that (login, movement, content) is gated on the client + extracted maps,
which belong on the host, not this container.

## Suspicious fixes that should be reviewed before committing to the core

- **`runtime/auth_schema_reconstructed.sql` is reconstructed, not canonical.** Column
  *names* come from the server's own prepared statements (reliable); column *types, indexes,
  defaults, and a few positional-INSERT layouts* (notably `account_banned`'s 7th column,
  guessed as `gmlevel`) are best-effort. It gets authserver running but the real
  Firestorm auth DB should replace it before trusting SRP6 / Bnet2 login semantics.
- **`Unit::m_cloudStacks`** is an unwired stub (per the handoff) — compiles and resets on
  login, no gameplay meaning.
- **`Unit::CastWithDelay`** is a faithful reimplementation of a method the scripts assume
  exists; behaviour matches the surrounding EventProcessor idiom but was never validated
  against live gameplay.
- The **two new `UpdateVisibilityOf` instantiations** are almost certainly correct (they
  mirror the existing five and resolved the only link errors), but they were added to satisfy
  the linker, not verified in a running world.

## Is the server ready for bot / population investigation?

**No, not yet.** The build baseline is solid, but the *runtime* baseline is blocked on the
world/characters DB and client data. Bot/Dead-Internet-Theory work should not start until a
character can actually enter the world — which needs the real DB dump + client on the host.
The build side is ready; the world side is not.
