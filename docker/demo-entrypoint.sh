#!/bin/sh
set -eu

: "${DB_NAME:=infolake_demo}"
: "${DB_USER:=infolake}"
: "${DB_PASSWORD:?DB_PASSWORD must be set}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD must be set}"
: "${SECRET_KEY:?SECRET_KEY must be set}"
: "${DEMO_AUTO_LOGIN_USERNAME:=demo}"
: "${DEMO_AUTO_LOGIN_PASSWORD:?DEMO_AUTO_LOGIN_PASSWORD must be set}"

export DB_NAME DB_USER DB_PASSWORD SECRET_KEY DEMO_AUTO_LOGIN_USERNAME DEMO_AUTO_LOGIN_PASSWORD
export DB_HOST=127.0.0.1 DB_PORT=5432
export DEBUG=False DEMO_AUTO_LOGIN_ENABLED=True
export FRONTEND_URL="${FRONTEND_URL:-http://localhost:8080}"
export ALLOWED_HOSTS="${ALLOWED_HOSTS:-localhost,127.0.0.1,infolake-demo}"
export CORS_ALLOWED_ORIGINS="${CORS_ALLOWED_ORIGINS:-$FRONTEND_URL}"
export CORS_ALLOW_ALL_ORIGINS=False
export DEM_DATA_DIR="${DEM_DATA_DIR:-/app/dem_data/glo-90}"

PG_BIN=/usr/lib/postgresql/17/bin

postgres_is_running() {
    runuser -u postgres -- "$PG_BIN/pg_ctl" -D "$PGDATA" status >/dev/null 2>&1
}

remove_stale_postgres_lock() {
    if [ -f "$PGDATA/postmaster.pid" ] && ! postgres_is_running; then
        echo "Removing stale PostgreSQL lock file"
        rm -f "$PGDATA/postmaster.pid"
    fi
}

start_postgres() {
    listen="${1:-127.0.0.1}"
    if postgres_is_running; then
        return 0
    fi
    remove_stale_postgres_lock
    echo "Starting PostgreSQL (listen_addresses=$listen)"
    runuser -u postgres -- "$PG_BIN/pg_ctl" -D "$PGDATA" -o "-c listen_addresses=$listen" -w start
}

stop_postgres() {
    if postgres_is_running; then
        runuser -u postgres -- "$PG_BIN/pg_ctl" -D "$PGDATA" -m fast -w stop
    fi
}

if [ ! -r /data/data/map.mbtiles ]; then
    echo "Required map file is unavailable: /data/data/map.mbtiles" >&2
    exit 1
fi

if [ ! -s "$PGDATA/PG_VERSION" ]; then
    echo "Initializing demonstration PostgreSQL cluster"
    pwfile=$(mktemp)
    trap 'rm -f "$pwfile"' EXIT
    printf '%s' "$POSTGRES_PASSWORD" > "$pwfile"
    chown postgres:postgres "$PGDATA" "$pwfile"
    chmod 600 "$pwfile"
    runuser -u postgres -- "$PG_BIN/initdb" \
        -D "$PGDATA" \
        --username=postgres \
        --pwfile="$pwfile" \
        --auth-host=scram-sha-256 \
        --encoding=UTF8 \
        --locale=C.UTF-8
    rm -f "$pwfile"
    trap - EXIT
    start_postgres 127.0.0.1
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h 127.0.0.1 -U postgres -d postgres -v ON_ERROR_STOP=1 \
        -v db_user="$DB_USER" -v db_password="$DB_PASSWORD" -v db_name="$DB_NAME" <<'SQL'
CREATE ROLE :"db_user" LOGIN PASSWORD :'db_password';
CREATE DATABASE :"db_name"
    OWNER :"db_user"
    ENCODING 'UTF8'
    LC_COLLATE 'C.UTF-8'
    LC_CTYPE 'C.UTF-8'
    TEMPLATE template0;
SQL
    stop_postgres
fi

# Host clients of 127.0.0.1:55432 are NATed by Docker and arrive as the
# bridge gateway (for example 172.18.0.1), not as loopback. initdb only
# allows 127.0.0.1/32. Neighbours on the Compose network have the same need.
# SCRAM remains required; Compose still publishes 5432 on loopback only.
hba_file="$PGDATA/pg_hba.conf"
hba_marker="# infolake-demo: docker published ports and integration network"
if [ -f "$hba_file" ] && ! grep -qF "$hba_marker" "$hba_file"; then
    printf '\n%s\nhost all all all scram-sha-256\n' "$hba_marker" >> "$hba_file"
fi

if [ "${DEMO_MAINTENANCE:-0}" = "1" ]; then
    echo "Maintenance mode: PostgreSQL only; migrations, seed and HTTP services are disabled."
    remove_stale_postgres_lock
    exec runuser -u postgres -- "$PG_BIN/postgres" -D "$PGDATA" -c listen_addresses=0.0.0.0
fi

start_postgres 127.0.0.1
cd /app
python manage.py migrate --noinput
python manage.py collectstatic --noinput
python manage.py provision_demo_user

if [ "${DEMO_SEED:-0}" = "1" ]; then
    python manage.py seed_demo_showcases
fi

stop_postgres
exec supervisord -c /etc/supervisord.conf
