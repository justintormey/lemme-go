# lemme-go — Claude Code Brief

## Product Vision

LemmeGo is a native iOS app that helps users maintain focus by locking their phone using NFC tags. Users tap an NFC tag to start a timed (or unlimited) lock session; selected apps are blocked via Apple's Screen Time API until the timer expires or the tag is scanned again. An emergency unlock system (5 uses/week, Monday reset) provides a safety valve for users who need to break focus.

**Status:** v1.2.0. Feature complete, publicly released, security audited. The Family Controls **distribution** entitlement is GRANTED (verified 2026-09-02 by a successful App Store archive + export). TestFlight is unblocked apart from a privacy policy URL. See `docs/TESTFLIGHT-EXTERNAL.md` and `docs/QA-2026-09-02.md`.

## Tech Stack

- **Language:** Swift (iOS 16.0+)
- **UI Framework:** SwiftUI (glassmorphism design)
- **Core APIs:** CoreNFC, FamilyControls, ManagedSettings, UserNotifications
- **State Management:** ObservableObject (no Redux/Redux alternatives)
- **Persistence:** UserDefaults (no CoreData, no external databases)
- **Dependencies:** None — pure Apple frameworks only

## Project Structure

```
LemmeGo/
├── LemmeGo/
│   ├── LemmeGoApp.swift                      # App entry point
│   ├── Models/
│   │   ├── BlockedAppsStore.swift            # @ObservableObject for Screen Time selections
│   │   ├── LockSession.swift                 # Codable session model, UserDefaults persistence
│   │   └── (EmergencyUnlockTracker in Views/)
│   ├── Services/
│   │   ├── LockManager.swift                 # Core session lifecycle, timer, persistence, shields
│   │   ├── NFCManager.swift                  # NFC scanning and tag reading
│   │   ├── NFCChipStore.swift                # @ObservableObject for registered NFC tags
│   │   └── AppBlockingManager.swift          # ManagedSettings shield orchestration
│   └── Views/
│       ├── ContentView.swift                 # Home screen (duration picker, Lock Now, NFC Lock buttons)
│       ├── LockScreenView.swift              # Full-screen lock UI with countdown
│       ├── SetupView.swift                   # First-run NFC tag registration
│       ├── AppPickerView.swift               # Screen Time app selection
│       ├── EmergencyUnlockSheet.swift        # Emergency unlock modal + safety warning
│       ├── EmergencyUnlockTracker.swift      # @ObservableObject for weekly unlock budget
│       └── GlassmorphismComponents.swift     # Reusable glassmorphic UI components
├── LemmeGoTests/
│   ├── BlockedAppsStoreTests.swift
│   ├── EmergencyUnlockTrackerTests.swift
│   ├── FormatTimeTests.swift
│   ├── LockSessionTests.swift
│   └── NFCChipTests.swift
└── (Xcode project files, entitlements, Info.plist — capabilities pre-configured)

docs/
├── blog-post-lemmego.md                      # PENDING: Blog post about the project
└── security-audit-2026-04-15.md              # Public release security review (passed)
```

## Current Status

| Component | Status | Notes |
|-----------|--------|-------|
| NFC tag reading & lock triggering | ✅ Complete | Device only; no Simulator support |
| Screen Time app blocking | ✅ Complete | `ManagedSettingsStore("LemmeGoShields")` persists across restarts |
| Timed + unlimited sessions | ✅ Complete | Hour/Minute/Second wheel pickers (0–23h 59m 59s) |
| Remote lock (Lock Now button) | ✅ Complete | Hybrid: starts without NFC; any **registered** tag unlocks it (an NFC-started session still needs its own tag) |
| Emergency unlock (5/week, Monday reset) | ✅ Complete | `startOfWeek()` counts back from the date's own weekday. Do NOT reintroduce `.weekOfYear`: it anchors on locale `firstWeekday` and doubled the budget every Sunday |
| Unit tests | ✅ 50 passing | Target AND scheme `<Testables>` both wired. Zero ran before 2026-09-02 |
| Security review | ✅ Complete | No PII, logging, or sensitive data; approved for public release |
| TestFlight/App Store | ✅ Unblocked | Family Controls distribution entitlement granted; archive + App Store export verified. Needs a privacy policy URL before external testing. |

## Key Decisions & Architecture Notes

### State Management: ObservableObject Everywhere
All state lives in observable objects: `LockManager`, `NFCManager`, `NFCChipStore`, `AppBlockingManager`, `BlockedAppsStore`, `EmergencyUnlockTracker`. Views react to changes automatically.

### Persistence: UserDefaults + PropertyList Encoding
- **Sessions, NFC chips, app selections, emergency unlock records** all stored in UserDefaults.
- **PropertyListEncoder** for `FamilyActivitySelection` opaque tokens (JSON encoding corrupted them; see commit d24969c).
- **No migration burden** — UserDefaults strings as keys throughout. No centralized key registry (tech debt).

### Screen Time is REQUIRED, Not Optional
Early versions had conditional logic for devices without FamilyControls. Removed in PR #6. App has no purpose without app blocking. Users *must* grant Screen Time permission on first launch.

### Named ManagedSettingsStore
Shields are stored in a named store (`"LemmeGoShields"`) so they survive process termination and survive app restarts. Unlocking removes shields; locking re-applies them.

### Hybrid Remote Lock ("Lock Now" Button)
Users can start a lock session immediately without scanning an NFC tag (`LockManager.startLockSession(isRemote: true)`), but still *require* NFC to unlock. Provides convenience without removing commitment friction.

