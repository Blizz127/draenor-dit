#!/usr/bin/env python3
"""Minimal DNS server for the Draenor-Core WoD server.

Resolves *.fstorm.cc (and bare fstorm.cc) to the server IP so that the
Firestorm WoD client can find logon.fstorm.cc, logon-cdn.fstorm.cc,
us-cdn.fstorm.cc, eu-cdn.fstorm.cc without a hosts file entry.

All other queries are forwarded to an upstream resolver (default 1.1.1.1)
so that a remote client using this as its sole DNS server still gets
normal internet name resolution.

Listens on UDP port 53 on the Tailscale IP by default.  Port 53 is a
privileged port, so either run as root or lower
net.ipv4.ip_unprivileged_port_start to <= 53 (setup-client-connect.sh
does this).

Environment variables:
  DRAENOR_SERVER_IP — IP to return for *.fstorm.cc (default 100.111.220.11)
  DRAENOR_IP        — legacy alias for DRAENOR_SERVER_IP
  UPSTREAM_DNS      — forwarder for non-fstorm.cc  (default 1.1.1.1)
  DNS_BIND          — address to bind on           (default DRAENOR_SERVER_IP)
  DNS_PORT          — port                          (default 53)
  DNS_TTL           — TTL for fstorm.cc records     (default 60)
"""
import os, socket, struct, sys, select, time

SERVER_IP   = os.environ.get("DRAENOR_SERVER_IP", os.environ.get("DRAENOR_IP", "100.111.220.11"))
UPSTREAM    = os.environ.get("UPSTREAM_DNS",  "1.1.1.1")
BIND_ADDR   = os.environ.get("DNS_BIND",      SERVER_IP)
DNS_PORT    = int(os.environ.get("DNS_PORT",  "53"))
TTL         = int(os.environ.get("DNS_TTL",   "60"))

# DNS QTYPE constants
QTYPE_A     = 1
QTYPE_AAAA  = 28
QTYPE_CNAME = 5
QTYPE_NS    = 2
QTYPE_PTR   = 12
QTYPE_MX    = 15
QTYPE_TXT   = 16
QTYPE_SRV   = 33
QTYPE_SOA   = 6

# DNS RCODEs
RCODE_NOERROR = 0
RCODE_NXDOMAIN = 3

def parse_qname(data, offset):
    """Parse a DNS QNAME (sequence of length-prefixed labels) from *offset*.
    Returns (name_string, next_offset)."""
    labels = []
    jumped = False
    orig_offset = offset
    while True:
        if offset >= len(data):
            break
        length = data[offset]
        if length == 0:
            offset += 1
            break
        if length & 0xC0 == 0xC0:          # compression pointer
            if offset + 1 >= len(data):
                break
            pointer = struct.unpack("!H", data[offset:offset + 2])[0] & 0x3FFF
            sub_name, _ = parse_qname(data, pointer)
            labels.append(sub_name)
            offset += 2
            jumped = True
            break
        offset += 1
        labels.append(data[offset:offset + length].decode("ascii", errors = "replace"))
        offset += length
    return ".".join(filter(None, labels)), offset


def build_a_response(query, ip_addr, rcode=RCODE_NOERROR):
    """Build a DNS response to *query* with a single A record."""
    qid = query[0:2]
    # Flags: QR=1, Opcode=0, AA=0, TC=0, RD=1(copy), RA=1, Z=0, RCODE
    rd = struct.unpack("!H", query[2:4])[0] & 0x0100      # preserve RD bit
    flags = 0x8000 | 0x0080 | rd | rcode                    # QR + RA + RD + RCODE
    header = qid + struct.pack("!HHHHH", flags, 1, 1 if rcode == RCODE_NOERROR else 0, 0, 0)

    # Copy the question section (QNAME + QTYPE + QCLASS)
    qname_end = 12
    offset = 12
    while offset < len(query) and query[offset] != 0:
        if query[offset] & 0xC0 == 0xC0:
            offset += 2
            break
        offset += query[offset] + 1
    else:
        offset += 1
    question = query[12:offset + 4]

    if rcode != RCODE_NOERROR:
        return header + question

    # Answer: pointer to QNAME at offset 12, type A, class IN
    answer = (
        struct.pack("!H", 0xC00C)          # name pointer to offset 12
        + struct.pack("!HH", QTYPE_A, 1)   # type A, class IN
        + struct.pack("!I", TTL)           # TTL
        + struct.pack("!H", 4)             # RDLENGTH
        + socket.inet_aton(ip_addr)        # RDATA
    )
    return header + question + answer


