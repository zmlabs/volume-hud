//
//  BetterOSDApp.swift
//  BetterOSD
//
//  Created by yu on 2025/9/23.
//

import AppKit

@main
struct App {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
