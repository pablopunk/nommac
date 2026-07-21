import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = NommacModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }
}
