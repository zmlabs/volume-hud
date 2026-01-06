//
//  HUDPreviewManager.swift
//  BetterOSD
//
//  Created by yu on 2025/12/27.
//

@preconcurrency import Combine
import Foundation

class HUDPreviewManager: ObservableObject {
    static let shared = HUDPreviewManager()

    @Published var isPreviewActive: Bool = false
    @Published var bottomOffset: Double = 120

    private init() {}
}
