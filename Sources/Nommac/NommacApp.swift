import SwiftUI

@main
struct NommacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            NommacMenu(model: appDelegate.model)
        } label: {
            NommacStatusLabel(model: appDelegate.model)
        }
        .menuBarExtraStyle(.window)
    }
}
