import SwiftUI
import BackgroundTasks
import UserNotifications
import WidgetKit
import ActivityKit

private let kBGTaskID        = "com.omari.morninghud.refresh"
private let kLastNotifiedKey = "last_notified_generated_at"

// Module-level singleton keeps the delegate alive for the full app lifetime
private let vegaNotificationDelegate = VegaBriefNotificationDelegate()

// MARK: - UNUserNotificationCenter delegate

private final class VegaBriefNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// Show banner + sound even when the app is in the foreground (sentinel alerts, brief)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// Route notification action taps
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == VegaMorningBrief.playAction {
            NotificationCenter.default.post(name: .vegaBriefPlay, object: nil)
        }
        completionHandler()
    }
}

private let kOnboardingKey = "onboarding_complete"

@main
struct HUBBYApp: App {
    @State private var store           = DashboardStore()
    @State private var vega            = VegaStore()
    @State private var showOnboarding  = !UserDefaults.standard.bool(forKey: kOnboardingKey)

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(store)
                .environment(vega)
                .fullScreenCover(isPresented: $showOnboarding) {
                    VegaOnboardingView {
                        UserDefaults.standard.set(true, forKey: kOnboardingKey)
                        showOnboarding = false
                    }
                }
        }
    }

    init() {
        GoogleSignInManager.shared.configure()
        VegaMorningBrief.registerCategory()
        UNUserNotificationCenter.current().delegate = vegaNotificationDelegate
        registerBackgroundTask()
        Task { await VegaAccountManager.shared.validateSession() }
    }

    // MARK: - Background task

    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: kBGTaskID, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handleBackgroundRefresh(refreshTask)
        }
    }

    private func handleBackgroundRefresh(_ task: BGAppRefreshTask) {
        scheduleNextBackgroundRefresh()

        let work = Task {
            let tempStore = await DashboardStore()
            await tempStore.refreshFromSnapshot()

            guard let snap = await tempStore.snapshot else {
                task.setTaskCompleted(success: false); return
            }

            let lastDate = UserDefaults.standard.object(forKey: kLastNotifiedKey) as? Date
            guard NotificationLogic.shouldNotify(newGeneratedAt: snap.generatedAt, lastNotifiedAt: lastDate) else {
                task.setTaskCompleted(success: true); return
            }

            WidgetCenter.shared.reloadAllTimelines()
            await tempStore.updateMorningBrief()

            let payload = SnapshotPayload(snapshot: snap)
            await VegaMorningBrief.generateAndPost(snapshot: payload)

            if let gen = snap.generatedAt {
                UserDefaults.standard.set(gen, forKey: kLastNotifiedKey)
            }
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = { work.cancel() }
    }

    private func scheduleNextBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: kBGTaskID)
        var comps   = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 6; comps.minute = 10
        if let today = Calendar.current.date(from: comps) {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
            request.earliestBeginDate = tomorrow
        }
        try? BGTaskScheduler.shared.submit(request)
    }

    @MainActor
    private func postNotification(title: String, body: String) async {
        let center   = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            return
        }
        let content   = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await center.add(req)
    }
}
