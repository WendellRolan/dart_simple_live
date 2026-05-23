import Cocoa
import FlutterMacOS

@NSApplicationMain
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let bundleIdentifier = Bundle.main.bundleIdentifier {
      let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
      let existingApp = NSRunningApplication
        .runningApplications(withBundleIdentifier: bundleIdentifier)
        .first { $0.processIdentifier != currentProcessIdentifier }

      if let existingApp = existingApp {
        existingApp.activate(options: [.activateAllWindows])
        NSApp.terminate(nil)
        return
      }
    }

    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
}