def build_empty_response(query, rcode=RCODE_NOERROR):
    """Build a DNS response with no answer records (NOERROR or NXDOMAIN)."""
    qid = query[0:2]
    rd = struct.unpack("!H", query[2:4])[0] & 0x0100
    flags = 0x8000 | 0x0080 | rd | rcode
    header = qid + struct.pack("!HHHHH", flags, 1, 0, 0, 0)

    qname_end = 12
    offset = 12
    while offset < len(query) and query[offset] != 0:
        if query[offset] & 0xC0 == 0xC0:
            offset += 2
            break
        offset += query[offset] + 1
    else:
        offset += 1
    question = query[12:offset + 4]
    return header + question


def forward_query(query, upstream, timeout=3):
    """Forward *query* to *upstream* DNS and return the raw response."""
    fwd = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    fwd.settimeout(timeout)
    try:
        fwd.sendto(query, (upstream, 53))
        response, _ = fwd.recvfrom(4096)
        return response
    except (socket.timeout, OSError):
        return None
    finally:
        fwd.close()


def handle_udp(query, addr, sock):
    """Handle a single UDP DNS query."""
    if len(query) < 17:                     # 12 header + min 1 QNAME + 4 QTYPE/QCLASS
        return
    try:
        qname, qend = parse_qname(query, 12)
        qname_lower = qname.lower().rstrip(".")
        qtype = struct.unpack("!H", query[qend:qend + 2])[0] if qend + 2 <= len(query) else 0
    except Exception:
        return

    is_fstorm = qname_lower == "fstorm.cc" or qname_lower.endswith(".fstorm.cc")

    if is_fstorm:
        if qtype == QTYPE_A:
            response = build_a_response(query, SERVER_IP)
            sock.sendto(response, addr)
            log(f"RESOLVE {qname} A -> {SERVER_IP}")
        else:
            # fstorm.cc exists but has no records of this type
            response = build_empty_response(query, RCODE_NOERROR)
            sock.sendto(response, addr)
            log(f"RESOLVE {qname} {qtype} -> NODATA (fstorm.cc)")
    else:
        # Forward to upstream
        response = forward_query(query, UPSTREAM)
        if response:
            sock.sendto(response, addr)
            log(f"FORWARD  {qname} {qtype} -> upstream")
        else:
            # Upstream timeout — return SERVFAIL
            response = build_empty_response(query, 2)  # RCODE=2 SERVFAIL
            sock.sendto(response, addr)
            log(f"SERVFAIL {qname} {qtype} (upstream timeout)")


def log(msg):
    print(f"DNS  {msg}", flush=True)


def main():
    udp_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    udp_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        udp_sock.bind((BIND_ADDR, DNS_PORT))
    except PermissionError:
        print(f"ERROR: cannot bind {BIND_ADDR}:{DNS_PORT} — permission denied.\n"
              f"Run as root or: sudo sysctl -w net.ipv4.ip_unprivileged_port_start=53",
              file=sys.stderr)
        sys.exit(1)
    except OSError as e:
        print(f"ERROR: cannot bind {BIND_ADDR}:{DNS_PORT} — {e}", file=sys.stderr)
        sys.exit(1)

    print(f"DNS server: {BIND_ADDR}:{DNS_PORT}  (*.fstorm.cc -> {SERVER_IP}, "
          f"upstream {UPSTREAM})", flush=True)

    while True:
        try:
            data, addr = udp_sock.recvfrom(4096)
            handle_udp(data, addr, udp_sock)
        except Exception as e:
            print(f"DNS error: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
