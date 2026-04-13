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
| Unit tests | ✅ Complete — test suite + Xcode target configured (#10) |
| TestFlight / App Store | ⏸️ Requires Apple Family Controls approval |

## Unfinished Work

### Immediate Next Steps
- Expand test coverage to `BlockedAppsStore` (requires mocking FamilyActivitySelection)

### Future Enhancements
- Fix deletion of active NFC tags (prevent or handle gracefully)
- Focus time statistics/analytics
- Shortcuts integration
- Lock status widget
- Scheduled focus sessions
- Achievement system

## Important Notes

- **Development must be on local disk, NOT iCloud.** iCloud sync causes build failures and file corruption.
- **NFC only works on physical devices** — no Simulator support.
- **Family Controls distribution entitlement** required for TestFlight/App Store — must be requested from Apple separately.
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

### Build
```bash
open LemmeGo/LemmeGo.xcodeproj
# Select device target (NFC requires physical iPhone)
# Cmd+R to run, Cmd+U to test (once test target is configured)
```
