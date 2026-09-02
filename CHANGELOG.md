# Changelog

All notable changes to LemmeGo are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This project follows [Semantic Versioning](https://semver.org/).

## Website — 2026-09-02 (no app version change)

Published the LemmeGo privacy policy, which App Store Connect requires a URL for
before external TestFlight testing can be enabled.

- `web/privacy/index.html` is live at **https://demo.justintormey.com/lemmego/privacy/**
- `scripts/deploy` publishes `web/` to the `lemmego/` prefix of the
  `justintormey.com` S3 bucket and invalidates CloudFront `E1R27W2LA6BBEH`, matching
  the per-project pattern already used by `qr-contact-card`. The sync is confined to
  that prefix so sibling projects in the same bucket cannot be touched. `--dry-run`
  previews.
- `docs/TESTFLIGHT-EXTERNAL.md` section 6 now carries the live URL, and its
  "What to Test" section was rewritten for 1.2.0. It had been drafted before the QA
  fixes landed and still listed the zero-duration session and the "Lock Now" tag
  binding as known issues, both of which 1.2.0 fixes.

**Deliberately no version bump.** `MARKETING_VERSION` is the iOS app's version and
the app binary is unchanged. Bumping it for a website-only change would put a version
on the build Justin is about to submit that does not match what was tested.

## [1.2.0] - 2026-09-02

Full QA pass ahead of TestFlight. The build now archives, exports as an App Store
IPA, and runs a test suite that actually executes. Details in `docs/QA-2026-09-02.md`.

### Fixed
- **Screen Time was read as denied on iOS 26.4+.** iOS 26.4 added
  `FamilyControls.AuthorizationStatus.approvedWithDataAccess`. It fell through the
  `@unknown default` arm in `AppBlockingManager.checkAuthorization()` and set
  `isAuthorized = false`, so the app refused to start any lock session for users who
  had granted permission. Authorization is now derived from the status raw value, so
  a future approval state cannot silently disable locking again.
- **Emergency-unlock budget reset a day early.** `Calendar.startOfWeek(for:)` derived
  the week from `.yearForWeekOfYear`/`.weekOfYear`, which anchors on the calendar's
  locale-dependent `firstWeekday` (Sunday in en_US). A Sunday therefore resolved to
  the *following* Monday, refilling all five unlocks a day early. Now counted back
  from the date's own weekday, which is locale-independent and DST-safe.
- **Crash starting a zero-length session.** All three duration wheels at 0 with
  Unlimited off passed a 0 interval to `UNTimeIntervalNotificationTrigger`, whose
  interval must be greater than zero. Sessions shorter than one second are now
  rejected and the lock buttons are disabled until a usable duration is set.
- **A lock could engage while blocking nothing.** Starting a session only checked
  Screen Time authorization, so with no apps selected the app showed the full "Phone
  Locked" screen, demanded an NFC tag to escape, and shielded nothing. Sessions now
  require at least one selected app.
- **A corrupted blocked-app list looked identical to an empty one.** A decode failure
  in `BlockedAppsStore` silently reset the selection, producing the same unenforced
  lock as above with no signal. The store now reports load failure separately and the
  session is refused with a message that says so.
- **"Lock Now" could strand a user holding a valid tag.** Remote sessions borrow
  `registeredChips[0]` as an identifier, and unlocking demanded that exact tag even
  though no tag started the session. Any registered tag now releases a remote session;
  NFC-started sessions still require the tag that started them.
- **Turning Screen Time off mid-session was invisible.** `reapplyShields()` no-opped
  silently while the UI kept showing an enforcing lock. The session is deliberately
  *not* ended, since that would make revoking Screen Time a one-tap bypass, but the
  lock screen now states that apps are no longer blocked.
- **Emergency unlock did nothing, visibly, once the budget was spent.** Tapping Unlock
  with zero remaining silently failed. It now explains that the budget resets Monday.
- **Invalid progress-bar geometry.** A zero-duration session made the lock screen
  progress width `NaN`. The fraction is now guarded and clamped.
- **Unlock notification claimed something untrue.** It read "Apps are now unlocked!",
  but nothing runs while the app is suspended, so the shields are still up when it
  fires. It now tells the user to open LemmeGo, which is what actually clears them.

### Added
- `PrivacyInfo.xcprivacy` declaring zero collected data types, no tracking, and the
  one required-reason API the app uses (`UserDefaults`, CA92.1). Without it, uploads
  draw an ITMS-91053 notice.
- `ITSAppUsesNonExemptEncryption = false` in `Info.plist`, so uploads stop pausing to
  ask about export compliance. The app performs no cryptography.
- `docs/TESTFLIGHT-EXTERNAL.md` with paste-ready Beta App Review copy, and
  `docs/privacy-policy.md`, which App Store Connect requires a URL for.
- Four regression tests pinning the Monday week boundary across every weekday, a
  Sunday-first calendar, and a month boundary. All four were confirmed to fail against
  the previous implementation.

### Changed
- The Settings About row reads `CFBundleShortVersionString` and `CFBundleVersion` from
  the bundle instead of a hardcoded literal, which had already gone stale once.
- `startLockSession` and `startRemoteLockSession` were near-identical copies; they now
  share one validated implementation and report a typed `LockStartFailure` so the UI
  can state the real reason a lock was refused instead of always blaming Screen Time.
- `UIRequiredDeviceCapabilities` corrected from `armv7` to `arm64`. The build system
  was already rewriting this at package time, so shipped behavior is unchanged.
- Removed `NSUserNotificationsUsageDescription`, which is not a real Info.plist key and
  described scheduled sessions, a feature the app does not have.

### Build & tooling
- **`DEVELOPMENT_TEAM` was empty**, so the project could not archive at all. Set to
  `5Y8S56DTEH`. Archive, App Store export, and distribution signing now all succeed.
- **The test suite never ran.** The shared scheme's `<Testables>` block was empty, so
  `Cmd+U` and `xcodebuild test` executed zero tests while reporting success. Wiring it
  up immediately surfaced the week-boundary bug above. 50 tests now run.
- The project builds with zero compiler warnings.

## [1.1.1] - 2026-08-18

### Fixed
- Xcode build failure ("Unexpected duplicate tasks"): `EmergencyUnlockSheet.swift` was registered in the project file as an entitlements plist instead of Swift source (introduced in #10), which generated duplicate bundle-copy tasks and kept the file from compiling. Corrected the file type; the app builds again.

## [1.1.0] - 2026-08-18

SemVer baseline established. Version taken as-is from the existing `MARKETING_VERSION` in the Xcode project (not bumped).

- Core NFC-triggered lock sessions, Screen Time app blocking, and the "Lock Now" hybrid remote lock built out
- Screen Time made a hard requirement (PR #6), removing earlier conditional support for devices without FamilyControls
- Emergency unlock system (5/week, Monday reset) added as a safety valve
- Unit test suite added and expanded (LockSession, NFCChip, EmergencyUnlockTracker, FormatTime, BlockedAppsStore) (#10, #12)
- Security / PII audit completed and repo cleared for public release (#11)
- Corrected a stale "App Version 1.0" literal shown on the Settings/About screen to match the shipped `MARKETING_VERSION`
- Still awaiting Apple Family Controls distribution entitlement approval before TestFlight/App Store release
