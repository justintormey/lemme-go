# LemmeGo - Project History

## Project Overview

LemmeGo is a native iOS (SwiftUI) app that uses NFC tags to enforce phone-locking focus sessions. Users tap an NFC tag to start a timed (or unlimited) lock session; selected apps are blocked via Apple's Screen Time API (FamilyControls/ManagedSettings) until the timer expires or the tag is scanned again. An emergency unlock system (5/week, resets Monday) provides a safety valve.

**Tech stack:** Swift, SwiftUI, CoreNFC, FamilyControls, ManagedSettings, UserNotifications  
**Min target:** iOS 16.0  
**License:** MIT

## Key Context & Decisions

### Architecture
- **ObservableObject pattern** for all state: `LockManager`, `NFCManager`, `NFCChipStore`, `AppBlockingManager`, `BlockedAppsStore`, `EmergencyUnlockTracker`
- **UserDefaults persistence** for sessions, chips, blocked app selections, and emergency unlock records. No CoreData or external DB.
- **Named ManagedSettingsStore** (`"LemmeGoShields"`) ensures app-blocking shields survive process termination.
- **No dependency manager** — zero external dependencies. Pure Apple frameworks only.

### Major Decisions
- **Screen Time is REQUIRED, not optional.** Early versions had conditional compilation to support devices without FamilyControls; this was removed in favor of making Screen Time a hard requirement (PR #6). The app has no purpose without app blocking.
- **PropertyListEncoder for FamilyActivitySelection.** JSON encoding corrupted opaque Screen Time tokens. Switched to PropertyList encoding with legacy JSON migration fallback (commit d24969c).
- **Hybrid remote lock.** "Lock Now" button starts a session without NFC scan, but still requires NFC to unlock. Provides convenience without weakening the commitment mechanism.
- **Emergency unlock limit: 5/week, Monday reset.** Balances safety (never truly locked out) with commitment friction. Uses `Calendar.startOfWeek()` extension for week boundary calculation.

### Known Technical Debt
- `LockManager` is the largest class — handles session lifecycle, timer, persistence, shield orchestration, and lifecycle observers. Could benefit from extracting a `SessionPersistence` layer.
- Logging via `print()` throughout. No structured logging.
- All persistence uses raw UserDefaults keys as string literals. No centralized key registry.

## Current Status

| Area | Status |
|------|--------|
| Core NFC locking | ✅ Complete |
| Screen Time integration | ✅ Complete |
| Unlimited sessions | ✅ Complete |
| Remote lock (Lock Now) | ✅ Complete |
| Emergency unlock | ✅ Complete |
| UI (Glassmorphism) | ✅ Complete |
| Unit tests | ✅ 50 passing — target AND scheme `<Testables>` wired (the scheme entry was missing until 2026-09-02, so zero tests actually ran) |
| Security / PII audit | ✅ Complete — repo cleared for public release (#11) |
| TestFlight / App Store | ✅ Unblocked — entitlement granted, archive + export verified 2026-09-02 (needs privacy policy URL) |

## Unfinished Work

### Immediate Next Steps
1. **Device QA of v1.2.0.** Nothing in the 2026-09-02 QA pass has run on an iPhone. The two most important fixes (iOS 26.4 Screen Time authorization, and the Monday week boundary) are both in paths that only execute on real hardware with Screen Time granted.
2. **Publish a privacy policy and get a URL.** App Store Connect will not accept an external TestFlight submission without one. Text is written and ready at `docs/privacy-policy.md`; suggested home is `demo.justintormey.com/lemmego/privacy/`.
3. **Decide on the DeviceActivityMonitor extension** (QA report O1). Shields stay applied past a session's end while the app is backgrounded, which is the normal way to use it. Self-heals when the user opens the app, and the notification copy no longer lies about it, but the real fix is a new app extension target.
4. **Decide whether clock manipulation matters** (QA report O2). Rolling the device clock forward ends any timed session and refills an exhausted emergency budget, both in about fifteen seconds. Arguably out of scope for a commitment device aimed at a willing user.

### Future Enhancements
- Inject `UserDefaults` into `BlockedAppsStore` / `EmergencyUnlockTracker` so tests stop wiping real app data, and so `LockManager` session-restore and shield-teardown become testable (QA O6/O7)
- Lock-screen copy telling the user that deleting the app clears the shields, shown when the emergency budget hits zero (QA O4)
- Fix deletion of active NFC tags (prevent or handle gracefully)
- Focus time statistics/analytics
- Shortcuts integration
- Lock status widget
- Scheduled focus sessions
- Achievement system

## Important Notes

- **v1.2.0 (2026-09-02) was a full QA pass.** 11 audit dimensions, 46 findings, 28 confirmed after adversarial verification. Read `docs/QA-2026-09-02.md` before touching session lifecycle, Screen Time authorization, or the week boundary; several of those bugs are the kind that look like working code.
- **The Family Controls distribution entitlement is GRANTED.** This file claimed otherwise for months. The real blocker was an empty `DEVELOPMENT_TEAM` in the project file, which stopped archiving before the entitlement was ever exercised.
- **A passing test run is not evidence tests ran.** The shared scheme's `<Testables>` block was empty, so the suite reported success while executing nothing, hiding a live bug inside an already-committed test.
- **Development must be on local disk, NOT iCloud.** iCloud sync causes build failures and file corruption.
- **NFC only works on physical devices** — no Simulator support.
- **Family Controls distribution entitlement is GRANTED.** Long recorded here as pending; verified granted on 2026-09-02 by producing a distribution-signed App Store IPA. The actual blocker had been an empty `DEVELOPMENT_TEAM` in the project file, not Apple.
- Screen Time permission is checked on every tag scan. If revoked between sessions, the lock will refuse to start with an error message.

## Technical Details

### Data Flow
```
User taps NFC tag
  → NFCManager extracts chip ID
  → NFCChipStore validates registration
  → LockManager.startLockSession()
    → Checks Screen Time authorization
    → Creates LockSession (persisted to UserDefaults)
    → Starts 1-second timer
    → BlockedAppsStore.reloadSelection()
    → AppBlockingManager.blockSelectedApps()
    → Schedules unlock notification
```

### Test Suite (added in #10)
Tests located in `LemmeGo/LemmeGoTests/`:
- `LockSessionTests` — timed/unlimited session computed properties, Codable migration
- `NFCChipTests` — model encoding, NFCChipStore CRUD and persistence
- `EmergencyUnlockTrackerTests` — weekly limit enforcement, persistence, Calendar.startOfWeek
- `FormatTimeTests` — LockManager.formatTime() edge cases
- `BlockedAppsStoreTests` — empty selection state, plist save/load round-trip, corrupted-data recovery, reloadSelection

### Build
```bash
open LemmeGo/LemmeGo.xcodeproj
# Select device target (NFC requires physical iPhone)
# Cmd+R to run, Cmd+U to test (once test target is configured)
```
