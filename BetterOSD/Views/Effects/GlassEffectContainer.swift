//
//  GlassEffectContainer.swift
//  BetterOSD
//
//  Created by yu on 2026/1/5.
//

import AppKit
import SwiftUI

struct GlassEffectContainer<Content: View>: NSViewRepresentable {
    let cornerRadius: CGFloat
    let style: NSGlassEffectView.Style
    let tintColor: NSColor?
    let variant: Int
    let content: Content

    init(
        cornerRadius: CGFloat = 28,
        style: NSGlassEffectView.Style = .regular,
        tintColor: NSColor? = nil,
        variant: Int = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.style = style
        self.tintColor = tintColor
        self.variant = variant
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(rootView: content)
    }

    func makeNSView(context: Context) -> NSGlassEffectView {
        let glassView = NSGlassEffectView(frame: .zero)
        glassView.cornerRadius = cornerRadius
        glassView.style = style
        glassView.tintColor = tintColor

        let hostingView = context.coordinator.hostingView
        hostingView.frame = glassView.bounds
        hostingView.autoresizingMask = [.width, .height]
        glassView.contentView = hostingView

        GlassEffectPrivateAPI.applyVariant(variant, to: glassView)
        return glassView
    }

    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        nsView.cornerRadius = cornerRadius
        nsView.style = style
        nsView.tintColor = tintColor
        context.coordinator.hostingView.rootView = content
        context.coordinator.hostingView.frame = nsView.bounds
        GlassEffectPrivateAPI.applyVariant(variant, to: nsView)
    }

    final class Coordinator {
        let hostingView: NSHostingView<Content>

        init(rootView: Content) {
            hostingView = NSHostingView(rootView: rootView)
        }
    }
}
