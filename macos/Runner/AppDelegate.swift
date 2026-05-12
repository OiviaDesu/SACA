import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
    let bundleIdentifier = Bundle.main.bundleIdentifier
    let existingApplication = NSWorkspace.shared.runningApplications.first {
      $0.bundleIdentifier == bundleIdentifier &&
        $0.processIdentifier != currentProcessIdentifier
    }

    if let existingApplication {
      existingApplication.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
      NSApp.terminate(nil)
      return
    }

    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
