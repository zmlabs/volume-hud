//
//  StatusBarMenuView.swift
//  VolumeHUD
//
//  Created by yu on 2025/9/23.
//

import SwiftUI

struct StatusBarMenuView: View {
    @Environment(\.openSettings) var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button("Settings") {
                openSettings()
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(.vertical, 4)
    }
}
