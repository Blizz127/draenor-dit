# STATUS — Draenor-Core local build & runtime (updated 2026-07-07)

WoD 6.2.3 (build **20779**) on the `draenor-devbox` distrobox container. This doc is
the live snapshot of what works, what's staged, and the one remaining blocker.

## TL;DR

Server builds clean, **canonical Firestorm WoD databases are imported and booting**,
both binaries run, extracted client data is present, and a 6.2.3.20779 client can
connect, login, enter world, and render Stormwind. The remaining preservation
baseline blocker is normal character movement. Current protocol/evidence rules are
tracked in [docs/PRESERVATION_PLAN.md](docs/PRESERVATION_PLAN.md),
[docs/CURRENT_STATUS.md](docs/CURRENT_STATUS.md), and
[docs/protocol-compatibility-20779.md](docs/protocol-compatibility-20779.md).

## What's done

### 1. Build (Draenor-Core source + build-fixes patch)
- `~/Draenor-Core` in container, patch `draenor-core-build-fixes.patch` applied, clean
  **100% build**, exit 0 (`make -j2`, ~20 min, 0 errors, PCH on).
- Binaries: `build/src/server/{authserver/worldserver}/*`, both `ldd`-clean (ACE 7.1.2,
  OpenSSL 3.0.13, libmysqlclient 8.0.46).

### 2. Databases (canonical, from WOPCore-6.2.3-FirestormWOD)
Imported into Draenor's **own MariaDB on port 3307** (the host's 3306 belongs to the
live `cata-devbox` server and is untouched). User `trinity/trinity`, DBs utf8mb4.

| DB | Tables | Rows | Source |
|---|---|---|---|
| `auth` | 33 | defaults | WOPCore `sql/base/auth_database.sql` (canonical — replaces Phase-1 reconstruction) |
| `characters` | 151 | empty schema | WOPCore `characters_database.sql` (150) + reconstructed `character_cuf_profiles` (1) |
| `world` | 213 | ~2.9M | WOPCore `world_database_wod_firestorm.rar` (extracted) |
| `hotfix` | 40 | ~723K | WOPCore `hotfix-database-wod-firestorm.zip` (extracted) |
| `web` | 3 | defaults | WOPCore `web_database.sql` (loyalty/battlepay) |

Staged/extracted dumps: `runtime/db/`. Schema fix: `runtime/db/character_cuf_profiles.sql`.

### 3. Config
- `/usr/local/etc/firestorm/{authserver,worldserver}.conf` (binaries hardcode this path),
  DB lines set to `127.0.0.1;3307;trinity;trinity;...`.
- `realmlist` id=1 = **"Draenor"**, `127.0.0.1:8085`, **gamebuild 20779**
  (WOPCore dump shipped 20726 — was corrected). `bnet_allowed_build` allows 20779.
- Fixed `Appender.Chat=0,0,0` (invalid type 0) → `=2,2,0,Chat.log,w` in conf + `.conf.dist`.

### 4. Runtime verified
- **authserver**: boots clean, opens `auth` pool on 3307, `Added realm "Draenor"`.
- **worldserver**: boots past DB init (`Realm running as realm ID 1`, `Using World DB:
  FirestormDB Febuary 2016`, `Using DataDir ./`, VMap support included), reaches
  `World initialized`, listens on `0.0.0.0:8085`, and accepts the 20779 client.

### 5. Extractor toolchain (built, verified)
Separate `~/Draenor-Core/build-tools/` (does not touch the server `build/`). All 4 tools
built + run, 0 missing libs:
`mapextractor`, `vmap4extractor`, `vmap4assembler`, `mmaps_generator`.
Driver script: `runtime/extract_maps.sh`.

## Current blocker -> movement protocol/input evidence

The client reaches in-world rendering, but movement is not fixed. Unknown-opcode
instrumentation is active in `/home/blizz/Draenor-Core/src/server/game/Server/WorldSocket.cpp`.
Do not add opcode aliases until a manual or native Windows real-input matrix ties an
unknown opcode to a specific action.

Latest local automated matrix did not produce action-correlated movement packets, so it
is not valid evidence for an alias table.

## Historical blocker -> maps/vmaps/mmaps

Resolved for the current local baseline; kept here for rebuild provenance. If rebuilding
from scratch, use the WoD 6.2.3.20779 client data and do not use Cata maps.

```
Map file './maps/0000_43_31.map': does not exist!
Correct *.map/*.vmtree/*.vmtile files not found in './maps' or './vmaps'
```

### Rebuild/extraction notes
1. `cd` into the container + worldserver run dir:
   `distrobox enter draenor-devbox -- bash -lc 'cd ~/Draenor-Core/run-world'`
2. Run (set CLIENT_DIR to the client folder with `WoW-64.exe` + `Data/`):
   `CLIENT_DIR="/path/to/WoD client" /var/home/blizz/Projects/draenor-dit/runtime/extract_maps.sh`
   - steps 1-3 (maps/dbc/vmaps) are minutes; step 4 (mmaps) is **hours**.
3. Create a GM account from the worldserver console (WoD BNet hashing is fiddly; the
   console does it correctly): `.account create <user> <pass>` then
   `.account set gmlevel <user> 3 -1` (3 = administrator, -1 = realm-all).
4. Point the real WoD 6.2.3.20779 client at the realm and log in.

## Helpers in this repo
- `runtime/start_servers.sh` — start MariaDB-3307 + authserver (bg) + worldserver (fg).
- `runtime/extract_maps.sh` — run all 4 extractors against the client.
- `runtime/db/` — the imported SQL dumps + the cuf_profiles schema fix.

## Hard constraints still in force
No bots/Playerbots/AHBots/fake-population/custom content this phase. WoD 6.2.3 build 20779
only. Do not touch `cata-devbox` or anything under `/var/home/blizz/cata-server/`. Keep the
Draenor MariaDB on 3307 (never 3306). PCH stays on.
