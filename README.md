# LemmeGo

An iOS app that helps you stay focused by locking your phone using NFC tags. Tap your NFC tag to lock your phone for a set duration and block distracting apps using Screen Time controls.

## Features

- **NFC-Powered Locking**: Use any NFC tag to lock your phone
- **Customizable Durations**: Choose lock periods from 15 minutes to 8 hours
- **App Blocking**: Block selected apps and websites during focus sessions using Screen Time API
- **Multiple Tags**: Register and manage multiple NFC tags
- **Lock Screen**: Full-screen lock interface that tracks session time
- **Persistent Sessions**: Lock sessions survive app restarts

## Requirements

- iOS 16.0 or later (required for Screen Time API)
- iPhone with NFC capability (iPhone 7 or newer)
- NFC tag (NTAG, MIFARE, ISO15693, or FeliCa)
- Apple Developer account (for building and running on device)
- **Screen Time Permission**: REQUIRED for app blocking functionality

## How It Works

1. Grant Screen Time permission (required for app blocking)
2. Select which apps you want to block during focus sessions
3. Register your NFC tag(s) in the app
4. Choose your desired lock duration (15 min - 8 hours)
5. Tap your phone to the NFC tag to start the lock session
6. Your phone enters lock mode and blocks selected apps
7. Tap the same tag again to unlock, or wait for the timer to expire

## Important: Screen Time Permission

**LemmeGo REQUIRES Screen Time permission to function.** This is not optional - without it, the app cannot block apps during focus sessions.

- You'll be prompted to grant Screen Time access on first launch
- This permission allows LemmeGo to use Apple's ManagedSettings framework to block apps
- The app only blocks apps YOU select during lock sessions
- LemmeGo does not collect or monitor any Screen Time data

## Setup Instructions

### 1. Get NFC Tags

You can use any of these NFC tag types:
- NTAG213/215/216 tags (most common, inexpensive)
- MIFARE Classic/Ultralight tags
- ISO15693 tags
- FeliCa tags

Available from:
- Amazon (search "NFC tags" or "NTAG213")
- AliExpress
- Local electronics stores
- Available as stickers, cards, or keychains

### 2. Build the App

#### Using Xcode:

1. Open the project:
   ```bash
   cd LemmeGo
   open LemmeGo.xcodeproj
   ```

2. In Xcode:
   - Select your development team in Signing & Capabilities
   - Change the bundle identifier if needed (currently `com.lemmego.app`)
   - Connect your iPhone
   - Select your iPhone as the build target
   - Click Run (⌘R)

#### Important Settings:

The app requires these capabilities:
- **Family Controls** - Required for Screen Time app blocking
- **NFC Tag Reading** - Required for NFC functionality

These are configured in:
- `LemmeGo.entitlements`: Family Controls and NFC Tag Reading enabled
- `Info.plist`: Usage descriptions for NFC and Family Controls
- Xcode project settings: Capabilities properly configured

### 3. Distribution to TestFlight/App Store

**IMPORTANT**: Family Controls capability requires special approval from Apple for distribution builds.

- Development builds work immediately (for testing on your device)
- TestFlight/App Store distribution requires requesting Family Controls entitlement from Apple
- Submit request at: https://developer.apple.com/contact/request/family-controls-distribution
- Explain your use case and wait for approval (can take several days to weeks)

### 4. First Launch

1. Launch the app on your iPhone
2. **CRITICAL**: Grant Screen Time permission when prompted
3. In Settings, select which apps you want to block during focus sessions
4. Tap "Register Your First Tag"
5. Hold your phone near your NFC tag
6. Give your tag a name (e.g., "Work Focus", "Study Time")
7. You're ready to start using LemmeGo!

## Usage

### Starting a Focus Session

1. Open the app
2. Select your desired lock duration using the wheel picker
3. Tap "Tap Tag to Lock"
4. Hold your phone near your registered NFC tag
5. The app enters lock mode and blocks your selected apps
6. A countdown timer shows remaining lock time

### Ending a Focus Session

**Normal Unlock:**
- Wait for the timer to expire, or
- Tap "Tap Tag to Unlock" and hold your phone near the same tag

### Managing Tags

1. Tap the "Settings" button on the home screen
2. View all registered tags
3. Tap "Register New Tag" to add more tags
4. Swipe left on any tag to delete it

### Managing Blocked Apps

1. Tap "Settings" on the home screen
2. Tap "Manage Blocked Apps"
3. Select the apps, categories, and websites you want to block
4. Your selections are saved automatically
5. These apps will be blocked during all future lock sessions

## Project Structure

```
LemmeGo/
├── LemmeGo.xcodeproj/      # Xcode project file
└── LemmeGo/
    ├── LemmeGoApp.swift    # App entry point
    ├── Info.plist          # App configuration
    ├── LemmeGo.entitlements # NFC + Family Controls permissions
    ├── Models/
    │   ├── LockSession.swift      # Lock session data model
    │   ├── BlockedAppsStore.swift # App selection storage
    │   └── NFCChip.swift          # NFC tag data model
    ├── Services/
    │   ├── NFCManager.swift           # NFC reading functionality
    │   ├── NFCChipStore.swift         # Tag registration & storage
    │   ├── LockManager.swift          # Lock session management
    │   └── AppBlockingManager.swift   # Screen Time API integration
    ├── Views/
    │   ├── ContentView.swift       # Main app view & settings
    │   ├── SetupView.swift         # First-run setup
    │   ├── LockScreenView.swift    # Lock mode UI
    │   ├── AppPickerView.swift     # App selection interface
    │   └── GlassmorphismComponents.swift # UI components
    └── Assets.xcassets/    # App icons and assets
```

## Technical Details

### Lock Mechanism

