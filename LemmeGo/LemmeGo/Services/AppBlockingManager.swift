import Foundation

#if canImport(FamilyControls)
import FamilyControls
import ManagedSettings
import DeviceActivity

@available(iOS 16.0, *)
class AppBlockingManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var authorizationError: String?

    private let center = AuthorizationCenter.shared
    private let store = ManagedSettingsStore()

    init() {
        checkAuthorization()
    }

    // MARK: - Authorization

    func checkAuthorization() {
        switch center.authorizationStatus {
        case .approved:
            isAuthorized = true
        case .denied:
            isAuthorized = false
            authorizationError = "Screen Time permission was denied. Please enable it in Settings > Screen Time."
        case .notDetermined:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }

    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(for: .individual)
            await MainActor.run {
                checkAuthorization()
            }
        } catch {
            await MainActor.run {
                authorizationError = "Failed to authorize: \(error.localizedDescription)"
                isAuthorized = false
            }
        }
    }

    // MARK: - App Blocking

    func blockAllApps(except allowedBundleIDs: Set<String> = []) {
        guard isAuthorized else {
            authorizationError = "Not authorized for Screen Time. Please authorize first."
            return
        }

        // Block all applications except system apps and LemmeGo
        store.shield.applications = .all(except: allowedBundleIDs)

        // Also block app categories to be comprehensive
        store.shield.applicationCategories = .all()

        // Block web content during focus
        store.shield.webDomains = .all()

        print("✅ Apps blocked successfully")
    }

    func blockSpecificApps(_ bundleIDs: Set<String>) {
        guard isAuthorized else {
            authorizationError = "Not authorized for Screen Time. Please authorize first."
            return
        }

        // Block specific applications by bundle ID
        store.shield.applications = .specific(bundleIDs)

        print("✅ Specific apps blocked: \(bundleIDs)")
    }

    func unblockAllApps() {
        // Clear all shields
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil

        print("✅ All apps unblocked")
    }

    // MARK: - Helper Methods

    func getBlockedAppsCount() -> Int {
        // This would require querying the current shield configuration
        // For now, return 0 as placeholder
        return 0
    }

    // MARK: - Device Activity Scheduling (Optional)

    func scheduleDeviceActivity(for duration: TimeInterval, named: String) {
        // This requires DeviceActivityCenter and creating a schedule
        // More complex implementation for timed blocking
        let deviceActivityCenter = DeviceActivity.Center()

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: false
        )

        do {
            try deviceActivityCenter.startMonitoring(
                DeviceActivityName(named),
                during: schedule
            )
            print("✅ Device activity monitoring started")
        } catch {
            print("❌ Failed to start monitoring: \(error)")
            authorizationError = "Failed to schedule device activity: \(error.localizedDescription)"
        }
    }

    func stopDeviceActivity(named: String) {
        let deviceActivityCenter = DeviceActivity.Center()
        deviceActivityCenter.stopMonitoring([DeviceActivityName(named)])
        print("✅ Device activity monitoring stopped")
    }
}

// MARK: - App Blocking Status
struct AppBlockingStatus {
    var isBlocking: Bool
    var blockedAppsCount: Int
    var startTime: Date?
    var endTime: Date?
}

#else

// Fallback when FamilyControls is not available
@available(iOS 16.0, *)
class AppBlockingManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var authorizationError: String?

    init() {
        isAuthorized = false
        authorizationError = "FamilyControls framework not available"
    }

    func checkAuthorization() {
        isAuthorized = false
    }

    func requestAuthorization() async {
        authorizationError = "FamilyControls framework not available"
    }

    func blockAllApps(except allowedBundleIDs: Set<String> = []) {
        print("⚠️ App blocking not available - FamilyControls framework not linked")
    }

    func blockSpecificApps(_ bundleIDs: Set<String>) {
        print("⚠️ App blocking not available - FamilyControls framework not linked")
    }

    func unblockAllApps() {
        print("⚠️ App blocking not available - FamilyControls framework not linked")
    }
}

struct AppBlockingStatus {
    var isBlocking: Bool
    var blockedAppsCount: Int
    var startTime: Date?
    var endTime: Date?
}

#endif
