//
//  GlassEffectPrivateAPI.swift
//  BetterOSD
//
//  Created by yu on 2026/1/5.
//

import AppKit

enum GlassEffectPrivateAPI {
    static func applyVariant(_ variant: Int, to view: NSGlassEffectView) {
        guard variant >= 0 else { return }
        setPrivateInt(view, selectors: ["set_variant:", "_setVariant:", "setVariant:"], value: variant)
    }

    private static func setPrivateInt(_ view: AnyObject, selectors: [String], value: Int) {
        for name in selectors {
            let selector = Selector(name)
            guard view.responds(to: selector) else { continue }
            typealias MsgSend = @convention(c) (AnyObject, Selector, Int) -> Void
            guard let method = view.method(for: selector) else { continue }
            let fn = unsafeBitCast(method, to: MsgSend.self)
            fn(view, selector, value)
            break
        }
    }
}
