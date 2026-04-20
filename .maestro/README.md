# BowPress Maestro E2E

Black-box UI suite that drives the iOS app and asserts server-side state
for the seven critical paths. Lives alongside the app so flows and app code
evolve together.

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
