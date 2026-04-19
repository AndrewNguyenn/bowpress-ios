#!/bin/bash
# capture-fixtures.sh — snapshot real API responses as JSON fixtures for
# FixtureContractTests.
#
# Usage:
#   ./scripts/capture-fixtures.sh
#
# Prereqs:
#   - `wrangler dev` running at http://localhost:8787 (from bowpress-api/).
#   - Local D1 seeded via `npm run seed:e2e:local` (from bowpress-api/).
#
# Run this whenever the API response shape intentionally changes. The captured
# JSON is committed to source control and becomes the contract iOS decodes.
# If you rename a field server-side, re-running capture + the test suite
# surfaces the drift before production does.

set -e

API=http://localhost:8787
OUT="$(cd "$(dirname "$0")/.." && pwd)/Tests/BowPressTests/Fixtures/api"
mkdir -p "$OUT"

# Ensure the API is reachable.
if ! curl -sf "$API/health" > /dev/null; then
  echo "ERROR: $API/health not responding. Start wrangler dev + run seed:e2e:local first." >&2
  exit 1
fi

echo "Signing in as e2e test user..."
TOKEN=$(curl -sf -X POST "$API/auth/signin" \
  -H 'content-type: application/json' \
  -d '{"email":"e2e-test@bowpress.dev","password":"bowpress-e2e-pw-1234"}' \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')

if [ -z "$TOKEN" ]; then
  echo "ERROR: signin returned no token." >&2
  exit 1
fi

auth_get() {
  curl -sf -H "Authorization: Bearer $TOKEN" "$API$1"
}

capture() {
  local name=$1
  local path=$2
  echo "  → $name"
  auth_get "$path" | python3 -m json.tool > "$OUT/$name"
}

echo "Capturing fixtures to $OUT"
capture "bows.json" "/bows"

# Use the first bow for bow-scoped endpoints.
FIRST_BOW_ID=$(python3 -c 'import json; print(json.load(open("'"$OUT"'/bows.json"))[0]["id"])')

capture "bow-configurations.json" "/bow-configurations?bowId=$FIRST_BOW_ID"
capture "arrow-configs.json" "/arrow-configs"
capture "sessions.json" "/sessions"

# First session → capture its plots.
FIRST_SESSION_ID=$(python3 -c 'import json; print(json.load(open("'"$OUT"'/sessions.json"))[0]["id"])')
capture "plots.json" "/sessions/$FIRST_SESSION_ID/plots"

capture "analytics-overview.json" "/analytics/overview?period=30d"
capture "analytics-comparison.json" "/analytics/comparison?period=30d"

# Suggestions are scoped per-bow. Capture for the first bow (may be empty).
capture "suggestions.json" "/bows/$FIRST_BOW_ID/suggestions?includeRead=true"

echo
echo "Done. Captured $(ls "$OUT" | wc -l | tr -d ' ') fixtures."
echo "Commit the changes and re-run the iOS test suite to verify decodability."
