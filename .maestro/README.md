# BowPress Maestro E2E

Black-box UI suite that drives the iOS app and asserts server-side state
for the seven critical paths. Lives alongside the app so flows and app code
evolve together.

## Status

| Flow | Driver | Status | Notes |
|---|---|---|---|
| `01-session-write-path` | Maestro | ✅ | server-verified: bow + session + plot + end all round-trip |
| `02-paywall-gates-write` | Maestro | ✅ | read-only user → upgrade banner → paywall sheet |
| `03-paywall-purchase` | XCUITest | ✅ | full StoreKit purchase via `SKTestSession`, backend verify round-trip |
| `04-suggestion-response-shape` | Maestro | ✅ | guards the `GET /bows/:id/suggestions` shape |
| `05-delete-bow` | Maestro | ✅ | server-verified deletion |
| `06-lapsed-subscription` | XCUITest | ✅ | forces inactive via `PATCH /__test__/entitlement`, re-purchases |
| `07-analytics-navigation` | Maestro | ✅ | five-tab smoke |
| `08-arrow-crud` | Maestro | ✅ | server-verified: add + delete round-trip |
| `09-config-persistence` | Maestro | ✅ | draw-length edit survives tab switch + re-open |
| `10-end-session-log` | Maestro | ✅ | server-verified: session ends, appears in Log immediately |
| `11-insights` | Maestro | ✅ | backend-driven Insights / Trend Analysis renders |
| `12-analytics-kenrokuen` | Maestro | ✅ | Kenrokuen chrome: eyebrow + stat grid + trend ledger "i." (needs backend) |
| `13-session-kenrokuen` | Maestro | ✅ | Kenrokuen session: setup chrome → begin → 2 arrows → end (writes) |
| `14-log-ledger` | Maestro | ✅ | Kenrokuen Log: "This week" group header + BEST stamp (needs backend sessions) |

## Why two drivers

Maestro handles 9 of the flows — it's black-box, fast, and covers the
navigation + UI-state paths well. The two paywall flows need
`SKTestSession` from `StoreKitTest.framework`, which in turn requires
`XCTest.framework` (weak-linking from an app target fails because
`@rpath` isn't wired for non-test bundles). The solution is an XCUITest
bundle (`Tests/BowPressUITests/PaywallUITests.swift`) where both
frameworks are legal dependencies.

The XCUITest bundle also needs backend cooperation to accept the
SKTestSession-issued JWS — it's signed by Apple's test chain, not Apple
Root G3 — so `src/controllers/subscriptionController.ts` decodes
unverified payloads when `ENVIRONMENT !== 'production'`. Production
still fails closed.

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
| `08-arrow-crud.yaml` | Add + delete arrow config round-trip |
| `09-config-persistence.yaml` | Draw-length edit survives tab switch + re-open |
| `10-end-session-log.yaml` | Session ends, appears in Log immediately |
| `11-insights.yaml` | Analytics pipeline hydration smoke |
| `12-analytics-kenrokuen.yaml` | Kenrokuen analytics chrome: eyebrow + Average + ledger "i." |
| `13-session-kenrokuen.yaml` | Kenrokuen session: setup → begin → 2 arrows → end |
| `14-log-ledger.yaml` | Kenrokuen Log: "This week" group header + BEST stamp |

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
