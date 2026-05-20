#!/usr/bin/env bash
# =============================================================================
# Post-deploy verification — runs on the self-hosted runner.
#
# Asserts:
#   1. nginx on :80 responds with a list of business endpoints on /
#   2. /items returns valid JSON
#   3. Content negotiation works (HTML variant returns a <table>)
#   4. /health/* is NOT exposed externally (nginx must hide it)
#   5. Full POST → GET cycle succeeds
#
# Exits non-zero on any failure, with a clear message about which check broke.
# =============================================================================

set -euo pipefail

: "${TARGET_HOST:?missing}"

base="http://${TARGET_HOST}"

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1" >&2; exit 1; }

echo "Verifying ${base}"

# Check 1 ---------------------------------------------------------------------
echo "Check 1: nginx serves the root page"
code=$(curl -sS -o /tmp/root.out -w '%{http_code}' -H 'Accept: text/html' "${base}/")
[[ "$code" == "200" ]] || fail "expected 200 on /, got $code"
grep -q '/items' /tmp/root.out || fail "root response does not list /items"
pass "root reachable and lists business endpoints"

# Check 2 ---------------------------------------------------------------------
echo "Check 2: /items returns JSON"
code=$(curl -sS -o /tmp/items.out -w '%{http_code}' -H 'Accept: application/json' "${base}/items")
[[ "$code" == "200" ]] || fail "expected 200 on /items, got $code"
python3 -c 'import json,sys; json.loads(open("/tmp/items.out").read())' \
  || fail "/items did not return valid JSON"
pass "/items reachable, returns JSON"

# Check 3 ---------------------------------------------------------------------
echo "Check 3: content negotiation — /items returns an HTML table"
code=$(curl -sS -o /tmp/items.html -w '%{http_code}' -H 'Accept: text/html' "${base}/items")
[[ "$code" == "200" ]] || fail "expected 200 on /items (text/html), got $code"
grep -q '<table' /tmp/items.html || fail "/items text/html response did not contain a table"
pass "content negotiation works (HTML)"

# Check 4 ---------------------------------------------------------------------
echo "Check 4: /health/* must NOT be exposed externally"
code=$(curl -sS -o /dev/null -w '%{http_code}' "${base}/health/alive")
[[ "$code" == "404" ]] || fail "expected 404 on /health/alive via nginx, got $code (HEALTH LEAKED)"
pass "/health/alive correctly returns 404 through nginx"

# Check 5 ---------------------------------------------------------------------
marker="verify-$$-$(date +%s)"
echo "Check 5: POST /items creates a record"
created=$(curl -sS -X POST \
  -H 'Accept: application/json' \
  -d "name=${marker}&quantity=1" \
  "${base}/items")
id=$(echo "$created" | python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["id"])')
[[ -n "$id" ]] || fail "POST /items did not return an id"
pass "POST /items created record id=$id"

echo "Check 6: GET /items/<id> returns the new record"
code=$(curl -sS -o /tmp/item.out -w '%{http_code}' -H 'Accept: application/json' "${base}/items/${id}")
[[ "$code" == "200" ]] || fail "expected 200 on /items/$id, got $code"
grep -q "$marker" /tmp/item.out || fail "GET /items/$id did not include the marker name"
pass "GET /items/$id returns the created record"

echo
echo "All verification checks passed."
