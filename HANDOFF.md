# HANDOFF — Draenor-Core Bazzite build, in progress

Written 2026-07-06 for a session handoff (Claude → GLM in VS Code). Read this first —
it captures exact state, what's done, what's blocked, and how to resume without
re-deriving context.

## What this project is

Getting [`EyalMK/Draenor-Core`](https://github.com/EyalMK/Draenor-Core) (WoD 6.2.3,
build 20779) building and running on this Bazzite host, using a distrobox container
(not touching the immutable host). See `README.md`, `BUILD.md`, `PHASE1-REPORT.md` in
this repo for the full history — a prior cloud-sandbox session already got the core to
a **clean 100% build** and a working `authserver`; that work is captured in
`draenor-core-build-fixes.patch` (23 files) and is considered known-good.

**This host session's job**: reproduce that build locally in a distrobox container, then
push into real runtime testing with the actual WoD 6.2.3 client and real DB assets
(replacing the cloud session's reconstructed auth-schema scaffold with the real thing
if available). Full phased plan is in the conversation; short version:

- Phase 0: container + toolchain baseline — **done**
- Phase 1: clone + patch + build to 100% — **not started, blocked** (see below)
- Phase 2: real DB/config baseline, start servers, create account — not started
- Phase 3: verify client is exactly build 20779, extract dbc/maps/vmaps/mmaps — not started
- Phase 4: login-to-world smoke test with the real client — not started
- Phase 5: world playability checklist — not started

## Hard constraints (do not violate)

- **No bots, Playerbots, NPCBots, fake population, AHBot, fake chat/guilds, solo
  scaling, custom vendors/progression, or broad gameplay rewrites yet.** This phase is
  build + runtime baseline only.
- **Keep WoD 6.2.3 build 20779 as the target.** Do not let anything drift to a different
  client version.
- **Keep this isolated from the user's other project.** There is a separate, unrelated
  `cata-devbox` distrobox container on this host running a WotLK/Cata core
  (`/var/home/blizz/cata-server/bin/{authserver,worldserver}`, currently live/running as
  of this writing). **Do not stop, modify, or touch that container or its processes.**
  This Draenor work must stay in its own container (`draenor-devbox`).
- **PCH must stay enabled.** Never pass `-DNOPCH=1` — disabling it produces spurious
  missing-include errors across `src/server/scripts` (see BUILD.md).
- **Commit build fixes separately from runtime/config fixes.** Don't mix a code patch
  commit with a DB-schema/config commit.

## Environment state right now

### distrobox container: `draenor-devbox` (created this session)

- Image: `docker.io/library/ubuntu:24.04`
- Status: up and running (`distrobox list` shows it `Up`)
- Packages installed and confirmed via `dpkg`: `cmake build-essential clang git
  libmysqlclient-dev libssl-dev libbz2-dev zlib1g-dev libreadline-dev libace-dev
  libboost-all-dev default-libmysqlclient-dev mariadb-server mariadb-client`
- **Nothing has been cloned or built inside it yet.** No `Draenor-Core` checkout exists
  in the container. Phase 1 has not started.
- MariaDB server package is installed but the service was never started
  (`invoke-rc.d: policy-rc.d denied execution of restart` during postinst — normal in a
  container; needs `sudo service mariadb start` or `mariadbd-safe` manually, same as the
  cloud sandbox did).

Enter it with: `distrobox enter draenor-devbox`

### Recorded toolchain versions (Phase 0 report — matches the cloud sandbox exactly)

| Component | Version |
|---|---|
| Compiler | g++ 13.3.0 (Ubuntu 24.04) |
| CMake | 3.28.3 |
| OpenSSL | 3.0.13 |
| Boost | 1.83.0 |
| ACE | 7.1.2 |
| MySQL client | libmysqlclient-dev 8.0.46 |
| MariaDB server | 10.11.14 |

Since these match the cloud sandbox where the patch was proven, no new build surprises
are expected from toolchain drift.

## Current blocker: host resource pressure (NOT a build/code problem)

This is why Phase 1 (the actual `cmake`/`make` build) has not started yet. The build has
PCH-heavy translation units (`Player.cpp`, `DB2Stores.cpp`, `ObjectMgr.cpp`) that already
OOM-killed `cc1plus` in the cloud sandbox at `make -j4` with a full 15GB RAM and *nothing
else running*. This host is currently far more contended than that:

