//
//  AppDelegate.swift
//  BetterOSD
//
//  Created by yu on 2025/9/23.
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_: Notification) {
        let currentShowInMenuBar = UserDefaults.standard.object(forKey: AppStorageKeys.showInMenuBar) as? Bool ?? true

        if currentShowInMenuBar {
            showStatusItem()
        }

        promptAccessibilityIfNeeded()
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        openSettings()
        return false
    }

    private func showStatusItem() {
        guard statusItem == nil else {
            return
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            let customIcon = NSImage(systemSymbolName: "iphone.pattern.diagonalline.on.rectangle.portrait.dashed", accessibilityDescription: "Better OSD")
            customIcon?.size = NSSize(width: 16, height: 16)
            button.image = customIcon
            button.target = self
        }

        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: NSLocalizedString("Settings", comment: ""),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title:
            NSLocalizedString("Quit", comment: ""),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    private func promptAccessibilityIfNeeded() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: AppStorageKeys.accessibilityPrompted) == nil {
            defaults.set(true, forKey: AppStorageKeys.accessibilityPrompted)
            print(MediaKeyMonitor.shared.hasAccessibilityPermission())
            guard !MediaKeyMonitor.shared.hasAccessibilityPermission() else { return }

            MediaKeyMonitor.shared.requestAccessibilityPermission()
        }
    }

    private func hideStatusItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingView = NSHostingView(rootView: settingsView)

            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 580, height: 580),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.contentView = hostingView
            settingsWindow?.center()
            settingsWindow?.isReleasedWhenClosed = false
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func updateMenuBarVisibility(visible: Bool) {
        if visible {
            showStatusItem()
        } else {
            hideStatusItem()
        }
    }

    func applicationWillTerminate(_: Notification) {
        MediaKeyMonitor.shared.stop()
    }
}
