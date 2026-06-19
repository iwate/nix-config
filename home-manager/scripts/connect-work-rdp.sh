#!/usr/bin/env bash

PASS=$(op read op://Private/RDP/password)
HOST=$(op read op://Private/RDP/host)
USER=$(op read op://Private/RDP/username)
DOMAIN=$(op read op://Private/RDP/domain)
GW=$(op read op://Private/RDP/gateway)

DISPLAY=:0 setxkbmap jp

echo "$PASS" | DISPLAY=:0 xfreerdp /from-stdin \
/v:"$HOST" \
/u:"$USER" \
/d:"$DOMAIN" \
/gateway:g:"$GW" \
/f /kbd:layout:Japanese /kbd:remap:0x3a=0x64 /scale:140
