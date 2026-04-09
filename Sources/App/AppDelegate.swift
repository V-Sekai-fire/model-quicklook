import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentRect = NSRect(x: 0, y: 0, width: 480, height: 200)
        let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        window.title = "VRM QuickLook"
        window.center()

        let label = NSTextField(wrappingLabelWithString:
            "VRM QuickLook is installed.\n" +
            "Select any .vrm file in Finder and press Space to preview it."
        )
        label.alignment = .center
        label.frame = NSRect(x: 20, y: 60, width: 440, height: 80)
        window.contentView?.addSubview(label)
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        true
    }
}
