//
//  VolumeHUDWindow.swift
//  VolumeHUD
//
//  Created by yu on 2025/9/23.
//

import AppKit
import SwiftUI

class VolumeHUDWindow: NSPanel {
    private let hostingController: NSHostingController<VolumeHUDFactoryView>

    private static let windowWidth: CGFloat = 280
    private static let windowHeight: CGFloat = 200

    init() {
        let contentView = VolumeHUDFactoryView()
        hostingController = NSHostingController(rootView: contentView)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.windowWidth, height: Self.windowHeight),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupContent()
    }

    private func setupWindow() {
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = NSColor.clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true

        isExcludedFromWindowsMenu = true
    }

    func updatePosition() {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.frame
        let bottomOffset = (UserDefaults.standard.object(forKey: AppStorageKeys.bottomOffset) as? Double) ?? 120

        let x = screenFrame.minX + (screenFrame.width - Self.windowWidth) / 2
        let y = screenFrame.minY + bottomOffset

        setFrame(NSRect(x: x, y: y, width: Self.windowWidth, height: Self.windowHeight), display: false)
    }

    private func setupContent() {
        contentViewController = hostingController

        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
    }

    func showWithAnimation() {
        updatePosition()

        alphaValue = 0.0
        orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
    }

    func hideWithAnimation() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        } completionHandler: {
            Task { @MainActor [weak self] in
                self?.orderOut(nil)
            }
        }
    }
}
