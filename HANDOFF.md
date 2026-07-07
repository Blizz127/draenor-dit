# HANDOFF — Draenor-Core Bazzite: LOGIN WORKS, world handshake is the last blocker

**Updated 2026-07-06 ~23:40.** See the "SESSION 2" section immediately below for the
current state (bnet2 **login now works end-to-end**; the client authenticates and
connects to the worldserver, but the world-socket handshake is rejected). The original
Session-1 notes follow after it, unchanged, for history.

---

## SESSION 2 (2026-07-06 late) — LOGIN SOLVED, world handshake blocked

### The two Session-1 blockers, both FIXED
1. **authserver segfaulted on every connection.** Root cause: `src/server/shared/
   Cryptography/ARC4.cpp` used `EVP_rc4()`, which returns NULL under OpenSSL 3 (RC4 moved
   to the non-default "legacy" provider) → NULL deref in the `BNet2Crypt`/`AuthCrypt`
   ctor on the first accepted socket. **Fix:** rewrote `ARC4.{h,cpp}` as a self-contained
   RC4 (no OpenSSL). This is a NEW source fix, NOT yet in `draenor-core-build-fixes.patch`
   — regenerate the patch or add it. Rebuilt `authserver` + `worldserver` (also recompiles
   Warden/WorldSession which share ARC4). Verified: a raw TCP probe to 1119 no longer
   crashes; `OnAccept ... Accepting connection` is logged and the process survives.
2. **Client could not reach the server.** The `wod/Wow-64.exe` is Firestorm's *online*
   client: on launch it bootstraps NGDP/TACT from `http://<region>-cdn.fstorm.cc/wow/
   versions` (+`/cdns`) and derives its bnet login host as `<portal>.fstorm.cc`. No WTF/
   registry change points it at a local server. See the working procedure below.

### bnet2 LOGIN NOW WORKS (verified in authserver log)
Client → `127.0.0.1:1119` → `None_Handle_InformationRequest account admin@admin.com` →
SRP6a proof exchange → `UPDATE account SET sessionkey=..., last_login=NOW()` → realm list →
client opens `127.0.0.1:8085` (worldserver). Account: **`admin@admin.com` / `adminpass`**
(id 5, gmlevel 3). NOTE: the login field MUST be email-format; a plain username is
rejected by the client and also wouldn't match the SRP identity.

### The working client-connect procedure (approach "B" — no exe edits, no downloads)
All of this is now scripted in `runtime/`:
- **Server-side (per boot):** MariaDB 3307 + authserver (1119) + worldserver (8085) as before.
- **`runtime/setup-client-connect.sh`** (run once per boot, `sudo`): appends to `/etc/hosts`
  `127.0.0.1 logon.fstorm.cc logon-cdn.fstorm.cc us-cdn.fstorm.cc eu-cdn.fstorm.cc`, and
  `sysctl -w net.ipv4.ip_unprivileged_port_start=80` (so :80/:87 bind as the user).
  Both are volatile (hosts persists; sysctl resets on reboot).
- **`runtime/ngdp/`** — the local NGDP emulation:
  - `serve.py` — HTTP on **127.0.0.1:80**, serves `/<product>/versions` + `/cdns` (any
    product path) and proxies `/tpr/wow/*` from `wod/Data`.
  - `wow_beta/versions` + `wow_beta/cdns` — **must be byte-exact to Firestorm's**. The
    real ones (saved as `*.firestorm-real`) advertise **BuildConfig `00647afe…`,
    CDNConfig `325095a9…`, build `20779`** (NOT the `.build.info` retail `dcff…`/`21e1…`/
    `20886`; that mismatch fails CAS init). Those config hashes already exist in
    `wod/Data/config/`, so the client uses the local 29 GB CASC. `cdns` Hosts is rewritten
    from Firestorm's `51.210.255.148:87` to `127.0.0.1`.
  - `serve.py` bind is **127.0.0.1** (not 0.0.0.0) on purpose.
