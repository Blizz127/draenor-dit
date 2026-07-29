# Supported Client Baseline: WoD 6.2.3.20779 enUS

Date: 2026-07-29  
Phase: 3J-B (preserve working English client baseline)

This document records **local paths, hashes, and configuration** for the
working English 20779 client validated in Phase 3J. It does **not** redistribute
copyrighted client binaries, CASC data, or any bundled private-server stack.

## Status

| Item | Value |
|---|---|
| Role | **Supported test / development client** for Draenor-Core 20779 |
| Validation | Login, in-game chat, movement, NPC/gossip interaction confirmed (Phase 3J) |
| Explicitly not supported as reference | Firestorm-branded `Wow-64.exe` / Firestorm portal-locked client |

Firestorm dead-input findings remain valid as **Firestorm-client-specific**
evidence only. See `docs/protocol/movement-probe-20779.md` Phase 3J sections.

## Working directories

| Role | Path |
|---|---|
| Canonical pack (pristine extract) | `/home/blizz/Games/World of Warcraft 6.2.3.20779 enUS/` |
| Active workspace client (validated session) | `/home/blizz/Projects/draenor-dit/wod/` |
| Mirror extract | `/var/home/blizz/Downloads/World of Warcraft 6.2.3.20779 enUS/` |
| Source archive (local, multi-part) | `/var/home/blizz/Downloads/World of Warcraft 6.2.3.20779 enUS.7z.001` … `.007` (~28 GiB total) |

`wod/` holds the same `Wow-64-Patched*.exe` SHA-256 hashes and the same
`versions` / `cdns` hashes as the Games pack. It is the directory used by
`runtime/launch-client-gamescope.sh` for the validated session.

**Do not commit** client binaries, `data/`, Cache, or WTF account trees into git.

## Identity

| Field | Value |
|---|---|
| Build | **6.2.3.20779** (`BuildId=20779`, `VersionsName=6.2.3.20779`) |
| Locale | **enUS** (`textLocale` / `audioLocale`; connection log `locale=enUS`) |
| Agent UID | `wow_enus` |
| Primary executable | **`Wow-64-Patched-Offline.exe`** (validated live process) |
| Alternate executable | `Wow-64-Patched.exe` |
| `Wow.exe` | **Not present** in this pack |
| PE `FileVersion` | `6.2.3.20779` |
| PE `ProductVersion` | `Version 6.2.3` |
| PE `OriginalFilename` | `WoW.exe` |
| Package launch hint | `Launch WoD.bat`: `Wow-64-patched.exe -uid wow_enus` |

`versions` file (both Games and `wod/`):

```text
Region!STRING:0|BuildConfig!HEX:16|CDNConfig!HEX:16|BuildId!DEC:4|VersionsName!String:0
us|00647afeb4fe9bfc6b961a0a532a4baa|325095a916ea88d9fc0c522be7260551|20779|6.2.3.20779
… (same BuildId/VersionsName for us/xx/eu/kr/tw/cn/sg)
```

## Size and file counts

| Tree | Size | Files | Notes |
|---|---:|---:|---|
| Games pack | ~29 GiB | 408 | Includes CASC `data/` (~356 files) |
| `wod/` workspace | ~29 GiB | 444 | Extra runtime dirs (`Interface`, `GLCache`, `Account`, leftover `Firestorm.wtf`) |
| Multi-part `.7z` archive | ~28 GiB | 7 parts | Local archive only |

## SHA-256 hashes

### Client executables

| File | SHA-256 |
|---|---|
| `Wow-64-Patched.exe` | `8a67fba97eccc87585ae22833d28ff87d15fd745a71f5d143ced81892ec1175f` |
| `Wow-64-Patched-Offline.exe` | `042c7c24af68ca16bfa3010a2ee9e1355c7686bee6b5ffb2442164749fa8e50d` |

Same hashes on Games pack and `wod/`.

### Adjacent metadata (not DLLs)

| File | SHA-256 |
|---|---|
| `versions` | `34aafb764bcf09a6a3a911d2c143335ed9cf21e7c8343cc3d799317fa7405710` |
| `cdns` | `6d035334c3ef277bf4ab604f62931f8d20acc764a04e6ae363209d4971bde15a` |
| `Blizzard Entertainment.zip` | `5a7c41b16d58aa8c50049f518f9082133d83cc901eb56bbfe56dfc2d3d7327b8` |

### Client-root DLLs

**None.** This pack does not ship `dbghelp.dll` / VC runtime DLLs beside the
exe. Launch/auth dependencies come from the Wine/Proton prefix (below).

### Wine/Proton system DLLs used at launch (prefix-provided, not pack files)

Recorded from `WINEPREFIX=…/umu-default/pfx` `drive_c/windows/system32/` for
reproducibility of the validated host environment:

| File | SHA-256 |
|---|---|
| `dbghelp.dll` | `83c8dc7fa8be798c6dd419f8f9243590d3be623d365be2a7ccac0dbea5b6a9fa` |
| `msvcr120.dll` | `53d4f336e32e16a60f4ac65725c5f48a1ea7e2be790bc5f9eb61d4a1789cb3c8` |
| `msvcp120.dll` | `a37fa7c29b5d52d6c7780131154ce22c0c6d8e16458566feea0e1c2576208742` |
| `d3d11.dll` | `5703cc26657edafa38e596878eaaa54a77087816d51564d4965de6bce6abccdd` |
| `dxgi.dll` | `16d815aed670c501ebe81b25166911b0852d0cc349b426070ac0113740312809` |

### Sanitized `WTF/Config.wtf`

Secrets (`accountName`, passwords) redacted before hashing. Required portal line
confirmed present.

