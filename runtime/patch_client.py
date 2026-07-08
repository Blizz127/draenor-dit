#!/usr/bin/env python3
"""patch_client.py — Patch the Firestorm WoD 6.2.3 client (Wow-64.exe) to connect
directly to a server IP, eliminating the need for DNS, hosts file entries, or
any network-level redirect.

What it patches (3 string literals in the .rdata section):
  1. "http://%s-cdn.fstorm.cc/%s/versions"  ->  "http://<IP>/%s/versions"
  2. "http://%s-cdn.fstorm.cc/%s/cdns"      ->  "http://<IP>/%s/cdns"
  3. ".fstorm.cc"  (bnet host suffix)       ->  null-padded (so bnet host = portal value)

After patching, set  SET portal "<IP>"  in WTF/Config.wtf  and the client connects
directly to <IP> for NGDP (port 80), bnet auth (port 1119), and the world server
(port 8085, from the realmlist).

The WOPCore binary patches (BNet/Send/Signature) are NOT applied here — the
Firestorm exe is already patched (verified by searching for the patch bytes).

Usage:
  python3 patch_client.py [exe_path] [server_ip]

  exe_path   — path to Wow-64.exe (default: /var/home/blizz/Projects/draenor-dit/wod/Wow-64.exe)
  server_ip  — IP to redirect to  (default: $DRAENOR_SERVER_IP or 100.111.220.11)

The patcher creates a backup (<exe>.bak) before patching, and writes the patched
exe to <exe> (in-place). It also updates WTF/Config.wtf if found alongside the exe.
"""
import os
import sys
import shutil
import struct


def find_all(data, needle):
    """Return list of all offsets where *needle* appears in *data*."""
    offsets = []
    pos = 0
    while True:
        idx = data.find(needle, pos)
        if idx == -1:
            break
        offsets.append(idx)
        pos = idx + 1
    return offsets


def patch_string(data, old, new):
    """Replace all occurrences of *old* (bytes) with *new* (bytes, null-padded
    to the same length as *old*).  Returns (patched_data, count)."""
    if len(new) > len(old):
        raise ValueError(f"Replacement ({len(new)} bytes) is longer than original ({len(old)} bytes)")

    # Null-pad to match original length
    padded_new = new + b'\x00' * (len(old) - len(new))

    count = 0
    result = bytearray(data)
    for offset in find_all(data, old):
        result[offset:offset + len(old)] = padded_new
        count += 1

    return bytes(result), count


def update_config_wtf(exe_path, server_ip):
    """Update WTF/Config.wtf (and Firestorm.wtf) alongside the exe."""
    wod_dir = os.path.dirname(exe_path)
    wtf_dir = os.path.join(wod_dir, "WTF")

    for wtf_name in ["Config.wtf", "Firestorm.wtf"]:
        wtf_path = os.path.join(wtf_dir, wtf_name)
        if not os.path.isfile(wtf_path):
            continue

        with open(wtf_path, "r", errors="replace") as f:
            lines = f.readlines()

        changed = False
        portal_found = False
        new_lines = []
        for line in lines:
            stripped = line.strip()
            if stripped.startswith("SET portal"):
                new_lines.append(f'SET portal "{server_ip}"\n')
                portal_found = True
                changed = True
            elif stripped.startswith("SET realmList"):
                new_lines.append(f'SET realmList "{server_ip}"\n')
                changed = True
            else:
                new_lines.append(line)

        # If no portal line exists, add one
        if not portal_found:
            new_lines.append(f'SET portal "{server_ip}"\n')
            changed = True

        if changed:
            with open(wtf_path, "w") as f:
                f.writelines(new_lines)
            print(f"  Updated {wtf_path}: portal={server_ip}")
        else:
            print(f"  {wtf_path}: already configured")


def main():
    default_exe = "/var/home/blizz/Projects/draenor-dit/wod/Wow-64.exe"
    default_ip = os.environ.get("DRAENOR_SERVER_IP", "100.111.220.11")

    exe_path = sys.argv[1] if len(sys.argv) > 1 else default_exe
    server_ip = sys.argv[2] if len(sys.argv) > 2 else default_ip

    if not os.path.isfile(exe_path):
        print(f"ERROR: exe not found: {exe_path}", file=sys.stderr)
        sys.exit(1)

    print(f"Client patcher")
    print(f"  Exe:       {exe_path}")
    print(f"  Server IP: {server_ip}")
    print()

    # Read the exe
    with open(exe_path, "rb") as f:
        data = f.read()
    print(f"  Exe size:  {len(data):,} bytes")

    # --- Verify the exe is a Firestorm client (has fstorm.cc strings) ---
    if b"fstorm.cc" not in data:
        print("ERROR: This exe does not contain 'fstorm.cc' strings.")
        print("       It may not be a Firestorm client, or it's already patched.", file=sys.stderr)
        sys.exit(1)

    # --- Patch 1: NGDP versions URL ---
    old_versions = b"http://%s-cdn.fstorm.cc/%s/versions"
    new_versions = f"http://{server_ip}/%s/versions".encode()
    data, n_versions = patch_string(data, old_versions, new_versions)
    print(f"  [1] NGDP versions URL: {n_versions} occurrence(s) patched")
    print(f"      '{old_versions.decode()}' -> '{new_versions.decode()}'")

    # --- Patch 2: NGDP cdns URL ---
    old_cdns = b"http://%s-cdn.fstorm.cc/%s/cdns"
    new_cdns = f"http://{server_ip}/%s/cdns".encode()
    data, n_cdns = patch_string(data, old_cdns, new_cdns)
    print(f"  [2] NGDP cdns URL: {n_cdns} occurrence(s) patched")
    print(f"      '{old_cdns.decode()}' -> '{new_cdns.decode()}'")

    # --- Patch 3: bnet host suffix (.fstorm.cc -> null) ---
    # This must come AFTER the URL patches (otherwise it would corrupt them).
    # By now the URL strings no longer contain "fstorm.cc".
    old_suffix = b".fstorm.cc"
    new_suffix = b""  # empty = just null-pad
    data, n_suffix = patch_string(data, old_suffix, new_suffix)
    print(f"  [3] bnet host suffix '.fstorm.cc': {n_suffix} occurrence(s) nulled")
    print(f"      (bnet host will be just the portal value: {server_ip})")

    # --- Verify no fstorm.cc remains ---
    remaining = data.count(b"fstorm.cc")
    if remaining > 0:
        print(f"\n  WARNING: {remaining} 'fstorm.cc' string(s) still remain in the binary!")
        print(f"           These may be in other strings not covered by this patcher.")
    else:
        print(f"\n  All 'fstorm.cc' strings eliminated.")

    # --- Make backup and write patched exe ---
    backup_path = exe_path + ".bak"
    if not os.path.exists(backup_path):
        shutil.copy2(exe_path, backup_path)
        print(f"\n  Backup: {backup_path}")
    else:
        print(f"\n  Backup already exists: {backup_path}")

    with open(exe_path, "wb") as f:
        f.write(data)
    print(f"  Patched exe written: {exe_path}")

    # --- Update Config.wtf ---
    print(f"\n  Updating WTF config files...")
    update_config_wtf(exe_path, server_ip)

    print(f"\nDONE. The client now connects directly to {server_ip}.")
    print(f"  Required server-side services:")
    print(f"    - NGDP HTTP on :80  (serve.py)")
    print(f"    - authserver   on :1119")
    print(f"    - worldserver  on :8085")
    print(f"  No DNS, hosts file, or socat needed.")


if __name__ == "__main__":
    main()