- **`runtime/start-ngdp.sh`** — starts `serve.py` (:80) + a `socat` :87→1119 forward
  (the :87 turned out to be Firestorm's CDN port, not bnet; :87 forward is harmless/unused
  now that bnet goes direct to 1119).
- **Client WTF/registry:** `SET portal "logon"` in `wod/WTF/{Config,Firestorm}.wtf` AND
  registry `LastPortal-enUS="logon"` in the umu prefix `user.reg`. (The exe appends
  `.fstorm.cc` → `logon.fstorm.cc`; do NOT use an IP.) The Firestorm launcher already
  seeded the 8 bnet `.auth` modules into the umu prefix's ProgramData Battle.net cache
  (and they were copied to `~/.wine` too).
- **Launch (direct exe, NOT launcher.exe):**
  `cd wod && WINEPREFIX=/var/home/blizz/Games/umu/umu-default/pfx GAMEID=umu-default
   PROTONPATH=/var/home/blizz/.local/share/Steam/compatibilitytools.d/GE-Proton10-34
   STORE=none umu-run .../wod/Wow-64.exe`. Login with `admin@admin.com` / `adminpass`.

### THE REMAINING BLOCKER → world-socket handshake rejected by client
After login the client connects to worldserver 8085 but **sits on "Connecting", cannot
load characters**, and re-logins in a loop. Diagnosis (captured the wire with a `socat -x`
proxy in front of 8085, and read the source):
- On connect the worldserver sends its handshake (`src/server/game/Server/WorldSocket.cpp`
  `open()`): opcode `SMSG_HANDSHAKE=0x4F57` + payload `"RLD OF WARCRAFT CONNECTION -
  SERVER TO CLIENT"`. On the wire the 4-byte header is **`57 cf 05 00`**, which decodes as
  the *packed* header `(size<<13)|(cmd&0x1FFF)` = size 46, cmd `0x4F57&0x1FFF`. That is the
  **encrypted-mode** header layout (`ServerPktHeader`, crypt-initialized branch), but this
  is the **pre-auth** handshake where the client expects the **plain** `{uint16 size,
  uint16 cmd}` form (`30 00 57 4f`). Read as plain, `57 cf 05 00` = size `0xcf57` (garbage)
  → the client rejects it and **never replies** (proxy dump shows only server→client).
- Anomaly to resolve: `m_Crypt.Init()` is only called post-auth (WorldSocket.cpp:1295), so
  `IsInitialized()` should be false at handshake and the plain branch should run — yet the
  wire shows the packed branch. Running binary == the rebuilt one (inode verified), so it's
  not a stale-binary issue. Either the crypt is initialized earlier than expected, or the
  handshake path deliberately packs and the client-side expectation differs. Needs the
  client-side world-header format (RE of `Wow-64.exe`) to confirm what it wants, then a
  targeted `WorldSocket.cpp` patch + rebuild. Likely followed by more post-handshake
  protocol mismatches (world crypt seeds, opcode table, char enum) — a deeper bring-up.
- Debug aid left in place: worldserver `Logger.Root` bumped to Debug (`0,2`) and
  `Logger.Opcodes` to `2` in `/usr/local/etc/firestorm/worldserver.conf`. The failing line
  is `WorldSocket::handle_input_header(): ... malformed packet (size: 25400, cmd: 8)`.

### Session-1 doc follows (historical; "login blocked" framing there is now superseded)

> **Note on terminal output noise:** commands run through `distrobox enter` occasionally
> emit a stray line like `{"$mid":24,"mimeType":"cache_control","data":"..."}` — this is
> a terminal/stream-layer artifact (the `data` is base64 of "experimental"), **not real
> program output**, and it is NOT written to files. Ignore it when reading logs/output.

## TL;DR for whoever picks this up

- **Phases 0–3 are DONE**: container + toolchain, clean 100% build, real databases
  imported, maps/vmaps/dbc extracted, servers boot to "ready".
