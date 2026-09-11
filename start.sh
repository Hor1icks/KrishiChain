#!/usr/bin/env bash
set -uo pipefail

export MSYS_NO_PATHCONV=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER=krishichain-oracle
LOGS="$ROOT/logs"
API_PORT=5000
UI_PORT=5173

REBUILD=0
SKIP_DB=0
for arg in "$@"; do
  case "$arg" in
    --rebuild) REBUILD=1 ;;
    --no-db)   SKIP_DB=1 ;;
    -h|--help) cat <<'USAGE'
Start the whole system: Oracle XE, the API and the front end.

  ./start.sh              start everything
  ./start.sh --rebuild    drop and rebuild the schema first, then start
  ./start.sh --no-db      skip the container (Oracle already running elsewhere)
USAGE
      exit 0 ;;
    *) echo "Unknown option: $arg  (try --help)" >&2; exit 1 ;;
  esac
done

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\n\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

port_busy() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

if command -v curl >/dev/null; then
  api_up() { curl -sf "http://localhost:$API_PORT/api/health" >/dev/null 2>&1; }
else
  api_up() { port_busy "$API_PORT"; }
fi

if [ ! -f "$ROOT/server/.env" ]; then
  say "Creating server/.env from the example"
  cp "$ROOT/server/.env.example" "$ROOT/server/.env"
  echo "Edit server/.env and set ORACLE_CLIENT_DIR to your Instant Client"
  echo "directory, then run this script again."
  exit 1
fi

CLIENT_DIR=$(grep -E '^ORACLE_CLIENT_DIR=' "$ROOT/server/.env" | head -1 | cut -d= -f2- | tr -d '"'"'"'' | tr -d '\r')
[ -n "$CLIENT_DIR" ] || fail "ORACLE_CLIENT_DIR is not set in server/.env"
[ -d "$CLIENT_DIR" ] || fail "ORACLE_CLIENT_DIR points at a directory that does not exist: $CLIENT_DIR"
export LD_LIBRARY_PATH="$CLIENT_DIR:${LD_LIBRARY_PATH:-}"

if [ "$SKIP_DB" -eq 0 ]; then
  command -v docker >/dev/null || fail "docker is not installed, or use --no-db"

  if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
      say "Starting Oracle XE"
      docker start "$CONTAINER" >/dev/null || fail "Could not start $CONTAINER"
    else
      [ -f "$ROOT/Dockerfile" ] || fail "No container named '$CONTAINER', and no Dockerfile to build one from. Create the container first, or use --no-db."
      say "No '$CONTAINER' container yet — building it from Dockerfile"
      echo "First boot builds the whole schema and seeds it; this takes a few minutes."
      (cd "$ROOT" && docker build -t krishichain-oracle .) ||
        fail "docker build failed. Full output above."
      docker run -d --name "$CONTAINER" -p 1521:1521 \
        -e ORACLE_PASSWORD=OracleDemo2026 -e NLS_LANG=.AL32UTF8 \
        -v krishichain-oradata:/u01/app/oracle/oradata \
        krishichain-oracle >/dev/null ||
        fail "docker run failed to start $CONTAINER."
    fi
  fi

  printf 'Waiting for the database'
  ready=0
  for _ in $(seq 1 150); do
    if "$ROOT/db.sh" -q "SELECT 'up' FROM dual" 2>/dev/null | grep -q '^up$'; then
      ready=1; break
    fi
    printf '.'; sleep 2
  done
  echo
  [ "$ready" -eq 1 ] || fail "The database did not come up. Check: docker logs $CONTAINER"
fi

if [ "$REBUILD" -eq 1 ]; then
  say "Rebuilding the schema (this wipes all data)"
  for f in 00_reset 01_create_tables 01_schema_automation 02_trigger_layer 02_business_rules 03_insert_data \
           04_views 05_plsql_layer; do
    [ -f "$ROOT/database/$f.sql" ] || continue
    echo "  $f.sql"
    out=$("$ROOT/db.sh" "$ROOT/database/$f.sql" 2>&1)
    if [ "$f" != "00_reset" ] && grep -qE '^(ORA-|PLS-|SP2-)' <<<"$out"; then
      echo "$out" | grep -E '^(ORA-|PLS-|SP2-)' | head -5
      fail "$f.sql reported errors. Run it on its own with ./db.sh to see them all."
    fi
  done
fi

