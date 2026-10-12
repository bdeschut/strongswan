#!/bin/sh
set -e

if [ "$#" -gt 0 ]; then
    exec "$@"
fi

# Clean up any stale PID or UNIX socket files left behind by an in-place restart
rm -f /var/run/charon.vici /var/run/charon.pid

echo "[+] Starting strongSwan charon daemon..."
/usr/libexec/ipsec/charon &
CHARON_PID=$!

# Trap signals immediately to ensure clean IKE_DELETE and socket cleanup on shutdown
cleanup() {
    echo "[+] Stopping charon..."
    kill -TERM "$CHARON_PID" 2>/dev/null || true
    wait "$CHARON_PID" 2>/dev/null || true
    rm -f /var/run/charon.vici /var/run/charon.pid
    exit 0
}
trap cleanup INT TERM

# Wait up to 15 seconds (30 * 0.5s) for charon's VICI socket to actively accept connections
MAX_RETRIES=30
COUNT=0
until swanctl --stats >/dev/null 2>&1; do
    # Fail fast if the charon process died during startup
    if ! kill -0 "$CHARON_PID" 2>/dev/null; then
        echo "[!] Error: charon exited prematurely during startup."
        exit 1
    fi

    sleep 0.5
    COUNT=$((COUNT + 1))
    if [ "$COUNT" -ge "$MAX_RETRIES" ]; then
        echo "[!] Timeout waiting for charon VICI socket (/var/run/charon.vici)"
        kill -KILL "$CHARON_PID" 2>/dev/null || true
        exit 1
    fi
done

echo "[+] charon ready. Loading swanctl configuration..."
if ! swanctl --load-all --noprompt; then
    echo "[!] Error: swanctl --load-all failed."
    kill -TERM "$CHARON_PID" 2>/dev/null || true
    exit 1
fi

# Wait for charon to exit
wait "$CHARON_PID"