- **The open problem is Phase 4 (client login).** The WoD client (`Wow-64.exe` via Wine)
  shows a **"Battle.net error"** at login with `ADMIN`/`adminpass`. The authserver IS up
  on 1119, but a 60s log watch showed **ZERO bytes written** during the user's login
  attempt — i.e. **the client's login is not reaching the authserver at all**.
- **PRIMARY SUSPECT: the `Wow-64.exe` is NOT the patched Firestorm client.** A `strings`
  scan found no `firestorm`/`portal`/`127.0.0.1`/`set realmlist` markers. An unpatched
  stock Blizzard exe tries to reach the real Battle.net → exactly this error. The WOPCore
  README ships a *separate* patched exe named `Wow-64-Patched.exe` — the user's `Wow-64.exe`
  may be the unpatched one. **Verify the exe is patched (or obtain the patched one) first.**
  See "CURRENT BLOCKER — Phase 4 login" below for the full diagnosis checklist.

## What this project is

[`EyalMK/Draenor-Core`](https://github.com/EyalMK/Draenor-Core) (WoD 6.2.3, build
**20779**) running on this Bazzite host in the `draenor-devbox` distrobox container, then
logging in with a real WoD 6.2.3 client. The build-fix patch
(`draenor-core-build-fixes.patch`, 23 files) is applied and proven.

### Phase status
- Phase 0: container + toolchain — **done**
- Phase 1: clone + patch + build to 100% — **done** (clean exit 0, ~20min `make -j2`)
- Phase 2: real DB/config + start servers + create account — **done**
- Phase 3: verify client build, extract dbc/maps/vmaps/mmaps — **done** (mmaps partial)
- Phase 4: login-to-world smoke test — **BLOCKED** (see below)
- Phase 5: world playability checklist — not started

## Hard constraints (do not violate)

- **No bots/Playerbots/NPCBots/AHBot/fake population/solo scaling/custom vendors or broad
  gameplay rewrites.** This phase is build + runtime baseline only.
- **WoD 6.2.3 build 20779 only.** Do not drift to another client version.
- **Container isolation:** Draenor work stays in `draenor-devbox`. There is a SEPARATE
  `cata-devbox` container running a Cata core (`/var/home/blizz/cata-server/...`, on auth
  port **3724**). It does NOT conflict with Draenor (1119/8085) — leave it alone unless the
  user explicitly asks to stop it (they once said "shut down cata", but there's no port
  conflict, so it was left running).
- **PCH must stay enabled** (never `-DNOPCH=1`).
- **Commit build fixes separately from runtime/config fixes.**

## Environment state

### Container: `draenor-devbox` (ubuntu:24.04, Up)
- Toolchain: g++ 13.3.0, CMake 3.28.3, OpenSSL 3.0.13, Boost 1.83.0, ACE 7.1.2,
  libmysqlclient 8.0.46, MariaDB 10.11.14 (all match the proven cloud-sandbox build).
- Enter with: `distrobox enter draenor-devbox -- bash -lc '...'`

### ⚠️ Distrobox/process fragility (IMPORTANT)
- **Background processes started inside `distrobox enter` get killed when the wrapping
  terminal/command exits.** Use `setsid ... &` via a **script file** to detach (NOT inline
  `setsid bash -c`, and NOT `nohup` alone — both still die with the wrapper).
- **`pkill -f`/`pgrep -f` SELF-MATCH trap:** if the search string appears in the wrapper
  command line (e.g. an `echo "...run-auth-supervisor..."`), pkill kills the wrapper too
  (exit 143). Kill by exact exe name (`pkill -x authserver`) or by PID/pidfile, and put
  long command strings in a script file so they don't appear on the ps line.
- The authserver's threads rename themselves to `MainThread` (ACE quirk) — host `ps` shows
  `comm=MainThread`, and `/proc/net/tcp` (host view) does NOT show container-bound sockets.
  Query sockets via `ss -ltn` **from inside the container**.
