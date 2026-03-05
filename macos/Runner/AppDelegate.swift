import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      for window in sender.windows {
        if window.contentViewController is FlutterViewController {
          window.makeKeyAndOrderFront(self)
          NSApp.activate(ignoringOtherApps: true)
          break
        }
      }
    }
    return true
  }
}
