#!/usr/bin/env bash
# setup-client-connect.sh — the PRIVILEGED half of pointing the Firestorm WoD
# client at the local Draenor-Core server. Run once per boot: sudo bash <this>
#
# What it does (and why):
#  1. /etc/hosts: the client builds its bnet login host as "<portal>.fstorm.cc"
#     and its NGDP versions host as "<portal>-cdn.fstorm.cc". With portal="logon"
#     that is logon.fstorm.cc + logon-cdn.fstorm.cc — redirect both to loopback.
#  2. lower the unprivileged-port floor so the local NGDP server (:80) and the
#     bnet port-forward (:87) can bind as your normal user (client uses those ports).
set -euo pipefail

HOSTS_MARK="# draenor-dit local WoD server"
if ! grep -q "$HOSTS_MARK" /etc/hosts; then
  cat >> /etc/hosts <<EOF

$HOSTS_MARK
127.0.0.1 logon.fstorm.cc
127.0.0.1 logon-cdn.fstorm.cc
127.0.0.1 us-cdn.fstorm.cc
127.0.0.1 eu-cdn.fstorm.cc
EOF
  echo "/etc/hosts: added logon/logon-cdn.fstorm.cc -> 127.0.0.1"
else
  echo "/etc/hosts: already has the draenor-dit entries"
fi

sysctl -w net.ipv4.ip_unprivileged_port_start=80
echo "port floor lowered to 80 (lets NGDP:80 and socat:87 bind as your user)"
echo "DONE. Now tell Claude to start the NGDP server + launch the client."
