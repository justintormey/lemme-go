# Timer Unlock Bug - Fix Plan

## Executive Summary

The app has critical bugs preventing automatic unlock when the timer expires. Apps remain blocked by Screen Time restrictions even after the session ends, particularly when the app is backgrounded or terminated.

---

## 🐛 Critical Bugs Identified

### Bug #1: App Restart/Termination Doesn't Unblock Apps

**Location:** `LemmeGo/LemmeGo/Services/LockManager.swift:21-27` (init method)

**Current Code:**
```swift
loadSession()
if let session = currentSession, session.isActive {
    startLock()
} else {
    currentSession = nil
    setAppIcon(to: nil)  // ❌ Missing unblockAllApps() call!
}
```

**Problem Description:**
1. User starts a lock session (e.g., 1 hour)
2. Apps get blocked via Screen Time API
3. App is terminated or backgrounded
4. Timer expires while app is closed
5. User reopens app after timer expires
6. `init()` loads the expired session and sets `currentSession = nil`
7. **NEVER calls `unblockAllApps()`** ❌

**Impact:** Apps remain blocked indefinitely even though session has expired.

**Severity:** CRITICAL

---

### Bug #2: Timer Doesn't Fire in Background

**Location:** `LemmeGo/LemmeGo/Services/LockManager.swift:65` (Timer in startLock)

**Current Code:**
```swift
timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
    guard let self = self else { return }

    if let session = self.currentSession {
        if !session.isActive {
            self.endLockSession()
        }
    }
}
```

**Problem Description:**
iOS suspends `Timer` objects when the app enters background state. The timer will not fire while the app is backgrounded, even if the session expires.

**Impact:** Apps remain blocked until user brings app to foreground.

**Severity:** HIGH

---

### Bug #3: No Background Task Management

**Location:** Missing entirely from codebase

**Problem Description:**
The app has no mechanism to handle sessions that expire while backgrounded. iOS provides:
- Background tasks for finite-length operations
- Background app refresh
- Silent push notifications
- **None are currently implemented**

**Impact:** No reliability guarantee for background session expiration.

**Severity:** MEDIUM

---

## 📋 Implementation Plan

### Phase 1: Fix Critical App Restart Bug (HIGHEST PRIORITY)

**Estimated Effort:** 30 minutes
**Risk Level:** Low
**Impact:** Solves 90% of the problem

#### Changes Required

**File:** `LemmeGo/LemmeGo/Services/LockManager.swift`

**1. Modify `init()` method:**

```swift
init() {
    // Initialize app blocking manager on iOS 16+
    if #available(iOS 16.0, *) {
        appBlockingManager = AppBlockingManager()
    }

    loadSession()
    if let session = currentSession {
        if session.isActive {
            // Session is still active - resume lock
            startLock()
        } else {
            // Session expired while app was closed - clean up properly!
            print("⚠️ Found expired session on app launch - cleaning up")
            endLockSession()  // This will unblock apps
        }
    } else {
        // No session - ensure clean state
        setAppIcon(to: nil)
    }
}
```

**Why This Works:**
- When app restarts with an expired session, it calls `endLockSession()`
- `endLockSession()` properly calls `unblockAllApps()`
- Screen Time restrictions are removed
- Session cleanup is consistent whether timer fires or app restarts

---

### Phase 2: Add App Lifecycle Monitoring

**Estimated Effort:** 45 minutes
**Risk Level:** Low
**Impact:** Ensures responsive unlock on app foreground

#### Changes Required

**File:** `LemmeGo/LemmeGo/Services/LockManager.swift`

**1. Add lifecycle observer in `init()`:**