# Existing Docker volumes are not re-initialized when the image changes.
# Apply versioned database objects so an older local volume can run the new
# service queries without forcing a destructive --rebuild. Trigger migration
# changes trigger objects only and never resets application data.
if [ "$SKIP_DB" -eq 0 ] && [ "$REBUILD" -eq 0 ]; then
  update4_column_count=$(
    "$ROOT/db.sh" -q \
      "SELECT 'U4COL=' || COUNT(*) FROM user_tab_columns WHERE table_name = 'STORAGE_UNIT' AND column_name = 'LOCATIONTAG'" \
      2>/dev/null | sed -n 's/^U4COL=//p' | tail -1
  )
  update4_migrated=0
  if [ "$update4_column_count" = "0" ]; then
    say "Migrating the existing database to Update 4 (no rows are deleted)"
    out=$("$ROOT/db.sh" "$ROOT/database/09_update4_migration.sql" 2>&1)
    if grep -qE '^(ORA-|PLS-|SP2-)' <<<"$out"; then
      echo "$out" | grep -E '^(ORA-|PLS-|SP2-)' | head -5
      fail "Update-4 migration reported errors. Review the output before running it again."
    fi
    update4_migrated=1
  fi

  automation_count=$(
    "$ROOT/db.sh" -q \
      "SELECT 'U3AUTO=' || COUNT(*) FROM user_objects WHERE (object_type = 'SEQUENCE' AND object_name LIKE 'SEQ\_%\_ID' ESCAPE '\\') OR (object_type = 'INDEX' AND object_name LIKE 'IX\_%' ESCAPE '\\')" \
      2>/dev/null | sed -n 's/^U3AUTO=//p' | tail -1
  )

  case "$automation_count" in
    0)
      say "Adding Update-3 sequences and indexes"
      out=$("$ROOT/db.sh" "$ROOT/database/01_schema_automation.sql" 2>&1)
      if grep -qE '^(ORA-|PLS-|SP2-)' <<<"$out"; then
        echo "$out" | grep -E '^(ORA-|PLS-|SP2-)' | head -5
        fail "Update-3 schema automation reported errors. No data was reset."
      fi
      ;;
    47)
      say "Adding Update-4 indexes"
      out=$("$ROOT/db.sh" "$ROOT/database/09_update4_indexes.sql" 2>&1)
      if grep -qE '^(ORA-|PLS-|SP2-)' <<<"$out"; then
        echo "$out" | grep -E '^(ORA-|PLS-|SP2-)' | head -5
        fail "Update-4 indexes reported errors."
      fi
      ;;
    49) ;;
    *)
      fail "Schema automation is incomplete ($automation_count of 49 objects). Run ./start.sh --rebuild only if wiping local data is acceptable."
      ;;
  esac

  trigger_layer_count=$(
    "$ROOT/db.sh" -q \
      "SELECT 'TRIGGERSET=' || COUNT(*) FROM user_objects WHERE object_type = 'TRIGGER' AND status = 'VALID' AND object_name IN ('TRG_USERS_PREPARE','TRG_BATCH_LISTING_GUARD','TRG_BID_GUARD','TRG_STORES_STATUS_GUARD','TRG_TRANSPORT_STATUS_GUARD','TRG_REVIEW_GUARD','TRG_BID_NOTIFICATION','TRG_TRANSPORT_NOTIFICATION','TRG_FARM_VERIFY_NOTIFICATION')" \
      2>/dev/null | sed -n 's/^TRIGGERSET=//p' | tail -1
  )
  legacy_trigger_count=$(
    "$ROOT/db.sh" -q \
      "SELECT 'LEGACYTRIG=' || COUNT(*) FROM user_triggers WHERE trigger_name LIKE 'TRG\_%\_ID' ESCAPE '\\'" \
      2>/dev/null | sed -n 's/^LEGACYTRIG=//p' | tail -1
  )

  if [ "$trigger_layer_count" != "9" ] || [ "$legacy_trigger_count" != "0" ]; then
    say "Installing the 9-trigger business and notification layer"
    out=$("$ROOT/db.sh" "$ROOT/database/02_trigger_layer.sql" 2>&1)
    if grep -qE '^(ORA-|PLS-|SP2-)' <<<"$out"; then
      echo "$out" | grep -E '^(ORA-|PLS-|SP2-)' | head -5
      fail "Trigger-layer installation reported errors. Legacy triggers were left in place."
    fi

    trigger_layer_count=$(
      "$ROOT/db.sh" -q \
        "SELECT 'TRIGGERSET=' || COUNT(*) FROM user_objects WHERE object_type = 'TRIGGER' AND status = 'VALID' AND object_name IN ('TRG_USERS_PREPARE','TRG_BATCH_LISTING_GUARD','TRG_BID_GUARD','TRG_STORES_STATUS_GUARD','TRG_TRANSPORT_STATUS_GUARD','TRG_REVIEW_GUARD','TRG_BID_NOTIFICATION','TRG_TRANSPORT_NOTIFICATION','TRG_FARM_VERIFY_NOTIFICATION')" \
        2>/dev/null | sed -n 's/^TRIGGERSET=//p' | tail -1
    )
    [ "$trigger_layer_count" = "9" ] ||
      fail "Only $trigger_layer_count of 9 new triggers compiled successfully. Legacy triggers were left in place."

    if [ "$legacy_trigger_count" != "0" ]; then
      out=$("$ROOT/db.sh" "$ROOT/database/10_trigger_migration.sql" 2>&1)
      if grep -qE '^(ORA-|PLS-|SP2-)' <<<"$out"; then
        echo "$out" | grep -E '^(ORA-|PLS-|SP2-)' | head -5
        fail "The old ID-trigger cleanup reported errors."
      fi
    fi
  fi

  update3_view_count=$(
    "$ROOT/db.sh" -q \
      "SELECT 'U3VIEWS=' || COUNT(*) FROM user_objects WHERE object_type = 'VIEW' AND status = 'VALID' AND object_name IN ('V_ORDER_DETAILS','V_STORAGE_DETAILS')" \
      2>/dev/null | sed -n 's/^U3VIEWS=//p' | tail -1
  )
  if [ "$update3_view_count" != "2" ] || [ "$update4_migrated" -eq 1 ]; then
    say "Refreshing database views"
    out=$("$ROOT/db.sh" "$ROOT/database/04_views.sql" 2>&1)
    if grep -qE '^(ORA-|PLS-|SP2-)' <<<"$out"; then
      echo "$out" | grep -E '^(ORA-|PLS-|SP2-)' | head -5
      fail "Update-3 views reported errors. No data was reset."
    fi
  fi

  if [ "$update4_migrated" -eq 1 ]; then
    say "Refreshing PL/SQL packages after Update 4"
    out=$("$ROOT/db.sh" "$ROOT/database/02_business_rules.sql" 2>&1)
    if grep -qE '^(ORA-|PLS-|SP2-)' <<<"$out"; then
      echo "$out" | grep -E '^(ORA-|PLS-|SP2-)' | head -5
      fail "Update-4 business-rule refresh reported errors."
    fi
    out=$("$ROOT/db.sh" "$ROOT/database/05_plsql_layer.sql" 2>&1)
    if grep -qE '^(ORA-|PLS-|SP2-)' <<<"$out"; then
      echo "$out" | grep -E '^(ORA-|PLS-|SP2-)' | head -5
      fail "Update-4 PL/SQL refresh reported errors."
    fi
  fi
