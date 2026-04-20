#!/bin/bash
set -euo pipefail

# BowPress end-to-end orchestrator.
# Runs the Maestro suite against local, staging, or production.
# See .maestro/README.md for the overall picture.

TARGET="local"
SINGLE_FLOW=""
SIMULATOR="iPhone 16"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="$2"; shift 2 ;;
    --flow)
      SINGLE_FLOW="$2"; shift 2 ;;
    --simulator)
      SIMULATOR="$2"; shift 2 ;;
    -h|--help)
      cat <<USAGE
Usage: $0 [--target local|staging|production] [--flow NAME] [--simulator "iPhone 16"]
USAGE
      exit 0 ;;
    *)
      echo "Unknown arg: $1"; exit 2 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="com.andrewnguyen.bowpress"
API_ROOT="${REPO_ROOT}/../bowpress-api"

case "$TARGET" in
  local)      API_BASE_URL="http://localhost:8787" ;;
  staging)    API_BASE_URL="https://bowpress-api-staging.stageandrewnguyen.workers.dev" ;;
  production) API_BASE_URL="https://bowpress-api.stageandrewnguyen.workers.dev" ;;
  *) echo "Unknown target: $TARGET"; exit 2 ;;
esac

export API_BASE_URL
export SIMCTL_CHILD_API_BASE_URL="$API_BASE_URL"
export SIMCTL_CHILD_USE_LOCAL_API="1"

echo "==> Target: $TARGET ($API_BASE_URL)"

# --- Backend orchestration ------------------------------------------------

