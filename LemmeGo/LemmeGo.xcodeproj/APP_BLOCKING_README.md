# LemmeGo - App Blocking Implementation

## Overview

LemmeGo now includes full app blocking functionality using Apple's FamilyControls and ManagedSettings frameworks. Users can select specific apps, categories, and websites to block during focus sessions.

## What Was Implemented

### 1. **BlockedAppsStore** (`BlockedAppsStore.swift`)
- Manages the user's selection of apps to block
- Persists selections using `UserDefaults` and `FamilyActivitySelection`
- Provides methods to save and load the selection

### 2. **AppBlockingManager** (`AppBlockingManager.swift`)
- Handles Screen Time authorization
- Applies shields to selected apps, categories, and web domains
- Provides methods to block and unblock apps

### 3. **AppPickerView** (`AppPickerView.swift`)
- SwiftUI interface for selecting apps to block
- Uses `FamilyActivityPicker` for native app selection UI
- Shows summary of blocked items (apps, categories, websites)
- Allows clearing the selection

### 4. **LockManager Updates** (`LockManager.swift`)
- Automatically requests Screen Time authorization on app launch
- Integrates `BlockedAppsStore` and `AppBlockingManager`
- Blocks selected apps when lock session starts
- Unblocks apps when lock session ends

### 5. **Settings Integration** (`ContentView.swift`)
- Added "Blocked Apps" section in Settings
- Shows authorization status
- Button to manage blocked apps (opens `AppPickerView`)

## How It Works

1. **Authorization**: On first launch, the app requests Screen Time authorization
2. **Selection**: Users go to Settings → "Manage Blocked Apps" and select apps/categories
3. **Persistence**: Selections are saved and restored between app launches
4. **Blocking**: When an NFC lock session starts, the selected apps are blocked
5. **Unblocking**: When the session ends (timer expires or NFC tap), apps are unblocked

## Required Setup

### 1. Add Frameworks
In Xcode:
- Target → "Frameworks, Libraries, and Embedded Content"
- Add `FamilyControls.framework`
- Add `ManagedSettings.framework`

### 2. Add Capability
- Target → "Signing & Capabilities"
- Click "+ Capability"
- Add **"Family Controls"**

### 3. Add Privacy Description
Add to `Info.plist`:
```xml
<key>NSFamilyControlsUsageDescription</key>
<string>LemmeGo needs Screen Time access to block distracting apps during your focus sessions.</string>
```

## User Flow

### First Time Setup
1. User opens app
2. Screen Time authorization prompt appears
3. User approves
4. Settings shows "Screen Time Access ✅"

### Selecting Apps to Block
1. User goes to Settings (gear icon)
2. Taps "Manage Blocked Apps"
3. Taps "Select Apps to Block"
4. Native iOS picker appears with all apps
5. User selects apps, categories, or websites
6. Taps "Done"
7. Selection is saved automatically

### Using the Lock
1. User selects duration
2. User taps NFC chip
3. **Selected apps are now blocked**
4. User tries to open blocked app → Shield screen appears
5. Timer expires (or user taps NFC again)
6. **Apps are unblocked**

## Technical Details

### FamilyActivitySelection
The `FamilyActivitySelection` type stores three types of selections:
- `applicationTokens`: Individual apps
- `categoryTokens`: App categories (Social, Games, etc.)
- `webDomainTokens`: Specific websites

### ManagedSettingsStore
Applies shields using:
```swift
store.shield.applications = selection.applicationTokens
store.shield.applicationCategories = .specific(selection.categoryTokens)
store.shield.webDomains = selection.webDomainTokens
```

### Shield Screens
When a user tries to open a blocked app, iOS shows a system shield screen with:
- App icon
- "Restricted" message
- No way to bypass (system-level)

## Testing

1. **Test Authorization**:
   - Delete and reinstall app
   - Launch app
   - Verify authorization prompt appears

2. **Test App Selection**:
   - Go to Settings → Manage Blocked Apps
   - Select some apps (e.g., Instagram, Twitter)
   - Verify summary shows correct count

3. **Test Blocking**:
   - Start a lock session
   - Try to open a blocked app
   - Verify shield screen appears

4. **Test Unblocking**:
   - Wait for timer to expire (or tap NFC)
   - Try to open previously blocked app
   - Verify app opens normally

## Debugging

Check Xcode console for helpful logging:
- `✅` Success messages
- `❌` Error messages
- `⚠️` Warning messages
- `ℹ️` Info messages

Common issues:
- **No authorization prompt**: Check `Info.plist` has `NSFamilyControlsUsageDescription`
- **Apps not blocking**: Verify Screen Time is authorized (Settings UI)
- **Selection not persisting**: Check console for save/load errors

## Future Enhancements

Potential improvements:
- Quick presets (e.g., "Block Social Media")
- Per-chip app selections
- Time-based restrictions
- Usage statistics
- Integration with Shortcuts app

## References

- [FamilyControls Documentation](https://developer.apple.com/documentation/familycontrols)
- [ManagedSettings Documentation](https://developer.apple.com/documentation/managedsettings)
- [Screen Time API](https://developer.apple.com/documentation/screentime)
