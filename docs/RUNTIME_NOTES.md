# Runtime Notes

These notes describe the local preservation runtime used for the WoD
6.2.3.20779 baseline.

## Host and Container

- Host: Bazzite Linux.
- Container: `draenor-devbox`.
- Source tree: `/home/blizz/Draenor-Core`.
- Runtime/support repo: `/home/blizz/Projects/draenor-dit`.

Use the container for build and server commands unless a note explicitly says a
host command is required.

## Ports

| Service | Port | Notes |
|---|---:|---|
| MariaDB | 3307 | Local DB endpoint used by the Draenor runtime. |
| authserver | 1119 | Battle.net/auth listener. |
| worldserver | 8085 | World socket listener. |
| NGDP HTTP | 80 | Local content/config bootstrap endpoint. |

Tailscale IP for remote/client-side routing tests: `100.111.220.11`.

## Client Approach

The current client target is WoD 6.2.3.20779. The local approach uses a patched
client/routing setup so the Firestorm-era client contacts the local preservation
services instead of remote production or Firestorm endpoints.

Keep patched-client changes documented and reversible. Record the exact client
build for every compatibility test.

## `.auth` Module Requirement

The client/auth flow depends on the required `.auth` module assets being present
in the expected client/runtime location. If those modules are missing, the
client may fail before meaningful realm or world protocol testing begins.

When reproducing from a fresh client directory, verify the `.auth` module setup
before debugging server-side packet behavior.

## Worldserver Launch Warning

Backgrounded `distrobox enter` or fragile detached shell jobs can close stdin or
lose the session in a way that makes `worldserver` halt immediately after
startup. If the log reaches `World initialized` and then immediately logs
`Halting process`, treat process management as the first suspect, not an opcode
crash.

Use a stable foreground terminal or a managed detached method that keeps the
worldserver session alive. Verify:

```bash
ps aux | grep "[w]orldserver"
ss -ltn | grep 8085
tail -40 /home/blizz/Draenor-Core/run-world/worldserver-live.log
```
