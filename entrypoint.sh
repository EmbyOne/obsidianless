#!/bin/bash
set -e

# Clean up stale X lock files from previous runs
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99 2>/dev/null

# Start virtual display
Xvfb :99 -screen 0 1024x768x24 -nolisten tcp &
export DISPLAY=:99

# Wait for display to be ready
for i in $(seq 1 10); do
    if xdpyinfo -display :99 >/dev/null 2>&1; then
        break
    fi
    if [ "$i" -eq 10 ]; then
        echo "ERROR: Xvfb failed to start after 10 attempts" >&2
        exit 1
    fi
    sleep 0.5
done

# Optionally start socat to forward CDP port to 0.0.0.0
if [ "${ENABLE_CDP:-false}" = "true" ]; then
    socat TCP-LISTEN:9223,fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:9222 &
    echo "CDP forwarding enabled on port 9223"
fi

# Start Obsidian
exec /opt/obsidian/obsidian --no-sandbox --disable-gpu --remote-debugging-port=9222 "$@"
