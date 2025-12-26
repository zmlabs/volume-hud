//
//  HUDPreviewManager.swift
//  VolumeHUD
//
//  Created by zenni on 2025/12/27.
//

import Combine
import Foundation

class HUDPreviewManager: ObservableObject {
    static let shared = HUDPreviewManager()

    @Published var isPreviewActive: Bool = false
    @Published var bottomOffset: Double = 120

    private init() {}
}
