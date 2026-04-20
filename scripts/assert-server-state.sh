#!/bin/bash
set -euo pipefail

# Post-flow server assertions. Called by scripts/e2e.sh after flows that
# mutate backend state. Exits non-zero on assertion failure.

FLOW="${1:-}"
API="${API_BASE_URL:-http://localhost:8787}"

USER_EMAIL="e2e-test@bowpress.dev"
USER_PW="bowpress-e2e-pw-1234"
FREE_EMAIL="e2e-free@bowpress.dev"
FREE_PW="bowpress-e2e-pw-1234"

jwt_for() {
  local email="$1" pw="$2"
  curl -fsS -X POST "$API/auth/signin" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$pw\"}" \
    | jq -r '.token // .accessToken // empty'
}

die() { echo "!! assertion failed: $*" >&2; exit 1; }

case "$FLOW" in
  01-session-write-path.yaml)
    TOKEN="$(jwt_for "$USER_EMAIL" "$USER_PW")"
    [[ -n "$TOKEN" ]] || die "could not obtain JWT for $USER_EMAIL"

    BOWS=$(curl -fsS -H "Authorization: Bearer $TOKEN" "$API/bows")
    echo "$BOWS" | jq -e '.[] | select(.name == "Maestro Recurve")' >/dev/null \
      || die "Maestro Recurve not in GET /bows"

    SESSIONS=$(curl -fsS -H "Authorization: Bearer $TOKEN" "$API/sessions")
    SID=$(echo "$SESSIONS" | jq -r '.[0].id // empty')
    [[ -n "$SID" ]] || die "no sessions returned"

    PLOTS=$(curl -fsS -H "Authorization: Bearer $TOKEN" "$API/sessions/$SID/plots")
    PLOT_COUNT=$(echo "$PLOTS" | jq 'length')
    [[ "$PLOT_COUNT" -ge 3 ]] || die "expected >=3 plots, got $PLOT_COUNT"

    ENDS=$(curl -fsS -H "Authorization: Bearer $TOKEN" "$API/sessions/$SID/ends")
    END_COUNT=$(echo "$ENDS" | jq 'length')
    [[ "$END_COUNT" -ge 1 ]] || die "expected >=1 end, got $END_COUNT"
    echo "  ✓ write path: bow + session + $PLOT_COUNT plots + $END_COUNT ends"
    ;;

  03-paywall-purchase.yaml)
    TOKEN="$(jwt_for "$FREE_EMAIL" "$FREE_PW")"
    [[ -n "$TOKEN" ]] || die "could not obtain JWT for $FREE_EMAIL"

    SUB=$(curl -fsS -H "Authorization: Bearer $TOKEN" "$API/subscription")
    ACTIVE=$(echo "$SUB" | jq -r '.isActive')
    PROVIDER=$(echo "$SUB" | jq -r '.provider // empty')
    [[ "$ACTIVE" == "true" ]] || die "subscription not active after purchase"
    [[ "$PROVIDER" == "apple" ]] || die "expected apple provider, got $PROVIDER"
    echo "  ✓ subscription active, provider=$PROVIDER"
    ;;

  05-delete-bow.yaml)
    TOKEN="$(jwt_for "$USER_EMAIL" "$USER_PW")"
    [[ -n "$TOKEN" ]] || die "could not obtain JWT for $USER_EMAIL"

    BOWS=$(curl -fsS -H "Authorization: Bearer $TOKEN" "$API/bows")
    if echo "$BOWS" | jq -e '.[] | select(.name == "Maestro Recurve")' >/dev/null; then
      die "Maestro Recurve still present in GET /bows after delete"
    fi
    echo "  ✓ Maestro Recurve no longer in /bows"
    ;;

  *)
    # No assertion defined for this flow — not an error.
    ;;
esac
