#!/usr/bin/env bash
#
# Run a script from KrishiChainV1/sql/ against the demo schema without
# needing any Oracle client on this machine — sqlplus is used from inside
# the Docker container.
#
# SQL Developer is the intended way to run these during the demo. This is
# for checking quickly that a file still runs clean.
#
#   ./tools/run-sql.sh sql/01_create_tables.sql
#   ./tools/run-sql.sh sql/00_reset.sql sql/01_create_tables.sql sql/02_insert_data.sql
#   ./tools/run-sql.sh -q "SELECT COUNT(*) FROM USERS"
#   ./tools/run-sql.sh                      # interactive prompt
#
set -uo pipefail

CONTAINER=krishichain-oracle
SQLPLUS=/u01/app/oracle/product/11.2.0/xe/bin/sqlplus
CONN='krishichain_demo/KrishiDemo2026@localhost:1521/XE'

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "The database container '$CONTAINER' is not running." >&2
  echo "Start it with:  docker start $CONTAINER   (then wait ~30s)" >&2
  exit 1
fi

# SQLBLANKLINES ON — a blank line inside a statement would otherwise end it
#                    when the file is piped in on stdin.
# DEFINE OFF       — stops '&' inside data being read as a substitution
#                    variable prompt.
PREAMBLE='SET SQLBLANKLINES ON
SET DEFINE OFF
SET PAGESIZE 500 LINESIZE 200 FEEDBACK ON SERVEROUTPUT ON'

run() { docker exec -i "$CONTAINER" "$SQLPLUS" -S "$CONN"; }

if [ $# -eq 0 ]; then
  exec docker exec -it "$CONTAINER" "$SQLPLUS" "$CONN"
elif [ "${1:-}" = "-q" ]; then
  printf '%s\n%s\n/\nEXIT\n' "$PREAMBLE" "$2" | run
else
  for f in "$@"; do
    [ -f "$f" ] || { echo "No such file: $f" >&2; exit 1; }
    echo "───── $f"
    # sqlplus's own @ cannot see host paths, so the file is piped in.
    { printf '%s\n' "$PREAMBLE"; cat "$f"; printf '\nEXIT\n'; } | run
  done
fi
