# LemmeGo - Project History

## Project Overview
iOS app that helps users stay focused by locking their phone using NFC tags, blocking distracting apps via Apple's Screen Time API. Inspired by the Brick physical NFC phone locker.

## Key Context & Decisions

### Architecture
- **Platform:** Native iOS (Swift/SwiftUI)
- **Minimum iOS:** 16.0+ (required for Screen Time API)
- **Key Frameworks:**
  - FamilyControls/ManagedSettings (Screen Time API)
  - CoreNFC (tag reading)
  - UserNotifications
  - UserDefaults (data persistence)

### Core Features
1. **NFC Tag Locking** - Register and use NFC tags to start/end lock sessions
2. **App Blocking** - True app blocking via Screen Time API (not just UI lock)
3. **Two Lock Modes:**
   - **Timed sessions:** H:M:S duration picker (0-23h 59m 59s)
   - **Unlimited sessions:** Lock indefinitely until manual unlock
4. **Hybrid "Lock Now" Mode** - Start without NFC, still need NFC to unlock
5. **Emergency Unlock** - 5 uses per week (resets Monday)
6. **App Picker** - Select which apps to block during sessions
7. **Notifications** - Alert when session completes

### Major Decisions
1. **Use Screen Time API** - Real app blocking vs just UI overlay (more effective)
2. **Support multiple NFC tag types** - NTAG, MIFARE, ISO15693, FeliCa
3. **Limited emergency unlock** - Prevent abuse while allowing legitimate emergencies
4. **Accept known bypass methods** - Document that users can disable via iOS Settings
5. **Commitment tool, not enforcement** - Philosophy: help users help themselves
6. **Privacy-first** - All data stored locally, no transmission/cloud

### Technical Issues Resolved
- ✅ Fixed timer memory leak issues
- ✅ Removed debug print statements
- ✅ Fixed settings layout bugs
- ✅ Fixed countdown timer display issues
- ✅ Fixed NFC timeout handling
- ✅ Implemented unlimited duration mode
- ✅ Updated README with current features and limitations

## Current Status
🟡 **MOSTLY COMPLETE** - Functional but with known bugs and distribution blockers

### Known Bugs to Fix
1. **Notifications not appearing consistently** - Session completion notifications unreliable
2. **Deleting active NFC tag** - Leaves session unable to unlock (stuck state)
3. **Multiple rapid scans** - Might trigger duplicate sessions

### Distribution Blockers
- **Requires Apple approval** for Family Controls entitlement to distribute via TestFlight/App Store
- Currently works for development/personal use only

## Unfinished Work

### Bug Fixes Needed
- [ ] Fix notification reliability issues
- [ ] Handle active session when NFC tag is deleted (prevent stuck state)
- [ ] Prevent duplicate sessions from rapid NFC scans

### Potential Enhancements (Not Committed)
- Statistics and analytics for focus time tracking
- iOS Shortcuts integration
- Home Screen widgets
- Scheduled lock sessions
- Multiple app blocking profiles

## Important Notes

### Known Limitations (By Design)
- Users can bypass by:
  - Turning off Screen Time in iOS Settings
  - Revoking Screen Time access in Settings
  - Removing the app entirely
- These are **unavoidable and acceptable** - this is a commitment tool, not parental controls
- Unencrypted NFC tag numbers - not a real security issue (tags are meant to be shared/reused)
- Screen Time permission required for app to actually block apps
- App must remain installed for lock sessions to persist

### Security Philosophy
- Not meant to be unbreakable
- Helps users commit to focus, doesn't enforce it
- All "defeats" are documented and known
- No emergency unlock was removed as settings/uninstall cover emergency cases

### Competitive Analysis
- Compared with **Brick** (physical NFC locker device) - LemmeGo offers more customization
- Compared with **BePresent** app - Similar concept, analyzed features
- LemmeGo maintains simplicity while offering competitive feature set

## Technical Details
- Lock sessions persist through app restarts (UserDefaults)
- Glassmorphic UI design
- Support for multiple registered NFC tags
- Weekly emergency unlock counter (resets Monday)
- Tag deletion with confirmation dialogs
- Settings screen for app management
- Comprehensive README documentation

## Project Inspiration
- Brick app/device (physical NFC phone locker)
- Screen Time API capabilities for true app blocking
- Digital wellbeing and focus tools movement
