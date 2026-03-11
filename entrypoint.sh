#!/bin/bash
# Clean up stale X lock files from previous runs
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99 2>/dev/null

# Start virtual display
Xvfb :99 -screen 0 1024x768x24 -nolisten tcp &
export DISPLAY=:99

# Wait for display
sleep 2

# Start socat to forward CDP port to 0.0.0.0
socat TCP-LISTEN:9223,fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:9222 &

# Start Obsidian
exec /opt/obsidian/obsidian --no-sandbox --disable-gpu --remote-debugging-port=9222 "$@"
