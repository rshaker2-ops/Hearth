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
| App name (on device) | Hearth (`PRODUCT_NAME`, `CFBundleName`, Android label) | Xcode project / Info.plist |
| App name (App Store Connect) | **Hearth Photos** — plain "Hearth" is taken | App Store Connect only; nothing in the repo |
| App icon + splash | Hearth artwork, all sizes generated | `assets/hearth-*` via `flutter_launcher_icons` / `flutter_native_splash` |
| Marketing version | `version:` in `pubspec.yaml` | fastlane reads it on every release |
| Build number | last TestFlight build + 1 | fastlane, automatic |
| Export compliance | `ITSAppUsesNonExemptEncryption = false` | `ios/Runner/Info.plist` (no per-build questionnaire) |
| Upload lanes | `release`, `build_only` | `ios/fastlane/Fastfile` (Xcode-automatic signing) |

Personal overrides (a different team/bundle) go in `ios/Signing.local.xcconfig`
— never edit the checked-in values for a one-off.

## 0. Prerequisites (once)

macOS ships none of the iOS toolchain by default, and each missing piece fails
with an error that doesn't name the real cause — the exact messages are in
[Troubleshooting](#troubleshooting). Get these in place first:

**Full Xcode**, not just the Command Line Tools. Flutter resolves the app's
bundle identifier by asking `xcodebuild`, so a CLT-only machine cannot build at
all. Install Xcode from the App Store, then point the toolchain at it:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
xcodebuild -runFirstLaunch
xcodebuild -version     # must print a version, not an error
```

**Ruby 3.0+** for CocoaPods and fastlane. Apple's system Ruby is 2.6, which
current gems refuse to install against (`ffi` is usually the first to complain):

```bash
brew install ruby
echo 'export PATH="$(brew --prefix ruby)/bin:$PATH"' >> ~/.zprofile
export PATH="$(brew --prefix ruby)/bin:$PATH"    # this shell, now
ruby -v                 # must not say 2.6.x
```

Homebrew's Ruby is keg-only (macOS provides its own), hence the PATH line.
`mise use -g ruby@3.3` works too and matches CI exactly, but compiles from
source. Ruby 3.4+ dropped `abbrev` from the default gems — the Gemfile already
carries it.

**CocoaPods** — `brew install cocoapods`, or skip it and let the Gemfile
provide it (`mise run checkout` uses whichever it finds).

**Apple Developer Program** membership active on team `7G5Q9CULSW`.

**Repo tooling**: [mise](https://mise.jdx.dev) — from `mobile/` run
`mise install`, then `mise run checkout` (Flutter deps, codegen, `pod install`).

**Gems for fastlane**: `cd mobile/ios && bundle install`.

## 1. One-time Apple setup

1. **Let Xcode register the identifiers.** Open `mobile/ios/Runner.xcworkspace`,
   sign in with your Apple ID (Xcode → Settings → Accounts), select the team on
   the Runner, ShareExtension and WidgetExtension targets, and build once for
   *Any iOS Device*. Automatic signing registers the three bundle IDs, the
   `group.com.lordblight.hearth` app group, and the WiFi-info capability on the
   team. (Equivalently: `bundle exec fastlane build_only` from `mobile/ios`.)
2. **Create the app record.** In [App Store Connect](https://appstoreconnect.apple.com)
   → My Apps → **+** → New App: platform iOS, name **Hearth Photos**, bundle ID
   `com.lordblight.hearth`, any SKU (e.g. `hearth-ios`). App Store names must be
   globally unique and plain "Hearth" is already taken several times over, hence
   the suffix. This name is independent of everything in the repo — the home
   screen still says **Hearth** — and with TestFlight-only distribution it shows
   up only in the TestFlight app and your ASC dashboard. If ASC ever refuses it,
   "Hearth Album" and "Lordblight Hearth" were also clear.
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

In App Store Connect → Hearth Photos → TestFlight:

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
| `mise run checkout` fails with `pod: command not found` | CocoaPods isn't installed. `brew install cocoapods`, or `cd mobile/ios && bundle install` to use the Gemfile's copy, then re-run. |
| Flutter fails with **"Application not configured for iOS"** | Flutter can't reach `xcodebuild`, so it can't resolve `$(PRODUCT_BUNDLE_IDENTIFIER)` from `Info.plist`. Almost always full Xcode missing, or `xcode-select` still pointing at the Command Line Tools — see Prerequisites. `flutter doctor -v` names it. |
| `bundle install` fails: *"ffi … requires ruby version >= 3.0 … current version 2.6.10"* | You're on Apple's system Ruby. Install a modern one and put it first on PATH (Prerequisites). |
| An Xcode build phase exits with **status 127** | A build phase couldn't find a tool. Usually `ios/Flutter/Generated.xcconfig` is missing or stale, which `mise run checkout` regenerates (it runs `flutter build ios --config-only`). |
| Archive warns *"CFBundleVersion of an app extension … must match … its containing parent app"*, or upload is rejected with **ITMS-90473** | The extensions drifted from the app's version. Both lanes call `stamp_all_targets`, which writes the same `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` to every target — re-run the lane rather than editing versions by hand in Xcode. |
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
