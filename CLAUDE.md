# lemme-go — Claude Code Brief

## Product Vision

LemmeGo is a native iOS app that helps users maintain focus by locking their phone using NFC tags. Users tap an NFC tag to start a timed (or unlimited) lock session; selected apps are blocked via Apple's Screen Time API until the timer expires or the tag is scanned again. An emergency unlock system (5 uses/week, Monday reset) provides a safety valve for users who need to break focus.

**Status:** Feature complete, publicly released. Code passes security audit. Awaiting Apple Family Controls approval for TestFlight/App Store distribution.

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
| Remote lock (Lock Now button) | ✅ Complete | Hybrid: starts without NFC, still requires NFC to unlock |
| Emergency unlock (5/week, Monday reset) | ✅ Complete | Calendar-based week boundary using `startOfWeek()` extension |
| Unit tests | ✅ Complete | Test target configured; runs in Xcode |
| Security review | ✅ Complete | No PII, logging, or sensitive data; approved for public release |
| TestFlight/App Store | ⏸️ Pending | Requires Apple Family Controls distribution entitlement (separate request) |

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
- App crashes (gracefully) if Screen Time permission is revoked between sessions. Users must re-grant permission. Check authorization status before every lock start (LockManager:~55).

**4. Family Controls Distribution Entitlement**
- Development builds work immediately. TestFlight/App Store requires requesting Family Controls entitlement from Apple (separate request process). Approval can take days to weeks.

**5. LockManager is the Largest Class**
- Handles session lifecycle, timer management, persistence, and shield orchestration. Could benefit from extracting a `SessionPersistence` layer and a `ShieldOrchestrator` class. Not urgent (works fine now), but refactoring opportunity for future agents.

### Code Quality Notes

- **Logging:** Uses `print()` throughout. No structured logging. Consider adding os.log for future production analytics.
- **Persistence Keys:** Raw UserDefaults string literals scattered across code. Could centralize in a `UserDefaultsKeys` enum.
- **Test Coverage:** Good (emergency unlock, blocked apps, session persistence tested). NFC mocking works well; actual tag reading is device-only.

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