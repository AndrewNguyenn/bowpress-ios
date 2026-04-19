# BowPress

**Tune smarter. Shoot better.**

BowPress is an iOS app for competitive and recreational archers who want quantifiable data behind every adjustment they make to their bow — not just feel.

---

## The Problem

Bow tuning involves dozens of interdependent variables: draw length, peep height, limb turns, cable twist, rest position, nocking height, and more. Most archers track changes through memory and feel alone. When something stops working, it's nearly impossible to know what changed, when, or why.

BowPress replaces guesswork with a logged history of every configuration state and every arrow you shoot under it.

---

## What It Does

**Configuration tracking**
Every time you change something on your bow or arrow setup, BowPress snapshots the full configuration. Nothing is overwritten — the complete history is preserved so you can always see exactly what your bow looked like when a group of arrows was shot.

**Session logging**
When you shoot, you log arrows against the active configuration. A simple drag-to-place target UI captures where each arrow landed. You can also write notes during a session — observations about hold feel, back tension, release — that travel alongside the objective data.

**Mid-session changes**
Changing something mid-session doesn't break the flow. BowPress handles the bookkeeping quietly in the background, keeping your arrows correctly attributed to the configuration they were shot under.

**Analytics**
After enough sessions, BowPress surfaces patterns: which configurations produced your tightest groups, how specific changes have affected your point of impact over time, and what your shooting data suggests you try next. The more you log, the more specific the insights get.

---

## Bow Parameters Tracked

Draw length · Let-off % · Peep height · D-loop length · Top/bottom cable twists · Main string twists (top/bottom) · Top/bottom limb turns · Rest position (vertical, horizontal, depth) · Sight distance · Grip angle · Nocking height

## Arrow Parameters Tracked

Length · Point weight · Fletching type, length & offset · Nock type · Total arrow weight

---

## Running Locally

**Requirements:** Xcode, [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

From the `bowpress-ios` directory:

```bash
./run.sh
```

This will regenerate the Xcode project, boot the iPhone 16 simulator, build, and launch the app. If the app bundle install step fails, Xcode will be open — just press **Cmd+R**.

To regenerate the project after pulling new code without launching:

```bash
xcodegen generate
```

---

## Running against local API

By default the `BowPress` scheme uses in-memory SwiftData seeded from
`DevMockData` — fast, deterministic, no network. When you need to exercise
real HTTP against the Hono API:

1. In `bowpress-api/`, run `npm run dev` (wrangler dev on 8787).
2. In `bowpress-ios/`, switch scheme to `BowPress-LocalAPI`.
3. Run. APIClient now calls `http://localhost:8787` for all read paths.

Known limitations of LocalAPI mode:
- Write methods (createSession, plotArrow, completeEnd, etc.) are still
  echo stubs in APIClient — this mode is primarily for read-path and
  auth/profile/subscription integration work.
- `fetchSuggestions()` (no bowId) has no matching Hono endpoint — the API
  only exposes `GET /bows/:bowId/suggestions`. LocalAPI mode returns an
  empty list from the no-arg overload; use `fetchSuggestions(bowId:)` via
  analytics screens instead.
- Session Log starts empty; run `npm run seed:e2e:local` in the API repo
  if you want fixture data in the local D1.

## Tech

- iOS 17+ · SwiftUI
- Backend: Cloudflare Workers + D1
- Sign in with Apple, Google, or email
