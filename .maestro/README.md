# BowPress Maestro E2E

Black-box UI suite that drives the iOS app and asserts server-side state
for the seven critical paths. Lives alongside the app so flows and app code
evolve together.

## Status

| Flow | Status | Notes |
|---|---|---|
| `01-session-write-path` | ✅ passing | server-verified: bow + session + plot + end all round-trip |
| `02-paywall-gates-write` | ✅ passing | read-only user → upgrade banner → paywall sheet |
| `03-paywall-purchase` | ⏸ manual only | see "Known limits" |
| `04-suggestion-response-shape` | ✅ passing | guards the `GET /bows/:id/suggestions` shape from the recent sync-fix merge |
| `05-delete-bow` | ✅ passing | server-verified deletion |
| `06-lapsed-subscription` | ⏸ manual only | see "Known limits" |
| `07-analytics-navigation` | ✅ passing | five-tab smoke |
| `08-arrow-crud` | ✅ passing | server-verified: add + delete round-trip |
| `09-config-persistence` | ✅ passing | draw-length edit survives tab switch and re-open |
| `10-end-session-log` | ✅ passing | server-verified: session ends, appears in Log immediately |
| `11-insights` | ✅ passing | backend-driven Insights section renders |

## Known limits

**Paywall purchase flows (03, 06) are manual-only.** Testing StoreKit purchases from automation requires an `SKTestSession`, which is part of `StoreKitTest.framework`. That framework has a hard runtime dependency on `XCTest.framework`, available only to test-target bundles — an app target's weak-link can't satisfy the `@rpath` lookup. The other avenue (scheme-attached `STORE_KIT_CONFIGURATION_FILE_PATH`) works when running from the Xcode IDE but silently does nothing when launching via `xcodebuild` + `simctl launch`. For now these flows stay on disk for copy-paste into a manual Xcode run; a future follow-up could move them into a `BowPressUITests` XCUITest target where `SKTestSession` is legal.

## Prerequisites

- macOS + Xcode 15+ with an iOS 17 Simulator (iPhone 16 recommended).
- [Maestro](https://maestro.mobile.dev): `brew install maestro`.
- `jq` on `$PATH` (used by `scripts/assert-server-state.sh`).
- For `--target local`: `bowpress-api` checked out as a sibling directory,
  with `wrangler` installed (`npm i -g wrangler`) and the local D1 seeded.

## Running

```bash
# Full suite against local wrangler dev (default)
./scripts/e2e.sh

# Single flow
./scripts/e2e.sh --flow 01-session-write-path.yaml

# Staging — requires a prior `wrangler deploy --env staging`
./scripts/e2e.sh --target staging

# Production — smoke only (flows 04 and 07)
./scripts/e2e.sh --target production
```

## Flow map

| File | Purpose |
|---|---|
| `01-session-write-path.yaml` | Create bow/config, run a session, plot arrows, end |
| `02-paywall-gates-write.yaml` | Unentitled user hits paywall on write |
| `03-paywall-purchase.yaml`   | StoreKit purchase → entitlement active |
| `04-suggestion-response-shape.yaml` | Analytics decodes OK (prod-safe) |
| `05-delete-bow.yaml` | DELETE /bows/:id round-trip |
| `06-lapsed-subscription.yaml` | Server-forced lapse → re-subscribe |
| `07-analytics-navigation.yaml` | Walk all five tabs (prod-safe) |

## How auth works

`DevAutoSignIn.ensureSignedIn()` is called from `MainTabView.task` in DEBUG
builds. It reads `-AutoSignInEmail` / `-AutoSignInPassword` launch args
(passed by each flow's `launchApp.arguments`) and signs in before Maestro
starts interacting with the UI.

## Base URL injection

Flows run under the `BowPress-RemoteAPI` scheme. `API_BASE_URL` is injected
by the orchestrator via `SIMCTL_CHILD_API_BASE_URL` on the shell
environment — `xcrun simctl launch` forwards `SIMCTL_CHILD_*` vars into
the launched app's `ProcessInfo.environment`.
