#!/bin/sh
# Container entrypoint:
#   1) run database migrations (idempotent, see app/migrate.js);
#   2) exec the HTTP server, replacing this shell so PID 1 == node.
#
# All CLI args ($@) are forwarded to both migrate.js and server.js.

set -e

echo "[entrypoint] running migrations..."
node /app/migrate.js "$@"

echo "[entrypoint] starting server..."
exec node /app/server.js "$@"