```swift
init() {
    // Initialize app blocking manager on iOS 16+
    if #available(iOS 16.0, *) {
        appBlockingManager = AppBlockingManager()
    }

    loadSession()
    if let session = currentSession {
        if session.isActive {
            startLock()
        } else {
            print("⚠️ Found expired session on app launch - cleaning up")
            endLockSession()
        }
    } else {
        setAppIcon(to: nil)
    }

    // Monitor app lifecycle events
    setupLifecycleObservers()
}

private func setupLifecycleObservers() {
    // Check session when app comes to foreground
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleAppWillEnterForeground),
        name: UIApplication.willEnterForegroundNotification,
        object: nil
    )

    // Optional: Pause timer when app goes to background
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleAppDidEnterBackground),
        name: UIApplication.didEnterBackgroundNotification,
        object: nil
    )
}

@objc private func handleAppWillEnterForeground() {
    print("📱 App entering foreground - checking session status")

    // Check if session expired while app was backgrounded
    if let session = currentSession, !session.isActive {
        print("⚠️ Session expired while backgrounded - ending session")
        endLockSession()
    }
}

@objc private func handleAppDidEnterBackground() {
    print("📱 App entering background - session will continue")
    // Timer is automatically suspended by iOS
    // Session will be checked when app returns to foreground
}

deinit {
    NotificationCenter.default.removeObserver(self)
}
```

**Why This Helps:**
- When user brings app to foreground, immediately check if session expired
- Ensures apps get unblocked even if timer didn't fire in background
- Provides responsive unlock when user returns to app
- Works for all session durations

---

### Phase 3: Background Execution Support (Optional Enhancement)

**Estimated Effort:** 1 hour
**Risk Level:** Medium
**Impact:** Limited (iOS only provides ~30 seconds of background time)

#### Changes Required

**File:** `LemmeGo/LemmeGo/Services/LockManager.swift`

**1. Add background task support:**

```swift
import UIKit

class LockManager: ObservableObject {
    // ... existing properties ...

    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    func startLockSession(chipId: String, duration: TimeInterval) {
        let session = LockSession(chipId: chipId, duration: duration)
        currentSession = session
        saveSession()
        startLock()
        setAppIcon(to: "AppIcon-Locked")

        // Block apps - this is REQUIRED functionality
        if #available(iOS 16.0, *), let blockingManager = appBlockingManager {
            if blockingManager.isAuthorized {
                let currentAppBundle = Bundle.main.bundleIdentifier ?? "com.lemmego.app"
                blockingManager.blockAllApps(except: [currentAppBundle])
            } else {
                print("❌ Screen Time not authorized - app blocking will not work")
            }
        }

        // Request background execution time
        requestBackgroundTime()
    }

    private func requestBackgroundTime() {
        // Only request if not already running
        guard backgroundTask == .invalid else { return }

        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "LockSessionMonitoring") {
            // Timeout handler (called after ~30 seconds)
            print("⚠️ Background time expired - ending background task")
            self.endBackgroundTask()
        }

        print("✅ Background task started: \(backgroundTask.rawValue)")
    }

    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
            print("✅ Background task ended")
        }
    }

    func endLockSession() {
        // End background task first
        endBackgroundTask()

        // Unblock apps
        if #available(iOS 16.0, *), let blockingManager = appBlockingManager {
            blockingManager.unblockAllApps()
        }

        currentSession = nil
        isLocked = false
        timer?.invalidate()
        timer = nil
        clearSession()
        setAppIcon(to: nil)
    }
}
```

**Limitations:**
- iOS only provides ~30 seconds of background execution
- Not suitable for long sessions (hours)
- Better than nothing for short sessions (15-30 minutes)
- Not a complete solution, but provides some coverage

---

### Phase 4: Local Notifications (User Communication)

**Estimated Effort:** 45 minutes
**Risk Level:** Low
**Impact:** Improves user experience and reliability

#### Changes Required

**File:** `LemmeGo/LemmeGo/Services/LockManager.swift`

**1. Add notification support:**

