#!/bin/sh
set -eu

# Do not expose the SPA until TileServer has loaded its local configuration.
# This prevents a transient 502 for style.json immediately after startup.
attempt=0
until wget -q -O /dev/null http://127.0.0.1:8080/styles/infolake-unified/style.json; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 120 ]; then
        echo "TileServer did not become ready within 120 seconds" >&2
        exit 1
    fi
    sleep 1
done

exec /usr/sbin/nginx -g 'daemon off;'
