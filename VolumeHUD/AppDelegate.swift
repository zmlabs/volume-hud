//
//  AppDelegate.swift
//  VolumeHUD
//
//  Created by yu on 2025/9/23.
//

import AppKit
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private let volumeHUDWindowManager = VolumeHUDWindowManager()

    func applicationDidFinishLaunching(_: Notification) {}
}