| Copy | Portal localhost? | SHA-256 (sanitized body) |
|---|---|---|
| `wod/WTF/Config.wtf` (validated session) | **Yes** `SET portal "localhost"` | `5f55832be79ebace44cd57258c6a9279f1ecd6512289bafd5f0a3c1eed1daba8` |
| Games pack `WTF/Config.wtf` | **Yes** `SET portal "localhost"` | `be9f36848357df08a1e6f8e2600d461ed25e84df1f8b41bb0f6ee32531f3a773` |

Sanitized required / identity lines (`wod/`):

```text
SET portal "localhost"
SET textLocale "enUS"
SET audioLocale "enUS"
SET agentUID "wow_enus"
SET accounttype "WD"
SET realmName "Banshee Realm"
```

Do not publish live `accountName` values.

## Wine prefix and ProgramData

| Item | Value |
|---|---|
| Validated Wine prefix | `/var/home/blizz/Games/umu/umu-default/pfx` |
| Compat data | `/var/home/blizz/Games/umu/umu-default` |
| Proton (live session) | **GE-Proton11-3** (umu); launch script default text may list an older GE build — prefer the live session) |
| Windows equivalent | `C:\ProgramData\Blizzard Entertainment` |
| Wine path | `$WINEPREFIX/drive_c/ProgramData/Blizzard Entertainment/` |

### Present under ProgramData (names/types only)

```text
Blizzard Entertainment/
  Battle.net/
    Cache/          # content-addressed .auth modules + cache blobs
    index
```

Installed `.auth` module basenames in the validated prefix (8 files; filenames
are content hashes — do not treat as account credentials):

```text
0a3afee2cade3a0e8b458c4b4660104cac7fc50e2ca9bef0d708942e77f15c1d.auth
2e6d53adab37a41542b38e01f62cd365eab8805ed0de73c307cc6d9d1dfe478c.auth
36b27cd911b33c61730a8b82c8b2495fd16e8024fc3b2dde08861c77a852941c.auth
5e298e530698af905e1247e51ef0b109b352ac310ce7802a1f63613db980ed17.auth
851c1d2ef926e9b9a345a460874e65517195129b9e3bdec7cc77710fa0b1fad6.auth
8c43bda10be33a32abbc09fb2279126c7f5953336391276cff588565332fcd40.auth
8f52906a2c85b416a595702251570f96d3522f39237603115f2f1ab24962043c.auth
c3a1ac0694979e709c3b5486927e558af1e2be02ca96e5615c5a65aacc829226.auth
```

Package ships the same tree as `Blizzard Entertainment.zip` for extraction into
ProgramData when bootstrapping a prefix. Also present under AppData (names only):

```text
drive_c/users/steamuser/AppData/Local/Blizzard Entertainment/System Survey/...
```

No account passwords or Battle.net login tokens are copied into this document.

## Launch command (validated)

Preferred launcher (matches live Phase 3J session):

```bash
# From repo root; defaults: Wow-64-Patched-Offline.exe, portal localhost, enUS
bash runtime/launch-client-gamescope.sh
```

Effective environment (validated session):

```bash
WINEPREFIX=/var/home/blizz/Games/umu/umu-default/pfx
STEAM_COMPAT_DATA_PATH=/var/home/blizz/Games/umu/umu-default
# Proton: GE-Proton11-3 via umu
cd /home/blizz/Projects/draenor-dit/wod
# gamescope … umu-run ./Wow-64-Patched-Offline.exe
```

Requirements:

1. `SET portal "localhost"` in `WTF/Config.wtf` (Offline-patched exe expects local NGDP).
2. Local NGDP/auth/world stack running (Draenor-Core — **not** any pack-bundled server).
3. ProgramData `Blizzard Entertainment/Battle.net/Cache` `.auth` modules present in the Wine prefix.

## Client files required vs material to ignore

### Required to run build 20779 (client)

- `Wow-64-Patched.exe` and/or `Wow-64-Patched-Offline.exe`
- CASC tree: `data/config`, `data/data`, `data/indices` (and `data/patch` if present)
- `versions`, `cdns`, `WoW.mfil` as shipped
- `WTF/Config.wtf` with `portal "localhost"` and enUS locales
- ProgramData Battle.net `.auth` cache (from zip or existing prefix)
- Optional: empty/minimal `Cache/`, `Interface/AddOns`, `Logs/`

### Do **not** use / do **not** import

- Any **repacked / leaked private-server stack** that may accompany community
  MagicStorm-style 20779 packs (worldserver/authserver binaries,
  MySQL dumps, `.sql`, realm configs, GM credentials, source trees).
- The current local multi-part `.7z` extract inspected for this baseline is a
  **client tree only** (no `worldserver` / `authserver` / `.sql` paths in the
  archive listing). Treat that as confirmation we only need the client side;
  if a fuller dump later includes a server directory, **leave it unused**.
- Firestorm `Wow-64.exe` and Firestorm-only WTF (`Firestorm.wtf`) as the
  reference client. A leftover `wod/WTF/Firestorm.wtf` may exist from earlier
  testing; it is **not** part of this baseline.
- Do not point Draenor-Core config at pack-bundled databases or binaries.

Draenor-Core remains the only server under `/home/blizz/Draenor-Core/`.

## Validation summary (Phase 3J)

Against Draenor-Core with this client:

- Login / character select: OK  
- In-game chat (`CMSG_CHAT_MESSAGE_SAY`): OK  
- Movement (`CMSG_MOVE_START_FORWARD` / turn / stop; non-stationary `MovementInfo`; position change): OK  
- NPC interaction (selection / gossip / questgiver): OK  

Details and log anchors: `docs/protocol/movement-probe-20779.md`  
(Phase 3J Clean English Client Validation + Phase 3J-B).
