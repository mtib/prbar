import AppKit
import PRBarCore
import UserNotifications

enum NotificationPayload {
    static let urlKey = "prURL"
}

/// Posts one banner per newly-arrived review request; tapping it opens the PR.
@MainActor
struct Notifier {
    /// `UNUserNotificationCenter` traps when there is no bundle, which happens if the binary is
    /// run straight out of `.build` instead of the assembled `.app`.
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : .current()
    }

    func requestAuthorization() async {
        guard let center else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func post(_ pullRequest: PullRequest, isDirect: Bool) async {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(pullRequest.repo) #\(pullRequest.number)"
        content.subtitle = isDirect ? "Review requested from you" : "Team review requested"
        content.body = pullRequest.title
        content.userInfo = [NotificationPayload.urlKey: pullRequest.url.absoluteString]
        content.sound = .default

        try? await center.add(
            UNNotificationRequest(identifier: pullRequest.id, content: content, trigger: nil)
        )
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let target = (userInfo[NotificationPayload.urlKey] as? String).flatMap(URL.init(string:)) {
            Task { @MainActor in NSWorkspace.shared.open(target) }
        }
        completionHandler()
    }
}
