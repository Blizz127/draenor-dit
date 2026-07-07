#!/usr/bin/env python3
"""
WorldSocket.cpp pre-auth header fix for WoD 6.2.3 (Banshee Realm).

The client's CMSG_AUTH_SESSION packet is ~25KB (compressed addon data) which
exceeds the original 10240 byte pre-auth size limit. This patch:

1. Increases the pre-auth max packet size to 65535
2. Adds raw hex dump of the first pre-auth header bytes for debugging
3. Sets up the pre-auth branch to handle the auth session packet flexibly
"""

import sys

filepath = "/home/blizz/Draenor-Core/src/server/game/Server/WorldSocket.cpp"

with open(filepath, 'r') as f:
    content = f.read()

changes = 0

# --- FIX 1: Increase pre-auth max packet size from 10240 to 65535 ---
old_size_check = 'if ((header.size < 4) || (header.size > 10240))'
new_size_check = 'if ((header.size < 4) || (header.size > 65535))'
if old_size_check in content:
    content = content.replace(old_size_check, new_size_check)
    changes += 1
    print("FIX 1: Increased pre-auth max packet size to 65535")
else:
    print("WARN: Could not find size check to patch")

# --- FIX 2: Add raw hex dump before the size check in pre-auth branch ---
# Find the pre-auth branch (the else clause with AuthClientPktHeader)
old_preauth = """        ACE_ASSERT(m_Header.length() == sizeof(AuthClientPktHeader));
        uint8* uintHeader = (uint8*)m_Header.rd_ptr();
        AuthClientPktHeader& header = *((AuthClientPktHeader*)uintHeader);

        if ((header.size < 4) || (header.size > 65535))"""

new_preauth = """        ACE_ASSERT(m_Header.length() == sizeof(AuthClientPktHeader));
        uint8* uintHeader = (uint8*)m_Header.rd_ptr();

        // Debug: dump raw pre-auth header bytes
        sLog->outError(LOG_FILTER_NETWORKIO, "DBG pre-auth header raw bytes: %02X %02X %02X %02X %02X %02X",
            uintHeader[0], uintHeader[1], uintHeader[2], uintHeader[3], uintHeader[4], uintHeader[5]);

        AuthClientPktHeader& header = *((AuthClientPktHeader*)uintHeader);

        if ((header.size < 4) || (header.size > 65535))"""

if old_preauth in content:
    content = content.replace(old_preauth, new_preauth)
    changes += 1
    print("FIX 2: Added raw hex dump logging for pre-auth header")
else:
    print("WARN: Could not find pre-auth branch to patch (may already be modified)")

# --- FIX 3: Also log the decoded size and cmd ---
old_malformed_log = '''                header.size, header.cmd);

            errno = EINVAL;
            return -1;
        }

        header.size -= 4;'''

new_malformed_log = '''                header.size, header.cmd);

            errno = EINVAL;
            return -1;
        }

        sLog->outError(LOG_FILTER_NETWORKIO, "DBG pre-auth decoded: size=%u cmd=0x%04X (%u)",
            header.size, (uint16)header.cmd, (uint16)header.cmd);

        header.size -= 4;'''

if old_malformed_log in content:
    content = content.replace(old_malformed_log, new_malformed_log)
    changes += 1
    print("FIX 3: Added decoded header debug logging")
else:
    print("WARN: Could not find malformed log block to patch")

with open(filepath, 'w') as f:
    f.write(content)

print(f"Total changes: {changes}")
if changes == 0:
    print("ERROR: No changes applied!")
    sys.exit(1)