### Emergency Unlock Budget: 5/Week, Monday Reset
`Calendar.startOfWeek()` extension ensures the week boundary is consistent. Prevents users from getting truly stuck while maintaining focus commitment. Resets every Monday.

### Zero External Dependencies
No CocoaPods, SPM, or third-party frameworks. Simplifies distribution, build reproducibility, and reduces supply-chain risk.

## Agent Notes

### ⚠️ Pitfalls & Constraints

**1. NFC Only Works on Physical Devices**
- No Simulator support. Testing requires an iPhone 7+ with NFC. Unit tests mock NFC; integration testing requires hardware.

**2. iCloud Storage Causes Build Failures**
- Do NOT store the repo in iCloud Drive. File sync conflicts corrupt git refs and cause mysterious build failures. Use local disk only.

**3. Screen Time Permission is Critical**
- A session refuses to start unless Screen Time is authorized AND at least one app is selected; `validateSessionStart()` returns a typed `LockStartFailure` the UI renders. Revoking Screen Time mid-session does NOT end the session (that would be a one-tap bypass); the lock screen states that apps are no longer blocked.
- Derive authorization from the status raw value, never an exhaustive case list. iOS 26.4 added `.approvedWithDataAccess`, which fell into `@unknown default` and disabled locking entirely.

**4. Family Controls Distribution Entitlement — GRANTED, do not re-request**
- This was listed as pending for months. It is not. Verified 2026-09-02: `xcodebuild archive` plus `-exportArchive -exportOptionsPlist method=app-store-connect` produces a distribution-signed IPA whose embedded profile (`iOS Team Store Provisioning Profile: com.lemmego.app`) carries `com.apple.developer.family-controls` and `beta-reports-active`.
- `DEVELOPMENT_TEAM` must stay set to `5Y8S56DTEH`. It was empty, which made archiving impossible and is what made the entitlement look like the blocker.

**4b. The scheme must keep its `<Testables>` entry**
- The shared scheme once had an empty `<Testables>` block, so `Cmd+U` ran zero tests and reported success for months. That hid a live week-boundary bug sitting in an already-committed test. If tests ever "pass" suspiciously fast, check the scheme before believing them.

**5. LockManager is the Largest Class**
- Handles session lifecycle, timer management, persistence, and shield orchestration. Could benefit from extracting a `SessionPersistence` layer and a `ShieldOrchestrator` class. Not urgent (works fine now), but refactoring opportunity for future agents.

### Code Quality Notes

- **Logging:** Uses `print()` throughout. No structured logging. Consider adding os.log for future production analytics.
- **Persistence Keys:** Raw UserDefaults string literals scattered across code. Could centralize in a `UserDefaultsKeys` enum.
- **Test Coverage:** Model-level only. `LockManager` and `AppBlockingManager` are untested because they need Screen Time; session restore and shield teardown, the highest-risk paths, have no coverage. Tests also write to `UserDefaults.standard`, so running them wipes real app data on that simulator. See `docs/QA-2026-09-02.md` O6/O7.

### Common Modifications

**To add a new app-blocking rule:**
1. Update `BlockedAppsStore.swift` to store the rule.
2. Update `AppBlockingManager.swift` to apply/unapply the rule to `ManagedSettingsStore`.
3. Update Views to expose the rule in the UI.

**To change emergency unlock budget:**
- `EmergencyUnlockTracker.swift` (the constant and the reset logic).

**To modify lock duration limits:**
- `ContentView.swift` (the wheel picker ranges).

**To add new NFC tag capabilities:**
- `NFCManager.swift` (reading logic) → `NFCChipStore.swift` (storage) → `LockManager.swift` (lock logic).

### Docs & Resources

- `docs/blog-post-lemmego.md` — PENDING: Draft blog post for justintormey.com (about the project, how it was built, Screen Time API approval experience).
- `docs/security-audit-2026-04-15.md` — Full security review (passed; public release ready).
- `README.md` — User setup and feature guide.
- `history.md` — Full technical history and architecture.
---

## Versioning — Semantic Versioning (mandatory)

This project follows [Semantic Versioning 2.0.0](https://semver.org/): `MAJOR.MINOR.PATCH`. Any agent/LLM making changes here MUST bump the version automatically as part of the change — never wait to be asked.

- **MAJOR** — breaking change: removed/renamed capability, incompatible API/CLI/schema/data-format/UX change
- **MINOR** — new backward-compatible functionality
- **PATCH** — backward-compatible bug fix, perf tweak, copy correction
- Docs-only or internal-refactor changes with no behavior change: no bump
- Pre-1.0 (`0.y.z`): breaking → MINOR, everything else → PATCH; new projects start at `0.1.0`

In the SAME commit as the change, update the version everywhere it appears:
1. **Source of truth** — whatever this repo uses (`package.json`, `VERSION`, `Info.plist`/`project.yml` `MARKETING_VERSION`, `pyproject.toml`, site footer constant). If none exists yet, create a root `VERSION` file at `0.1.0`.
2. **Documentation** — add a `CHANGELOG.md` entry (create the file if missing); update README/docs anywhere a version is stated.
3. **User interface** — not every UI displays a version and that's fine; never add one where none exists. Any surface that already shows a version (About screen, footer, settings, CLI `--version`) must be correct — reading from the single source of truth, never a second hardcoded copy.
4. **GitHub** — tag the release commit `vX.Y.Z` and push the tag with the branch (GitHub Releases for MAJOR/MINOR on repos that use them).
