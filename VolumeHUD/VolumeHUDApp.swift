//
//  VolumeHUDApp.swift
//  VolumeHUD
//
//  Created by yu on 2025/9/23.
//

import SwiftUI

@main
struct VolumeHUDApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Volume HUD", image: ImageResource(name: "custom.waveform.low.square.fill", bundle: Bundle.main)) {
            StatusBarMenuView()
        }
        Settings {
            SettingsView()
                .navigationTitle("")
        }
    }
}