fi

for part in server client; do
  if [ ! -d "$ROOT/$part/node_modules" ]; then
    say "Installing $part dependencies"
    (cd "$ROOT/$part" && npm install) || fail "npm install failed in $part/"
  fi
done

mkdir -p "$LOGS"
API_PID=""
UI_PID=""

stop() {
  echo
  [ -n "$UI_PID" ]  && kill "$UI_PID"  2>/dev/null
  [ -n "$API_PID" ] && kill "$API_PID" 2>/dev/null
  wait 2>/dev/null
  echo "Stopped. The database container is still running."
  exit 0
}
trap stop INT TERM

port_busy "$API_PORT" && fail "Port $API_PORT is already in use — something is on the API port."
port_busy "$UI_PORT"  && fail "Port $UI_PORT is already in use — something is on the front-end port."

say "Starting the API"
(cd "$ROOT/server" && exec node src/server.js) >"$LOGS/api.log" 2>&1 &
API_PID=$!

printf 'Waiting for the API'
ready=0
for _ in $(seq 1 40); do
  kill -0 "$API_PID" 2>/dev/null || break
  if api_up; then ready=1; break; fi
  printf '.'; sleep 1
done
echo
if [ "$ready" -ne 1 ]; then
  echo
  tail -20 "$LOGS/api.log"
  fail "The API did not start. Full output: logs/api.log"
fi

say "Starting the front end"
(cd "$ROOT/client" && exec node_modules/.bin/vite) >"$LOGS/client.log" 2>&1 &
UI_PID=$!

for _ in $(seq 1 30); do
  port_busy "$UI_PORT" && break
  kill -0 "$UI_PID" 2>/dev/null || break
  sleep 1
done
if ! port_busy "$UI_PORT"; then
  tail -20 "$LOGS/client.log"
  fail "The front end did not start. Full output: logs/client.log"
fi

cat <<INFO

  API         http://localhost:$API_PORT
  Front end   http://localhost:$UI_PORT
  Logs        logs/api.log, logs/client.log

  Sign in with any seeded account, password Demo@1234.
  abdul.karim@krishichain.bd is a farmer with an open auction.

  Ctrl+C stops both servers.

INFO

wait
