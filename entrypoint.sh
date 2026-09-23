#!/bin/sh
set -e

if [ "$#" -gt 0 ]; then
    exec "$@"
fi

echo "[+] Starting strongSwan charon daemon..."
/usr/libexec/ipsec/charon &
CHARON_PID=$!

# Trap signals immediately to ensure clean IKE_DELETE on shutdown
trap 'echo "[+] Stopping charon..."; kill -TERM "$CHARON_PID"; wait "$CHARON_PID"' INT TERM

# Allow up to 15 seconds for socket creation on slower Pi storage
MAX_RETRIES=75
COUNT=0
while [ ! -S /var/run/charon.vici ]; do
    sleep 0.2
    COUNT=$((COUNT + 1))
    if [ "$COUNT" -ge "$MAX_RETRIES" ]; then
        echo "[!] Timeout waiting for /var/run/charon.vici"
        kill -KILL "$CHARON_PID" 2>/dev/null || true
        exit 1
    fi
done

echo "[+] charon ready. Loading swanctl configuration..."
if ! swanctl --load-all; then
    echo "[!] Warning: swanctl --load-all encountered errors during initial boot."
fi

# Wait for Charon to exit
wait "$CHARON_PID"
