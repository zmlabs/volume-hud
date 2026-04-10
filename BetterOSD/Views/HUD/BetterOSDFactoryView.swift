//
//  BetterOSDFactoryView.swift
//  BetterOSD
//
//  Created by yu on 2025/9/23.
//

import Combine
import SwiftUI

struct BetterOSDFactoryView: View {
    @AppStorage(AppStorageKeys.hudStyle) private var hudStyle: HUDStyle = .modern
    @AppStorage(AppStorageKeys.liquidGlassEnable) private var liquidGlassEnable: Bool = true
    @AppStorage(AppStorageKeys.glassVariant) private var glassVariant: Int = 0

    @State private var displayState = HUDDisplayStateStore.shared.current

    var body: some View {
        ZStack {
            switch hudStyle {
            case .classic:
                ClassicHUDView(displayState: displayState, liquidGlassEnable: liquidGlassEnable, glassVariant: glassVariant)
            case .modern:
                ModernHUDView(displayState: displayState, liquidGlassEnable: liquidGlassEnable, glassVariant: glassVariant)
            }
        }
        .frame(width: HUDLayout.contentSize.width, height: HUDLayout.contentSize.height)
        .padding(HUDLayout.windowInset)
        .onAppear {
            displayState = HUDDisplayStateStore.shared.current
        }
        .onReceive(HUDDisplayStateStore.shared.publisher.receive(on: RunLoop.main)) {
            displayState = $0
        }
    }
}
