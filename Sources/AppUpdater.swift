import AppKit
import Sparkle

/// One updater shared by the settings window and both application menus.
final class AppUpdater: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    private(set) var controller: SPUStandardUpdaterController!
    private var observations: [NSKeyValueObservation] = []
    var onChange: (() -> Void)?
    private(set) var status = "尚未检查更新"
    private(set) var availableVersion: String?
    private(set) var started = false

    var canCheckForUpdates: Bool { started && controller.updater.canCheckForUpdates }
    var automaticallyChecks: Bool { controller.updater.automaticallyChecksForUpdates }
    var currentVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "v\(version) (\(build))"
    }

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: self)
        observations = [
            controller.updater.observe(\.canCheckForUpdates) { [weak self] _, _ in self?.onChange?() },
            controller.updater.observe(\.automaticallyChecksForUpdates) { [weak self] _, _ in self?.onChange?() },
            controller.updater.observe(\.sessionInProgress) { [weak self] updater, _ in
                guard let self else { return }
                if updater.sessionInProgress && self.availableVersion == nil { self.status = "正在检查更新…" }
                self.onChange?()
            }
        ]
    }

    func start() {
        do {
            try controller.updater.start()
            started = true
        } catch {
            status = "更新服务启动失败：\(error.localizedDescription)"
        }
        onChange?()
    }

    @objc func checkForUpdates(_ sender: Any?) {
        guard canCheckForUpdates else { return }
        if availableVersion == nil { status = "正在检查更新…" }
        onChange?()
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(sender)
    }

    @objc func toggleAutomaticChecks(_ sender: NSButton) {
        controller.updater.automaticallyChecksForUpdates = sender.state == .on
        onChange?()
    }

    func makeMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "检查更新…", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        item.target = controller
        return item
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        availableVersion = "\(item.displayVersionString) (\(item.versionString))"
        status = "发现新版本 \(availableVersion!)"
        onChange?()
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        availableVersion = nil
        status = "暂无可用更新"
        onChange?()
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let failure = error as NSError
        if failure.domain == SUSparkleErrorDomain &&
            (failure.code == SUError.noUpdateError.rawValue || failure.code == SUError.installationCanceledError.rawValue) { return }
        status = "更新失败：\(error.localizedDescription)"
        onChange?()
    }

    // A menu-bar app shows scheduled discoveries in settings without stealing focus.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool { false }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        updater(controller.updater, didFindValidUpdate: update)
    }
}