```swift
import UserNotifications

class LockManager: ObservableObject {
    // ... existing code ...

    func startLockSession(chipId: String, duration: TimeInterval) {
        let session = LockSession(chipId: chipId, duration: duration)
        currentSession = session
        saveSession()
        startLock()
        setAppIcon(to: "AppIcon-Locked")

        // Block apps
        if #available(iOS 16.0, *), let blockingManager = appBlockingManager {
            if blockingManager.isAuthorized {
                let currentAppBundle = Bundle.main.bundleIdentifier ?? "com.lemmego.app"
                blockingManager.blockAllApps(except: [currentAppBundle])
            }
        }

        // Schedule unlock notification
        scheduleUnlockNotification(for: duration)
    }

    private func scheduleUnlockNotification(for duration: TimeInterval) {
        // Cancel any existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()
        content.title = "LemmeGo"
        content.body = "Your focus session has ended. Apps are now unlocked!"
        content.sound = .default
        content.categoryIdentifier = "UNLOCK"

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: duration,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "session-unlock",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error)")
            } else {
                print("✅ Unlock notification scheduled for \(duration) seconds")
            }
        }
    }

    func endLockSession() {
        // Cancel notification since session ended manually or automatically
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        // ... rest of existing code ...
    }
}
```

**2. Request notification permissions (add to `LemmeGoApp.swift`):**

```swift
@main
struct LemmeGoApp: App {
    @StateObject private var lockManager = LockManager()
    @StateObject private var nfcManager = NFCManager()
    @StateObject private var chipStore = NFCChipStore()

    init() {
        // Request notification permissions
        requestNotificationPermissions()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(lockManager)
                .environmentObject(nfcManager)
                .environmentObject(chipStore)
        }
    }

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permissions granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error)")
            }
        }
    }
}
```

**Benefits:**
- User gets notified when session ends
- Works even if app is terminated
- Encourages user to open app, triggering the init() cleanup
- Provides clear feedback about session status

---

## 🧪 Testing Plan

### Test Case 1: App Termination During Active Session

**Steps:**
1. Start a 5-minute lock session
2. Verify apps are blocked
3. Force quit the app (swipe up in app switcher)
4. Wait 6 minutes (session expires)
5. Reopen the app

**Expected Result:**
- ✅ Apps are unblocked immediately on app open
- ✅ App icon returns to unlocked state
- ✅ Console shows "Found expired session on app launch - cleaning up"
- ✅ No active session in UI

**Priority:** CRITICAL

---

### Test Case 2: App Backgrounded During Active Session

**Steps:**
1. Start a 3-minute lock session
2. Verify apps are blocked
3. Background the app (home button/gesture)
4. Wait 4 minutes (session expires)
5. Bring app to foreground

**Expected Result:**
- ✅ Apps are unblocked when app enters foreground
- ✅ Console shows "Session expired while backgrounded - ending session"
- ✅ App icon returns to unlocked state

**Priority:** HIGH

---

### Test Case 3: Normal Timer Expiration (App Active)

**Steps:**
1. Start a 2-minute lock session
2. Keep app in foreground
3. Wait for timer to expire

**Expected Result:**
- ✅ Apps are unblocked automatically at expiration
- ✅ UI updates to show unlocked state
- ✅ Timer fires correctly
- ✅ No console errors

**Priority:** HIGH

---

### Test Case 4: Manual Unlock Before Expiration

**Steps:**
1. Start a 10-minute lock session
2. Verify apps are blocked
3. Manually end session (if UI provides this option)

**Expected Result:**
- ✅ Apps are unblocked immediately
- ✅ Timer is invalidated
- ✅ Session cleared from UserDefaults

**Priority:** MEDIUM

---

### Test Case 5: Notification Delivery

**Steps:**
1. Ensure notification permissions are granted
2. Start a 1-minute lock session
3. Background the app
4. Wait for session to expire

**Expected Result:**
- ✅ Notification appears at session end time
- ✅ Notification content is correct
- ✅ Tapping notification opens app with unlocked state

**Priority:** MEDIUM

---

## 🎯 Recommended Implementation Order

### Immediate (Critical Path)

1. **Phase 1** - Fix App Restart Bug
   - Modify `init()` to call `endLockSession()` for expired sessions
   - Test thoroughly with app termination scenarios
   - This alone solves the critical issue

### Short Term (This Week)

2. **Phase 2** - Add Lifecycle Monitoring
   - Add foreground/background observers
   - Test with backgrounding scenarios
   - Ensures responsive unlock on foreground