WRANGLER_PID=""
cleanup() {
  if [[ -n "$WRANGLER_PID" ]] && kill -0 "$WRANGLER_PID" 2>/dev/null; then
    echo "==> Stopping wrangler (pid $WRANGLER_PID)"
    kill "$WRANGLER_PID" 2>/dev/null || true
    wait "$WRANGLER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

if [[ "$TARGET" == "local" ]]; then
  if [[ ! -d "$API_ROOT" ]]; then
    echo "!! Expected backend at $API_ROOT" >&2
    exit 1
  fi
  echo "==> Seeding local D1 with e2e fixtures"
  (cd "$API_ROOT" && npm run seed:e2e:local --silent) || { echo "!! Seed failed"; exit 1; }
  echo "==> Starting wrangler dev in $API_ROOT"
  # ENVIRONMENT=test un-gates the /__test__ routes and the dev-bypass in
  # requireEntitlement for the seeded e2e user. Production stays fail-closed.
  (cd "$API_ROOT" && npx wrangler dev --local --port 8787 --var ENVIRONMENT:test) &
  WRANGLER_PID=$!
  # Wait for /health — up to 45s
  for i in $(seq 1 45); do
    if curl -fsS "$API_BASE_URL/health" >/dev/null 2>&1; then
      echo "==> Backend healthy after ${i}s"
      break
    fi
    sleep 1
    if [[ $i == 45 ]]; then
      echo "!! Backend never came up" >&2
      exit 1
    fi
  done
elif [[ "$TARGET" == "staging" ]]; then
  echo "==> Reminder: staging seeding is manual."
  echo "   Run from bowpress-api: npm run deploy:staging && npm run seed:e2e:remote -- --env staging"
  curl -fsS "$API_BASE_URL/health" >/dev/null || { echo "!! staging /health not OK"; exit 1; }
elif [[ "$TARGET" == "production" ]]; then
  curl -fsS "$API_BASE_URL/health" >/dev/null || { echo "!! production /health not OK"; exit 1; }
fi

# --- iOS build ------------------------------------------------------------

cd "$REPO_ROOT"
echo "==> xcodegen"
xcodegen generate

# If the preferred simulator doesn't exist, fall back to a sibling.
if ! xcrun simctl list devices available | grep -q "$SIMULATOR "; then
  FALLBACK=$(xcrun simctl list devices available | grep -iE 'iphone 1[5-6]' | head -1 | sed -E 's/^\s*([^(]+)\(.*/\1/' | xargs)
  echo "!! Simulator '$SIMULATOR' not available, falling back to '$FALLBACK'"
  SIMULATOR="$FALLBACK"
fi

echo "==> xcodebuild (BowPress-RemoteAPI, $SIMULATOR)"
xcodebuild \
  -project BowPress.xcodeproj \
  -scheme BowPress-RemoteAPI \
  -destination "platform=iOS Simulator,name=$SIMULATOR" \
  -derivedDataPath "$REPO_ROOT/build" \
  -quiet build

APP_PATH=$(find "$REPO_ROOT/build/Build/Products/Debug-iphonesimulator" -name "BowPress.app" -maxdepth 2 | head -1)
if [[ -z "$APP_PATH" ]]; then
  echo "!! BowPress.app not found after build" >&2
  exit 1
fi

echo "==> Booting simulator"
xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
xcrun simctl bootstatus "$SIMULATOR" -b
open -a Simulator
xcrun simctl install booted "$APP_PATH"

# --- Flow selection -------------------------------------------------------

if [[ "$TARGET" == "production" ]]; then
  FLOWS=(
    "04-suggestion-response-shape.yaml"
    "07-analytics-navigation.yaml"
  )
else
  FLOWS=(
    "01-session-write-path.yaml"
    "02-paywall-gates-write.yaml"
    "03-paywall-purchase.yaml"
    "04-suggestion-response-shape.yaml"
    "05-delete-bow.yaml"
    "06-lapsed-subscription.yaml"
    "07-analytics-navigation.yaml"
  )
fi
if [[ -n "$SINGLE_FLOW" ]]; then
  FLOWS=("$SINGLE_FLOW")
fi

# --- Flow loop ------------------------------------------------------------

FAILED=()
for FLOW in "${FLOWS[@]}"; do
  echo ""
  echo "================================================================="
  echo "  Flow: $FLOW"
  echo "================================================================="

  # Fresh install before every flow. This clears the app sandbox AND keychain,
  # which solves two problems at once:
  #   1. StoreKit test transaction history is wiped before paywall flows
  #      (this Xcode has no `simctl storekit` subcommand).
  #   2. The auth token persisted in the keychain by a previous flow's role
  #      (e.g. e2e-test) can't leak into this flow's role (e.g. e2e-free).
  xcrun simctl uninstall booted "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl install booted "$APP_PATH"

  # Flow #6 precondition: mark the e2e-free user's entitlement inactive.
  if [[ "$FLOW" == "06-"* && "$TARGET" != "production" ]]; then
    echo "==> Marking e2e-free entitlement inactive"
    curl -fsS -X PATCH "$API_BASE_URL/__test__/entitlement" \
      -H "Content-Type: application/json" \
      -d '{"email":"e2e-free@bowpress.dev","isActive":false}' >/dev/null \
      || echo "!! entitlement patch failed — flow will still run"
  fi

  if command -v maestro >/dev/null 2>&1; then
    if ! maestro test "$REPO_ROOT/.maestro/$FLOW"; then
      FAILED+=("$FLOW")
      continue
    fi
  else
    echo "!! maestro not installed; skipping $FLOW"
    continue
  fi

  # Server-state assertion for mutating flows.
  case "$FLOW" in
    01-*|03-*|05-*)
      if [[ "$TARGET" != "production" ]]; then
        if ! "$REPO_ROOT/scripts/assert-server-state.sh" "$FLOW"; then
          FAILED+=("$FLOW (server assertion)")
        fi
      fi
      ;;
  esac
done

# --- Summary --------------------------------------------------------------

echo ""
echo "================================================================="
if [[ ${#FAILED[@]} -eq 0 ]]; then
  echo "  All flows passed ($TARGET)"
  exit 0
else
  echo "  FAILURES:"
  for F in "${FAILED[@]}"; do echo "    - $F"; done
  exit 1
fi
