# Remote Windows Client Setup

This note is for connecting a native Windows WoD 6.2.3.20779 client to the
local Draenor-Core preservation server over Tailscale. Native Windows input is
useful for separating Wine/Wayland input problems from server-side protocol
problems.

## Server Details

- Default Tailscale IP for this local setup: `100.111.220.11`
- Realm: `Banshee Realm`
- Client build: WoD 6.2.3.20779

Do not commit real account passwords. Use a local test account created through
the worldserver console or another documented local account source.

## Patched Client Approach

The helper `runtime/patch_client.py` patches Firestorm client string literals so
the client can connect directly to a server IP:

1. NGDP versions URL -> `http://<server-ip>/%s/versions`
2. NGDP cdns URL -> `http://<server-ip>/%s/cdns`
3. bnet host suffix `.fstorm.cc` -> nulled out, so the bnet host is the portal
   value

The default server IP is `100.111.220.11`, but every script should also work with
another IP by setting `DRAENOR_SERVER_IP` or passing the IP explicitly where the
script supports it.

## Windows Prerequisites

1. Install Tailscale and join the same tailnet as the server.
2. Use a WoD 6.2.3.20779 client directory. Do not commit the client directory or
   copied binaries to this repo.
3. Make sure outbound Windows Firewall rules allow the server IP on ports `80`,
   `1119`, and `8085`.

## `.auth` Modules

The Battle.net `.auth` modules are required for the client auth flow. They are
private/local binary artifacts and are intentionally ignored by git:

- `runtime/bnet-auth-modules/`
- `runtime/bnet-auth-modules.zip`

If you have a local `bnet-auth-modules.zip`, copy it to the Windows machine and
extract it to:

```text
C:\ProgramData\Blizzard Entertainment\Battle.net\Cache\
```

Preserve the directory structure inside the zip. If retail Battle.net is
installed, its cache may contain different modules; use a clean cache directory
for this preservation client.

## Patching a Fresh Client

From the host repo:

```bash
python3 runtime/patch_client.py /path/to/Wow-64.exe 100.111.220.11
```

Or with another IP:

```bash
DRAENOR_SERVER_IP=<server-ip> python3 runtime/patch_client.py /path/to/Wow-64.exe
```

The patcher creates `<exe>.bak`, patches in place, and updates `WTF/Config.wtf`
or `WTF/Firestorm.wtf` if present.

## Launch Helpers

- `runtime/launch-wow.bat`: launch `Wow-64.exe` and kill lingering client
  processes on exit.
- `runtime/kill-wow.bat`: force-kill a stuck client.
- `runtime/setup-launcher-windows.bat`: create a local `Cache\` directory from a
  locally provided `bnet-auth-modules.zip`.
- `runtime/launch-wow-windows.bat`: temporarily point the Windows Battle.net
  cache registry value at the local `Cache\` directory while launching.

## Movement Discriminator

Once in world with the character and 3D scene visible, run the controlled matrix
from `docs/TEST_MATRIX_MOVEMENT_20779.md`.

Key checks:

1. Left-click a guard or NPC.
2. Right-click and drag for camera/facing.
3. Press and hold W.
4. Release W.
5. Jump once.

Interpretation:

| Result | Diagnosis |
|---|---|
| Windows input works but Wine input does not | Wine/Wayland/input-layer issue |
| Movement is still broken on Windows | server-side protocol issue remains likely |
| Camera/target works but movement does not | partial client control; movement opcode mapping still suspect |

Do not add opcode aliases from this test unless the server log contains
action-correlated unknown-opcode evidence.
