//
//  ModernVolumeHUDView.swift
//  BetterOSD
//
//  Created by yu on 2025/9/23.
//

import SwiftUI

struct ModernVolumeHUDView: View {
    let volumeState: VolumeState

    @AppStorage(AppStorageKeys.liquidGlassEnable) private var liquidGlassEnable: Bool = true
    @AppStorage(AppStorageKeys.glassVariant) private var glassVariant: Int = 0

    var body: some View {
        let content = HStack(spacing: 16) {
            // Volume icon
            Image(systemName: volumeState.iconName)
                .font(.system(size: 24, weight: .medium))
                .frame(width: 28)
                .foregroundStyle(.primary.opacity(liquidGlassEnable ? 0.6 : 1))
                .contentTransition(.symbolEffect(.replace))

            // Progress bar with ticks
            VStack(spacing: 4) {
                ModernVolumeProgressBar(
                    volumeState: volumeState
                )
                .frame(height: 4)

                ModernVolumeProgressTicks(
                    volumeState: volumeState
                )
                .frame(height: 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: 280, height: 64)

        if liquidGlassEnable {
            GlassEffectContainer(cornerRadius: 22, variant: glassVariant) {
                content
            }
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

struct ModernVolumeProgressBar: View {
    let volumeState: VolumeState

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(.primary.opacity(0.2))

                // Progress fill
                if !volumeState.isMuted, volumeState.volume > 0 {
                    Capsule()
                        .fill(.primary)
                        .frame(width: geometry.size.width * calculateVisualProgress())
                }
            }
        }
    }

    private func calculateVisualProgress() -> CGFloat {
        // Use volume directly for smooth progress bar fill
        // This supports both 16-step and 64-step (Shift+Option) adjustments
        CGFloat(volumeState.volume)
    }
}

struct ModernVolumeProgressTicks: View {
    let volumeState: VolumeState

    var body: some View {
        HStack(spacing: 0) {
            // 17 ticks for 16 volume steps (0%, 6.25%, 12.5%, ..., 100%)
            ForEach(0 ... VolumeCalculation.standardSteps, id: \.self) { index in
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(tickColor(for: index))
                        .frame(width: 1, height: tickHeight(for: index))
                }
                // Add spacer between ticks except after the last one
                if index < VolumeCalculation.standardSteps {
                    Spacer()
                }
            }
        }
    }

    private func tickColor(for index: Int) -> Color {
        let isActive = !volumeState.isMuted && VolumeCalculation.isTickActive(
            tickIndex: index,
            volume: volumeState.volume
        )
        return .primary.opacity(isActive ? 0.8 : 0.3)
    }

    private func tickHeight(for index: Int) -> CGFloat {
        // Every 4th tick is taller (at positions 0, 4, 8, 12, 16)
        index % 4 == 0 ? 6 : 4
    }
}

#Preview {
    VStack(spacing: 30) {
        ModernVolumeHUDView(volumeState: VolumeState(volume: 0.06, isMuted: false))
        ModernVolumeHUDView(volumeState: VolumeState(volume: 0.5, isMuted: false))
        ModernVolumeHUDView(volumeState: VolumeState(volume: 0.9, isMuted: false))
        ModernVolumeHUDView(volumeState: VolumeState(volume: 0.3, isMuted: true))
    }
    .padding(40)
    .background(.black.opacity(0.1))
}