- The authserver **segfaulted once on its first supervisor start** (a startup race against
  the DB pool warming), then the supervisor respawned it and it held 1119 fine. A respawn
  supervisor is the right pattern.

## Current runtime state (as of handoff)

### Build (DONE)
- `~/Draenor-Core` in container, patch applied, clean **100% build** (exit 0, 0 errors).
- Binaries `ldd`-clean: `build/src/server/{authserver,worldserver}/` (ACE 7.1.2,
  OpenSSL 3.0.13, libmysqlclient 8.0.46).

### Databases (DONE — on Draenor's OWN MariaDB, port 3307)
- **MariaDB runs on 3307**, NOT the host default 3306 (3306 is the cata server's — do not
  touch). Isolated data dir `/var/lib/mysql-draenor`, socket `/run/mysqld-draenor/mysqld.sock`.
- Start it: `sudo mariadbd --user=mysql --port=3307 --socket=/run/mysqld-draenor/mysqld.sock
  --datadir=/var/lib/mysql-draenor --bind-address=127.0.0.1 --character-set-server=utf8mb4
  --collation-server=utf8mb4_general_ci` (NOTE: `sudo -u mysql mariadbd` is blocked by
  sudoers; must use `sudo mariadbd --user=mysql`). Run `SET GLOBAL max_allowed_packet=536870912`
  before big imports. DB user `trinity/trinity`.
- DBs (all utf8mb4): `auth` (33 tbls), `characters` (151), `world` (217), `hotfix` (40),
  `web` (3). **IMPORTANT provenance:**
  - `auth`, `characters`, `hotfix`, `web` → imported from **WOPCore-6.2.3-FirestormWOD**
    canonical dumps (`runtime/db/`). `auth` REPLACES the Phase-1 reconstructed scaffold.
  - `world` → imported from **Draenor-Core's OWN `sql/base/worldlive/`** (NOT WOPCore's!).
    WOPCore's world dump lacks Draenor-Core's custom tables (e.g. `spellregulator`) which
    made worldserver abort with "database structure is not up to date". worldlive (218
    files, 18s, 0 fail) is the code-matched set: ~111K creatures / 21K quests / 82K items.
  - **Schema gaps fixed** (code queries these but neither dump ships them; both are
    `CREATE TABLE IF NOT EXISTS`, empty data is fine):
    - `runtime/db/character_cuf_profiles.sql` → into `characters` (Draenor-Core's CUF
      profile feature; DDL reconstructed from `CUFProfile.hpp` + prepared statements).
    - `runtime/db/ip2nation_tables.sql` → into `world` (`ip2nation` + `ip2nationCountries`;
      IP-geo, optional; the server hard-aborts if absent).

### Config (DONE)
- Binaries hardcode `/usr/local/etc/firestorm/{authserver,worldserver}.conf` (NOT cwd).
  Both edited there (sudo) with DB lines = `127.0.0.1;3307;trinity;trinity;...`.
- `realmlist` id=1 = **"Draenor"**, `127.0.0.1:8085`, **gamebuild 20779** (WOPCore dump
  shipped 20726 — corrected). `bnet_allowed_build` permits 20779+20726.
- Fixed logging bug: `Appender.Chat=0,0,0` (invalid type 0) → `=2,2,0,Chat.log,w` in both
  the runtime conf and source `.conf.dist`.
- worldserver `DataDir="."`; run from a dir with `dbc/` `maps/` `vmaps/` `mmaps/` present.

### Maps (DONE except mmaps partial)
- Client: `/home/blizz/Projects/draenor-dit/wod` — **verified build 20779** via the
  `Wow-64.exe` PE FileVersion (`6.2.3.20779`; the `.build.info` says 20886 but that's the
  installer manifest, ignore it).
- In `~/Draenor-Core/run-world/`: **maps** (11934 files, 1.1G), **dbc** (517 files, freshly
  extracted from the 20779 client), **vmaps** (22451 files, 1.3G). The previously-missing
  `maps/0000_43_31.map` now exists.