LemmeGo uses Apple's **Screen Time API** (FamilyControls framework) to block apps:
- Apps are blocked using `ManagedSettings` shields
- Blocks persist even if the app is closed or device restarts
- Only selected apps are blocked (not the entire phone)
- Blocks are automatically removed when the session ends

This is a **true app-blocking solution**, not just a UI lock.

### NFC Implementation

- Uses CoreNFC framework for reading NFC tags
- Supports multiple tag types: ISO7816, MIFARE, ISO15693, FeliCa
- Reads unique tag identifiers for registration
- Requires user-initiated NFC sessions (iOS security requirement)
- Protected against race conditions from multiple rapid scans

### Data Storage

- NFC tag registrations: Stored in UserDefaults
- App selection: Stored in UserDefaults
- Active lock sessions: Persisted to survive app restarts
- All data stays on device (backed up to iCloud with device backups)

## Known Issues and Limitations

### By Design / Unavoidable

These are intentional limitations or inherent to iOS that cannot be fixed:

1. **Bypass Methods Exist**
   - Users can bypass the lock by going to iOS Settings and:
     - Disabling Screen Time entirely
     - Revoking Screen Time permission from LemmeGo
     - Deleting the LemmeGo app
   - **Why this exists**: iOS does not allow apps to prevent users from managing system settings
   - **Intended use**: LemmeGo is a commitment tool, not parental controls. It works through intentional friction, not forcing
   - **Protection**: The app checks Screen Time permission every time you scan a tag. If permission was revoked, you'll see an error message and the lock will not start

2. **System Time Bypass**
   - Users can bypass the lock by changing the device time forward in iOS Settings
   - **Why this exists**: Apps cannot access secure time sources or prevent time changes
   - **Mitigation**: This requires enough effort that it breaks the focus commitment

3. **Force Quit / Device Restart Behavior**
   - If the app is force-quit or device restarts while locked:
     - App blocks persist until the app is reopened
     - Timer continues counting down but won't auto-unlock until app reopens
   - **Why this exists**: iOS terminates background timers when apps are force-quit
   - **Impact**: Apps stay blocked as intended, but won't auto-unlock at expiration until app is opened
   - **Workaround**: Open the app to check remaining time or unlock

4. **TestFlight/App Store Distribution Limitation**
   - Family Controls requires Apple's special approval for distribution
   - Development builds work fine for personal use
   - Public distribution requires submitting request to Apple
   - **Why this exists**: Apple restricts Screen Time API to prevent abuse
   - **Impact**: Cannot distribute widely without Apple approval

### Active Bugs

1. **Deleting Active NFC Tag**
   - If you delete an NFC tag while it's being used for an active lock session:
     - You cannot unlock with that tag anymore
     - You must wait for the timer to expire
   - **Workaround**: Don't delete tags during active sessions

2. **Multiple Rapid Scans** (Partially Fixed)
   - Tapping a tag multiple times very quickly could potentially restart the session
   - **Mitigation**: Added guard to prevent multiple simultaneous scans
   - **Remaining risk**: Very rapid successive scans might still trigger multiple sessions

### Privacy Notes

- NFC tag IDs are permanent hardware identifiers stored on your device
- These IDs are stored in UserDefaults (unencrypted)
- They're backed up to iCloud with your device backups
- LemmeGo does not transmit any data over the network
- Screen Time permission grants visibility to installed apps (but LemmeGo doesn't monitor usage)

## "Emergency" Unlock

There is **no built-in emergency unlock button**. This is intentional - the lock is meant to help you commit to focus time.

If you absolutely need to unlock early:
1. **Wait for timer to expire** (recommended)
2. Go to iOS Settings > Screen Time and disable it entirely
3. Go to iOS Settings > Screen Time > LemmeGo and revoke permission
4. Delete the LemmeGo app

These methods require enough friction that they break the commitment, but are available if truly needed.

## Troubleshooting

### NFC Not Working

- Ensure you're testing on a physical iPhone (NFC doesn't work in Simulator)
- Check that NFC is enabled (Settings > General > NFC - if option exists)
- Hold the phone with the top near the NFC tag (NFC antenna is at the top)
- Try removing any thick phone case

### Apps Not Being Blocked

- **CHECK FIRST**: Did you grant Screen Time permission?
- Go to Settings in LemmeGo and verify the green checkmark next to "Screen Time Access"
- If not authorized, tap "Enable Screen Time" and grant permission
- Ensure you've selected apps to block in "Manage Blocked Apps"
- Restart the lock session after configuring blocked apps

### Build Errors

- Ensure you have a valid development team selected
- Check that Family Controls and NFC capabilities are properly configured
- Update to the latest Xcode version
- Clean build folder (Product > Clean Build Folder)

### Tag Not Registering

- Some NFC tags may be damaged or incompatible
- Try a different tag to verify the app works
- Check that your tag is one of the supported types (NTAG, MIFARE, ISO15693, FeliCa)

## Future Enhancements

Possible improvements:
- [ ] Fix deletion of active tags (prevent deletion or handle gracefully)
- [ ] Statistics and analytics (focus time tracking)
- [ ] Shortcuts integration for automation
- [ ] Widget showing active lock status
- [ ] Scheduled focus sessions
- [ ] Achievement system for motivation
- [ ] Better handling of force-quit scenarios

## Privacy

- No data is collected or transmitted over the network
- All information stays on your device (backed up to iCloud)
- No analytics or tracking
- No internet connection required
- Screen Time permission is only used for app blocking, not monitoring

## License

This project is provided as-is for personal use and learning.

## Credits

Inspired by the Brick app - a physical NFC-based phone locking solution.

## Contributing

This is a learning project. Feel free to fork and modify for your own use!