- RAM: ~27Gi/30Gi used, only ~3Gi available
- Swap (zram): essentially full, ~15.4G/15.4G
- Top consumer: `/home/blizz/.vscode/extensions/sumneko.lua-3.18.2-linux-x64/server/bin/lua-language-server`
  at **8.4GB RSS** — this looks abnormal for that process (possible leak), not something
  I caused
- Also present: `/server/xi_map` (2.4GB, unrelated process, not investigated), the user's
  own `cata-server` worldserver (1.4GB, **do not touch**), and normal VSCode overhead

I flagged this and asked the user how to proceed (free memory first vs. proceed anyway
with `-j1`). They attempted to free memory but a recheck showed **no change** — same
8.4GB lua-language-server, same exhausted swap. I asked a follow-up clarifying question
and the user then requested this handoff instead, since they're stepping away.

**Bottom line for whoever resumes:** before running `cmake`/`make` in `draenor-devbox`,
recheck host memory (`free -h`, `ps -eo pid,rss,cmd --sort=-rss | head`). If the
lua-language-server (or whatever else) is still eating most of the RAM/swap, either:
1. get it closed/restarted first (likely a VSCode Lua extension restart or window reload), or
2. accept the risk and build with `make -j1` (slowest but smallest footprint), watching
   `free -h` / `dmesg | grep -i oom` during the build and aborting if things degrade.

Do not jump straight to `-j$(nproc)` or even `-j2` on this host until memory pressure is
confirmed resolved — that combination already caused an OOM `internal compiler error:
Bus error` in a *less* contended environment.

## Exact commands to resume Phase 1 once memory is OK

```bash
distrobox enter draenor-devbox
cd ~   # or wherever you want the checkout — not yet created
git clone --depth 1 https://github.com/EyalMK/Draenor-Core.git
cd Draenor-Core
git apply /var/home/blizz/Projects/draenor-dit/draenor-core-build-fixes.patch
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo -DTOOLS=0 -DWITH_WARNINGS=0
# check free -h here before building
make -j1   # or -j2 only if memory is confirmed free; never -DNOPCH=1
```

If `make` hits a NEW compile/link error not covered by the patch, the pattern from the
cloud session was: fix the smallest local blocker, classify it (modern Linux/toolchain
compat / missing include-PCH fallout / real source-API bug / build-system cleanup /
questionable gameplay behavior), and keep going — see `BUILD.md`'s fix catalogue
(12 categories) for the established taxonomy and examples.

## Reference material already in this repo (`draenor-dit`, branch
`claude/draenor-core-build-fixes-20pgg0`, all pushed)

- `README.md` — top-level status/pointer doc
- `BUILD.md` — prerequisites, exact configure/build commands, full 12-category fix
  catalogue (what each fix was and why)
- `PHASE1-REPORT.md` — the cloud sandbox's build+runtime report: versions, binaries
  produced, blockers, suspicious-fixes list, bot-readiness verdict
- `draenor-core-build-fixes.patch` — the 23-file patch, apply to a fresh `--depth 1`
  clone
- `runtime/auth_schema_reconstructed.sql` — a **scaffold** auth DB schema reconstructed
  from the server's own prepared-statement dump (cloud sandbox had no real DB asset
  available). **Phase 2 on this host should prefer a real DB dump/Docker image if one
  can be found locally** instead of relying on this reconstruction — see PHASE1-REPORT's
  "suspicious fixes" section for exactly what's uncertain about it (column types/indexes,
  one guessed positional-insert column).
- `runtime/authserver.conf.example` — example config used in the cloud sandbox

## What to explicitly NOT do without asking the user

- Don't kill/restart the `lua-language-server` or any other host process on the user's
  behalf — those are their active apps/editor state.
- Don't touch `cata-devbox` or anything under `/var/home/blizz/cata-server/`.
- Don't start bots/population/fake-content work — out of scope until Phase 5 passes.
- Don't push/force-push without explicit ask (this repo's remote is
  `Blizz127/draenor-dit`; the working branch is `claude/draenor-core-build-fixes-20pgg0`).
