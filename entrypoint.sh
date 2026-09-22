#!/bin/sh
set -e

echo "[+] Starting strongSwan charon daemon..."
/usr/libexec/ipsec/charon &
CHARON_PID=$!

# Wait for VICI IPC socket to become available
MAX_RETRIES=20
COUNT=0
while [ ! -S /var/run/charon.vici ]; do
    sleep 0.2
    COUNT=$((COUNT + 1))
    if [ "$COUNT" -ge "$MAX_RETRIES" ]; then
        echo "[!] Timeout waiting for /var/run/charon.vici"
        exit 1
    fi
done

echo "[+] charon started. Loading swanctl configuration..."
swanctl --load-all || echo "[!] Notice: swanctl --load-all returned warnings."

# Trap termination signals to gracefully stop charon
trap "kill -TERM $CHARON_PID" INT TERM

wait $CHARON_PID