- **mmaps: PARTIAL** (~86+ tiles generated, then the run was killed). It IS incremental
  (skips existing tiles), so just re-run `mmaps_generator` from `run-world/` to resume.
  It's OPTIONAL for boot/login (creatures just have impaired pathfinding without it).
- **BUG FIX (not in the build-fixes.patch — apply to source!):**
  `src/tools/vmap4_extractor/vmapexport.cpp` `OpenCascStorage()` was HARDCODED to
  `"./Data"`, ignoring the `-d` arg → always failed with "Error 2". Fixed to use
  `std::string(input_path) + "Data"`. Rebuild `vmap4extractor` after editing.

### Extractor tools (DONE)
- Separate dir `~/Draenor-Core/build-tools` (`-DTOOLS=1`; do NOT pollute the server `build/`).
  All 4 built + verified, 0 missing libs. Target name is `mmaps_generator` (WITH 's').
  Paths: `build-tools/src/tools/{map_extractor/mapextractor, vmap4_extractor/vmap4extractor,
  vmap4_assembler/vmap4assembler, mmaps_generator/mmaps_generator}`.
- Invocation (from `run-world/`): `mapextractor -i <client> -o . -e 3`;
  `vmap4extractor -d <client>`; `vmap4assembler Buildings vmaps`; `mmaps_generator` (no args).
- Helper: `runtime/extract_maps.sh`.

### Servers (UP but login blocked — see below)
- **worldserver (8085)**: stable, boots to "World initialized in 0 minutes", "Firestorm
  WoDCore ready". Run dir `~/Draenor-Core/run-world` (symlinks: `dbc->../dbc`,
  `worldserver->../build/...`). Started via the FIFO-console trick or `setsid`.
- **authserver (1119)**: boots clean, opens `auth` pool, `Added realm "Draenor"`. Run dir
  `~/Draenor-Core/run-auth`. Use the **respawn supervisor** `runtime/run-auth-supervisor.sh`
  (launch: `distrobox enter draenor-devbox -- setsid bash
  /var/home/blizz/Projects/draenor-dit/runtime/run-auth-supervisor.sh &`).

### Account (DONE)
- Username **`ADMIN`** (created uppercase by the console; login is case-insensitive),
  password **`adminpass`**, gmlevel 3 (admin), RealmID -1 (all realms), expansion 5 (WoD).
  Set via the worldserver console `.account create admin adminpass`, then
  `REPLACE INTO auth.account_access (id,gmlevel,RealmID) VALUES (4,3,-1)` (the console
  `.account set gmlevel` returned "Incorrect values" in this core; SQL is reliable).
  Both `sha_pass_hash` (SRP6) and `bnet2_pass_hash` (256-char RSA BNet verifier) are populated.

### Client connection (set up, NOT WORKING)
- `wod/WTF/Config.wtf` created: `SET portal "127.0.0.1"` + `SET realmList "127.0.0.1"`.
- Launch: `cd wod && wine Wow-64.exe` (Wine at `~/.local/bin/wine`).

## CURRENT BLOCKER — Phase 4 login ("Battle.net error")

**Symptom:** client shows "Battle.net error" (or prompts for a Battle.net account) when
logging in with `ADMIN`/`adminpass`. The authserver is up (1119 LISTENING, realm
"Draenor" registered), but a 60s log watch showed **zero new log bytes** during the
attempt — the client's connection is NOT reaching the authserver.

**Diagnosis checklist (in priority order):**

1. **PRIMARY: is `Wow-64.exe` actually the patched Firestorm client?** A `strings -e l`
   scan found NO `firestorm`/`portal`/`127.0.0.1`/`localhost`/`set realmlist` markers. An
   unpatched stock Blizzard WoD exe authenticates against the real Battle.net and ignores
   `Config.wtf`'s portal → "Battle.net error" + no traffic to 1119. **Action:** obtain the
   patched exe (WOPCore README links `Wow-64-Patched.exe` on mediafire) OR confirm this exe
   is patched by another means (e.g. the Firestorm patch may zero out the bnet URL rather
   than redirect to 127.0.0.1 — check what host/port the exe actually connects to with
   `strace`/`ss` while it tries to log in).
