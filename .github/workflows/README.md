# CI / CD

Two workflows:

| File | Trigger | What it does |
|---|---|---|
| `testflight.yml` | Push to `main` | Archive + upload to TestFlight. No App Review involvement. |
| `release.yml` | Tag `v*` (e.g. `v1.0.2`) | Archive + upload to TestFlight + submit to App Review. |

## Day-to-day flow

```
# iterate on main, each push → new TestFlight build in ~10 min
git push origin main

# when ready to submit to Apple for review:
git tag v1.0.2 -m "Fix paywall dismissal bug"
git push --tags
```

The release workflow:

1. Extracts `1.0.2` from the tag name
2. Pulls the next `CFBundleVersion` from ASC (latest build + 1)
3. Edits `project.yml` in-place with both values (not committed)
4. Runs the same archive + upload as TestFlight
5. After upload: cancels any in-flight review submissions, creates (or reuses) the 1.0.2 App Store version, links the build, copies localization + screenshots from the most recent prior version, sets App Review demo-account notes, and submits.

Concurrency: tagged releases run serially — never two at once. TestFlight builds cancel their in-flight predecessor if you push again before one finishes.

## Secrets required

Set in GitHub → Settings → Secrets and variables → Actions → New repository secret.

| Secret | Value | How to obtain |
|---|---|---|
| `ASC_API_KEY_ID` | `NAC59CNG59` | App Store Connect → Users and Access → Integrations → Team Keys |
| `ASC_API_ISSUER_ID` | `13d8cf33-53ce-4889-85da-511d61c7bd2c` | Same page, top of Integrations tab |
| `ASC_API_KEY_P8` | Contents of `AuthKey_NAC59CNG59.p8` (paste the whole PEM, including header and footer) | Downloaded once when the key was created |
| `APPLE_TEAM_ID` | `DFT522PW2V` | Apple Developer → Membership |
| `APPLE_DIST_CERT_P12_BASE64` | `base64 -i scripts/asc/certs/distribution_legacy.p12 \| pbcopy` | Generated locally in the initial signing setup |
| `APPLE_DIST_CERT_P12_PASSWORD` | `bowpress` | Password used when the `.p12` was exported |
| `APPLE_PROVISION_PROFILE_BASE64` | `base64 -i scripts/asc/certs/BowPress_AppStore.mobileprovision \| pbcopy` | Downloaded from App Store Connect alongside the cert |

Setting them all via the `gh` CLI (fastest):

```bash
gh secret set ASC_API_KEY_ID --body "NAC59CNG59"
gh secret set ASC_API_ISSUER_ID --body "13d8cf33-53ce-4889-85da-511d61c7bd2c"
gh secret set ASC_API_KEY_P8 < /Users/andrewnguyen/Downloads/AuthKey_NAC59CNG59.p8
gh secret set APPLE_TEAM_ID --body "DFT522PW2V"
gh secret set APPLE_DIST_CERT_P12_PASSWORD --body "bowpress"
base64 -i scripts/asc/certs/distribution_legacy.p12 | gh secret set APPLE_DIST_CERT_P12_BASE64
base64 -i scripts/asc/certs/BowPress_AppStore.mobileprovision | gh secret set APPLE_PROVISION_PROFILE_BASE64
```

## Runner choice

`macos-15` (Sequoia) is used because it comes with Xcode 16-26 pre-installed. The `setup-xcode` action pins `latest-stable`. If your project needs a specific Xcode version, change the `xcode-version:` line.

Cost per run: ~$0.80 (8-min archive × $0.08/min + overhead). Budget accordingly if you push frequently.

## Troubleshooting

**Build fails with "no matching provisioning profiles found":** The profile's bundle ID must match `com.andrewnguyen.bowpress`. If the embedded profile ID drifts from what's in `scripts/asc/certs/`, re-download from ASC and update `APPLE_PROVISION_PROFILE_BASE64`.

**altool 90062 "version X is closed for new submissions":** You pushed a tag whose `MARKETING_VERSION` has already been approved. Bump to the next patch (`v1.0.3` instead of `v1.0.2`).

**submit-to-review.py "version not ready to be submitted":** ASC sometimes takes up to a minute for a version's state machine to settle after the build is linked. The script retries 20 times with 15s backoff — if it gives up, check App Store Connect for what's blocking (usually a missing metadata field).

**`wrangler` errors:** This project is iOS — if you see `wrangler`, you're in the wrong repo. `bowpress-api` is the Cloudflare Worker.
