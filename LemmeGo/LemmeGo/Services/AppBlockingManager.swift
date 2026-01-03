import Foundation
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

        // Check again after a delay to ensure authorization status is fully loaded
        // This fixes an issue where authorization status may not be immediately available on app launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkAuthorization()
        }
    }

    // MARK: - Authorization

    func checkAuthorization() {
        switch center.authorizationStatus {
        case .approved:
            isAuthorized = true
        case .denied:
            isAuthorized = false
            authorizationError = "Screen Time permission was denied. LemmeGo requires Screen Time access to function. Please enable it in Settings > Screen Time."
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
            authorizationError = "Not authorized for Screen Time. LemmeGo cannot function without this permission."
            return
        }

        // Block all applications except system apps and LemmeGo
        // Note: To block all apps, we need to use FamilyActivitySelection
        // For now, we'll use specific blocking approach
        store.shield.applications = nil // Reset first
        store.shield.applicationCategories = .all(except: Set())
        store.shield.webDomains = nil
    }

    func blockSpecificApps(_ tokens: Set<ApplicationToken>) {
        guard isAuthorized else {
            authorizationError = "Not authorized for Screen Time. LemmeGo cannot function without this permission."
            return
        }

        // Block specific applications by token
        store.shield.applications = tokens
    }

    func blockSelectedApps(_ selection: FamilyActivitySelection) {
        // Always check authorization status before blocking (fixes race condition on app launch)
        checkAuthorization()

        guard isAuthorized else {
            authorizationError = "Not authorized for Screen Time. LemmeGo cannot function without this permission."
            return
        }

        // Block the selected apps, categories, and web domains
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    func unblockAllApps() {
        print("🔓 AppBlockingManager.unblockAllApps() called")
        // Clear all shields
        store.shield.applications = nil
        print("   ✅ Cleared applications shield")
        store.shield.applicationCategories = nil
        print("   ✅ Cleared applicationCategories shield")
        store.shield.webDomains = nil
        print("   ✅ Cleared webDomains shield")
        print("🔓 All shields cleared!")
    }

    // MARK: - Device Activity Scheduling

    func scheduleDeviceActivity(for duration: TimeInterval, named: String) {
        let deviceActivityCenter = DeviceActivityCenter()

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
        } catch {
            authorizationError = "Failed to schedule device activity: \(error.localizedDescription)"
        }
    }

    func stopDeviceActivity(named: String) {
        let deviceActivityCenter = DeviceActivityCenter()
        deviceActivityCenter.stopMonitoring([DeviceActivityName(named)])
    }
}