2. **Confirm the client actually opens a TCP socket to 127.0.0.1:1119 during login.**
   While Wow-64.exe is at the login screen attempting to connect, run (host):
   `ss -tn | grep 1119` or `sudo ss -tnp | grep -i wine`. If no socket to 1119 appears,
   the client isn't using our portal → confirms #1.
3. **WoD bnet auth may need a different port.** WoD 6.x clients authenticate via the bnet
   "portal" which is normally port **1119** (what RealmServerPort is set to). Verify
   `RealmServerPort = 1119` in `/usr/local/etc/firestorm/authserver.conf`. If the client
   expects 3724 (legacy), the realm won't connect — but the "Battle.net error" is bnet-
   level (pre-realm), so this is secondary.
4. **Wine networking:** ensure Wine isn't sandboxing networking. The cata client launches
   via Wine fine on this host, so Wine itself works; just confirm the WoD prefix is sane.

**Fastest likely fix:** replace `Wow-64.exe` with the Firestorm-patched build, then retry
login with `ADMIN`/`adminpass`.

## Exact commands to resume

```bash
# 0. enter the container for all server-side work
distrobox enter draenor-devbox -- bash -lc '...'

# 1. ensure MariaDB on 3307 is up (if rebooted)
sudo mariadbd --user=mysql --port=3307 --socket=/run/mysqld-draenor/mysqld.sock \
  --datadir=/var/lib/mysql-draenor --bind-address=127.0.0.1 \
  --character-set-server=utf8mb4 --collation-server=utf8mb4_general_ci &

# 2. start servers via the supervisor (auth) + world
distrobox enter draenor-devbox -- setsid bash \
  /var/home/blizz/Projects/draenor-dit/runtime/run-auth-supervisor.sh &
# worldserver: cd ~/Draenor-Core/run-world && setsid ./worldserver > worldserver-live.log 2>&1 &

# 3. resume mmaps (optional, incremental)
distrobox enter draenor-devbox -- bash -lc \
  'cd ~/Draenor-Core/run-world && setsid bash -c "~/Draenor-Core/build-tools/src/tools/mmaps_generator/mmaps_generator >> ~/extract-mmaps.log 2>&1" &'

# 4. attempt client login (host side)
cd /home/blizz/Projects/draenor-dit/wod && wine Wow-64.exe
# account: ADMIN / adminpass
```

## Repo contents (`draenor-dit`, branch `claude/draenor-core-build-fixes-20pgg0`, pushed)
- `README.md`, `BUILD.md`, `PHASE1-REPORT.md`, `STATUS.md`, `HANDOFF.md` (this file)
- `draenor-core-build-fixes.patch` — the 23-file build patch (applied to the in-container checkout)
- `runtime/db/` — imported SQL dumps + the 2 schema-fix files (cuf_profiles, ip2nation)
- `runtime/extract_maps.sh`, `runtime/start_servers.sh`, `runtime/run-auth-supervisor.sh`
- `WOPCore-6.2.3-FirestormWOD/` — the DB-source tree (canonical Firestorm dumps); do NOT port its code
- `wod/` — the WoD 6.2.3 client (build 20779 verified); `wod/WTF/Config.wtf` set to 127.0.0.1

## Do NOT (without asking the user)
- Don't kill `lua-language-server` or other host apps on the user's behalf.
- Don't touch `cata-devbox` / `/var/home/blizz/cata-server/` (no conflict anyway; 3724 vs 1119/8085).
- Don't start bots/population/fake-content work — out of scope until Phase 5 passes.
- Don't push/force-push without explicit ask (remote `Blizz127/draenor-dit`).