3. **Phase 4** - Add Local Notifications
   - Request notification permissions
   - Schedule notifications on session start
   - Improves user experience significantly

### Optional (Future Enhancement)

4. **Phase 3** - Background Execution
   - Only if needed for short sessions
   - Limited value due to iOS restrictions
   - Consider skipping if Phase 1 + 2 + 4 work well

---

## 📝 Implementation Checklist

### Phase 1: Critical Fix
- [ ] Modify `LockManager.init()` to handle expired sessions
- [ ] Add logging for expired session detection
- [ ] Test: Force quit during active session
- [ ] Test: Reopen after expiration
- [ ] Verify apps are unblocked
- [ ] Commit changes

### Phase 2: Lifecycle Monitoring
- [ ] Add `setupLifecycleObservers()` method
- [ ] Implement `handleAppWillEnterForeground()`
- [ ] Implement `handleAppDidEnterBackground()`
- [ ] Add `deinit` to remove observers
- [ ] Test: Background during active session
- [ ] Test: Return to foreground after expiration
- [ ] Commit changes

### Phase 4: Notifications
- [ ] Import UserNotifications framework
- [ ] Add `scheduleUnlockNotification()` method
- [ ] Request notification permissions in app init
- [ ] Cancel notifications on manual unlock
- [ ] Test: Notification appears at correct time
- [ ] Test: Notification content is correct
- [ ] Commit changes

---

## ⚠️ Known Limitations

1. **iOS Background Restrictions**
   - Timers don't fire in background
   - Background execution limited to ~30 seconds
   - No way to force unlock while app is completely inactive

2. **Workarounds Implemented**
   - Phase 1: Cleanup on app restart handles most cases
   - Phase 2: Foreground check catches backgrounding scenarios
   - Phase 4: Notifications prompt user to open app

3. **User Experience Impact**
   - Apps may remain blocked for a few extra minutes if user doesn't open app
   - This is acceptable given iOS limitations
   - Notification helps minimize this delay

---

## 📚 Related Files

- `LemmeGo/LemmeGo/Services/LockManager.swift` - Main file to modify
- `LemmeGo/LemmeGo/Services/AppBlockingManager.swift` - Handles Screen Time API
- `LemmeGo/LemmeGo/Models/LockSession.swift` - Session model with `isActive` property
- `LemmeGo/LemmeGo/LemmeGoApp.swift` - App entry point for notification permissions

---

## 🔍 Code Review Notes

### Current Code Analysis

**File:** `LockManager.swift:48-60`

The `endLockSession()` method is correctly implemented:
```swift
func endLockSession() {
    // Unblock apps
    if #available(iOS 16.0, *), let blockingManager = appBlockingManager {
        blockingManager.unblockAllApps()  // ✅ Correct
    }

    currentSession = nil
    isLocked = false
    timer?.invalidate()
    timer = nil
    clearSession()
    setAppIcon(to: nil)
}
```

The issue is NOT with this method - it's that this method **doesn't get called** in certain scenarios (app termination with expired session).

---

## 🚀 Success Criteria

After implementing all phases, the following must be true:

1. ✅ Apps ALWAYS unblock when session expires
2. ✅ Works whether app is active, backgrounded, or terminated
3. ✅ User receives notification at session end
4. ✅ App icon reflects correct lock state
5. ✅ No apps remain blocked indefinitely
6. ✅ All test cases pass
7. ✅ No console errors or warnings

---

## 📞 Support Information

If issues persist after implementation:

1. Check console logs for:
   - "Found expired session on app launch"
   - "Session expired while backgrounded"
   - "All apps unblocked"

2. Verify Screen Time permissions are granted

3. Check UserDefaults for stale session data:
   ```swift
   // Debug command to check stored session
   if let data = UserDefaults.standard.data(forKey: "currentLockSession") {
       print("Stored session exists: \(data)")
   }
   ```

---

**Document Version:** 1.0
**Date Created:** 2025-01-03
**Last Updated:** 2025-01-03
**Author:** Claude (Sonnet 4.5)
