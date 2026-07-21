import SwiftUI

@main
struct NommacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            NommacMenu(model: appDelegate.model)
        } label: {
            NommacStatusLabel()
        }
        .menuBarExtraStyle(.window)
    }
}
