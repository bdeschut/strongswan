#!/bin/sh
set -e

# If arguments were passed to 'podman run', execute them directly (e.g. bash, sh)
if [ "$#" -gt 0 ]; then
    exec "$@"
fi

echo "[+] Starting strongSwan charon daemon..."
/usr/libexec/ipsec/charon &
CHARON_PID=$!

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
swanctl --load-all || true

trap "kill -TERM $CHARON_PID" INT TERM
wait $CHARON_PID