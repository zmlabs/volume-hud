//
//  BetterOSDFactoryView.swift
//  BetterOSD
//
//  Created by yu on 2025/9/23.
//

import Combine
import SwiftUI

/// A SwiftUI view that automatically switches between different HUD styles based on user settings
struct BetterOSDFactoryView: View {
    @AppStorage(AppStorageKeys.hudStyle) private var hudStyle: HUDStyle = .modern
    @AppStorage(AppStorageKeys.liquidGlassEnable) private var liquidGlassEnable: Bool = true
    @AppStorage(AppStorageKeys.glassVariant) private var glassVariant: Int = 0

    @State private var volumeState: VolumeState = .init()

    var body: some View {
        ZStack {
            switch hudStyle {
            case .classic:
                ClassicVolumeHUDView(volumeState: volumeState, liquidGlassEnable: liquidGlassEnable, glassVariant: glassVariant)
            case .modern:
                ModernVolumeHUDView(volumeState: volumeState, liquidGlassEnable: liquidGlassEnable, glassVariant: glassVariant)
            }
        }
        .frame(width: HUDLayout.contentSize.width, height: HUDLayout.contentSize.height)
        .padding(HUDLayout.windowInset)
        .onAppear {
            volumeState = VolumeMonitor.shared.currentVolumeState
        }
        .onReceive(VolumeMonitor.shared.volumeChangePublisher.receive(on: RunLoop.main)) {
            volumeState = $0
        }
    }
}
