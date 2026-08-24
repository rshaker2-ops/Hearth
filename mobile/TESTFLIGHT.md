# Shipping Hearth to TestFlight

Hearth is distributed to the family through **TestFlight only** — no public App
Store listing. This is the full path from a fresh Mac to a build on everyone's
phone, using what's already configured in this repo.

## What the repo already carries

| Thing | Value | Where |
|---|---|---|
| Team ID | `7G5Q9CULSW` | `ios/Signing.xcconfig` |
| Bundle ID (release) | `com.lordblight.hearth` (+ `.ShareExtension`, `.Widget`) | `ios/Signing.xcconfig` |
| Bundle ID (debug/profile) | `com.lordblight.hearth.dev.*` | `ios/Signing.xcconfig` |
| App group | `group.com.lordblight.hearth` | `ios/Signing.xcconfig` |
| App name | Hearth (`PRODUCT_NAME`, `CFBundleName`, Android label) | Xcode project / Info.plist |
| App icon + splash | Hearth artwork, all sizes generated | `assets/hearth-*` via `flutter_launcher_icons` / `flutter_native_splash` |
| Marketing version | `version:` in `pubspec.yaml` | fastlane reads it on every release |
| Build number | last TestFlight build + 1 | fastlane, automatic |
| Export compliance | `ITSAppUsesNonExemptEncryption = false` | `ios/Runner/Info.plist` (no per-build questionnaire) |
| Upload lanes | `release`, `build_only` | `ios/fastlane/Fastfile` (Xcode-automatic signing) |

Personal overrides (a different team/bundle) go in `ios/Signing.local.xcconfig`
— never edit the checked-in values for a one-off.

## 0. Prerequisites (once)

- A Mac with Xcode installed (the version the repo's CI uses is a safe pick).
- Apple Developer Program membership active on team `7G5Q9CULSW`.
- Repo tooling: [mise](https://mise.jdx.dev) — from `mobile/` run
  `mise install`, then `mise run checkout` (fetches Flutter deps, runs codegen,
  `pod install`).
- Ruby gems for fastlane: `cd mobile/ios && bundle install`.

## 1. One-time Apple setup

1. **Let Xcode register the identifiers.** Open `mobile/ios/Runner.xcworkspace`,
   sign in with your Apple ID (Xcode → Settings → Accounts), select the team on
   the Runner, ShareExtension and WidgetExtension targets, and build once for
   *Any iOS Device*. Automatic signing registers the three bundle IDs, the
   `group.com.lordblight.hearth` app group, and the WiFi-info capability on the
   team. (Equivalently: `bundle exec fastlane build_only` from `mobile/ios`.)
2. **Create the app record.** In [App Store Connect](https://appstoreconnect.apple.com)
   → My Apps → **+** → New App: platform iOS, name **Hearth**, bundle ID
   `com.lordblight.hearth`, any SKU (e.g. `hearth-ios`). The name only shows in
   TestFlight, so it doesn't need to be globally clever.
3. **(Recommended) API key** so uploads never prompt for 2FA: App Store Connect
   → Users and Access → Integrations → App Store Connect API → generate a key
   with **App Manager** role. Save the `.p8` as
   `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` and export
   `APP_STORE_CONNECT_API_KEY_ID` and `APP_STORE_CONNECT_API_KEY_ISSUER_ID` in
   your shell. Without it, fastlane signs in interactively with your Apple ID.

## 2. Ship a build

```bash
cd mobile
mise run checkout        # after pulling new commits
cd ios
bundle exec fastlane release
```

The lane sets the marketing version from `pubspec.yaml`, bumps the build number
past the latest TestFlight build (the very first upload becomes build 1),
archives with automatic signing, and uploads. Processing on Apple's side takes
5–30 minutes; you'll get an email when the build is testable.

## 3. Invite the family

In App Store Connect → Hearth → TestFlight:

1. Create an **external group** (e.g. "Family") and enable the **public link**,
   or invite each person by email.
2. The **first build** in an external group goes through Beta App Review
   (hours to ~a day, and far lighter than App Review). In the review notes,
   explain: *"Private photo server for an invited family group. Sign-in
   requires an invitation issued by the server administrator; the app cannot
   be used without one."* Beta review generally accepts limited-audience apps
   like this — they mainly verify the app launches and states what it does.
3. Family members install the **TestFlight app**, open the invite link, and get
   Hearth. Sign-in is the normal flow: server URL `https://im.lordblight.com`
   → portal Google sign-in (must be an invited account) → Immich login.

Alternative with zero review: add people as users on your App Store Connect
team and use an **internal group** — usually not worth the account juggling
for a family.

## 4. The 90-day rhythm

TestFlight builds expire **90 days** after upload (internal and external
alike). Testers get a warning as expiry approaches. Re-running
`bundle exec fastlane release` every ~2–3 months keeps everyone running —
new builds push to testers automatically. Calendar-remind yourself; there's no
server-side automation for this fork (CI's signing pipeline is disabled).

## Troubleshooting

| Symptom | Fix |
|---|---|
| Xcode: "Failed to register bundle identifier" | The bundle ID is taken on another team — pick a variant in `Signing.local.xcconfig`. |
| "Provisioning profile doesn't include the App Groups capability" | Open each target's Signing & Capabilities tab once with the team selected so Xcode refreshes the App ID; make sure the group shows as `group.com.lordblight.hearth`. |
| `latest_testflight_build_number` auth errors | Set up the API key from step 1.3, or run once interactively and store the session. |
| Upload OK but build never appears | Check App Store Connect → TestFlight → iOS builds for a processing/compliance banner; with `ITSAppUsesNonExemptEncryption=false` set there should be none. |
| Testers on the build can't reach the server | That's the portal, not TestFlight: their Google account needs an invitation, and the device token can be revoked/re-issued from the portal admin (see homeserver `docs/hearth-mobile-app-auth.md`). |

## If Hearth ever goes to the real App Store

Not the current plan, but for the record: full App Review would additionally
want screenshots/metadata, a demo account reviewers can actually use, and
possibly a second sign-in option (Guideline 4.8 — the portal is Google-only
today). Unlisted App Distribution (link-only, permanent installs) would be the
route to request; revisit then.
