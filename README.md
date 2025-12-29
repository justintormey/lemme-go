# LemmeGo

An iOS app that helps you stay focused by locking your phone using NFC chips, similar to the Brick app. Tap your NFC chip to lock your phone for a set duration and eliminate distractions.

## Features

- **NFC-Powered Locking**: Use any NFC chip or tag to lock your phone
- **Customizable Durations**: Choose lock periods from 15 minutes to 8 hours
- **Multiple Chips**: Register and manage multiple NFC chips
- **Lock Screen**: Full-screen lock interface that prevents app access during focus time
- **Emergency Unlock**: Safety feature for urgent situations
- **Persistent Sessions**: Lock sessions survive app restarts

## How It Works

1. Register your NFC chip(s) in the app
2. Select how long you want to focus (15 min - 8 hours)
3. Tap your phone to the NFC chip to start the lock
4. Your phone enters focus mode with a lock screen
5. Tap the same chip again to unlock, or wait for the timer to expire

## Requirements

- iOS 16.0 or later
- iPhone with NFC capability (iPhone 7 or newer)
- NFC chip or tag (NTAG, MIFARE, ISO15693, FeliCa)
- Apple Developer account (for building and running on device)

## Setup Instructions

### 1. Get NFC Chips

You can use any of these NFC chip types:
- NTAG213/215/216 tags (most common, inexpensive)
- MIFARE Classic/Ultralight tags
- ISO15693 tags
- FeliCa tags

Available from:
- Amazon (search "NFC tags" or "NTAG213")
- AliExpress
- Local electronics stores
- Tile stickers, cards, or keychains

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

The app requires NFC capabilities. Make sure these are configured:
- In `LemmeGo.entitlements`: NFC Tag Reading is enabled
- In `Info.plist`: `NFCReaderUsageDescription` is set
- In Xcode project settings: Near Field Communication Tag Reading capability is added

### 3. First Launch

1. Launch the app on your iPhone
2. Follow the setup wizard
3. Tap "Register Your First Chip"
4. Hold your phone near your NFC chip
5. Give your chip a name (e.g., "Work Focus", "Study Time")
6. You're ready to start using LemmeGo!

## Usage

### Starting a Focus Session

1. Open the app
2. Select your desired lock duration using the wheel picker
3. Tap "Tap NFC Chip to Lock"
4. Hold your phone near your registered NFC chip
5. The app will enter lock mode with a countdown timer

### Ending a Focus Session

**Normal Unlock:**
- Wait for the timer to expire, or
- Tap "Tap Chip to Unlock" and hold your phone near the same chip

**Emergency Unlock:**
- Tap "Emergency Unlock" on the lock screen
- Confirm you want to end the session early

### Managing Chips

1. Tap the settings gear icon
2. View all registered chips
3. Register new chips with the "+" button
4. Swipe to delete chips you no longer use

## Project Structure

```
LemmeGo/
├── LemmeGo.xcodeproj/      # Xcode project file
└── LemmeGo/
    ├── LemmeGoApp.swift    # App entry point
    ├── Info.plist          # App configuration
    ├── LemmeGo.entitlements # NFC permissions
    ├── Models/
    │   └── LockSession.swift      # Lock session and chip data models
    ├── Services/
    │   ├── NFCManager.swift       # NFC reading functionality
    │   ├── NFCChipStore.swift     # Chip registration & storage
    │   └── LockManager.swift      # Lock session management
    ├── Views/
    │   ├── ContentView.swift      # Main app view & navigation
    │   ├── SetupView.swift        # First-run setup experience
    │   └── LockScreenView.swift   # Lock mode UI
    └── Assets.xcassets/    # App icons and assets
```

## Technical Details

### NFC Implementation

- Uses CoreNFC framework for reading NFC tags
- Supports multiple tag types: ISO7816, MIFARE, ISO15693, FeliCa
- Reads unique chip identifiers for registration
- Requires user-initiated NFC sessions (iOS security requirement)

### Lock Mechanism

The current implementation provides a UI-based lock that:
- Displays a full-screen lock interface
- Tracks session time with a timer
- Persists lock state across app restarts
- Requires the same NFC chip to unlock

**Note:** This is a "soft lock" that relies on user commitment. For a true phone-wide lock, you would need:
- Screen Time API integration (requires special entitlements)
- Guided Access Mode automation (limited by iOS)
- MDM (Mobile Device Management) for enterprise deployments

The current approach works well for users who want a focus tool with intentional friction, similar to how the original Brick app works.

### Data Storage

- NFC chip registrations: Stored in UserDefaults
- Active lock sessions: Persisted to survive app restarts
- All data stays on device (no cloud sync)

## Troubleshooting

### NFC Not Working

- Ensure you're testing on a physical iPhone (NFC doesn't work in Simulator)
- Check that NFC is enabled on your device (Settings > General > NFC)
- Make sure the app has NFC permissions in Settings > Privacy > NFC
- Hold the phone with the top near the NFC chip (NFC antenna is at the top)
- Try removing any thick phone case

### Build Errors

- Ensure you have a valid development team selected
- Check that NFC capabilities are properly configured
- Update to the latest Xcode version
- Clean build folder (Product > Clean Build Folder)

### Chip Not Registering

- Some NFC chips may be write-protected or damaged
- Try a different chip to verify the app works
- Check that your chip is one of the supported types

## Future Enhancements

Possible improvements:
- [ ] Statistics and analytics (focus time tracking)
- [ ] Shortcuts integration for automation
- [ ] Widget showing active lock status
- [ ] Different lock modes (block specific apps vs. full lock)
- [ ] Scheduled focus sessions
- [ ] Achievement system for motivation
- [ ] iCloud sync for multiple devices

## Privacy

- No data is collected or transmitted
- All information stays on your device
- No analytics or tracking
- No internet connection required

## License

This project is provided as-is for personal use and learning.

## Credits

Inspired by the Brick app - a physical NFC-based phone locking solution.

## Contributing

This is a learning project. Feel free to fork and modify for your own use!
