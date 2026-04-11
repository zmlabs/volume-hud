import AppKit
import ObjectiveC

extension NSMenuItem {
    static func disableAutoIcons() {
        guard let original = class_getInstanceMethod(NSMenuItem.self, #selector(getter: image)),
              let replacement = class_getInstanceMethod(NSMenuItem.self, #selector(nilImage))
        else { return }
        method_exchangeImplementations(original, replacement)
    }

    @objc private func nilImage() -> NSImage? {
        nil
    }
}
