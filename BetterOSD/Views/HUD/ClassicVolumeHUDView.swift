//
//  ClassicVolumeHUDView.swift
//  BetterOSD
//
//  Created by yu on 2025/9/23.
//

import SwiftUI

struct ClassicVolumeHUDView: View {
    let volumeState: VolumeState

    @AppStorage(AppStorageKeys.liquidGlassEnable) private var liquidGlassEnable: Bool = true
    @AppStorage(AppStorageKeys.glassVariant) private var glassVariant: Int = 0

    var body: some View {
        let content = VStack(spacing: 0) {
            VStack {
                Image(systemName: volumeState.iconName)
                    .font(.system(size: 72, weight: .regular))
                    .foregroundStyle(.primary.opacity(liquidGlassEnable ? 0.6 : 1))
                    .contentTransition(
                        .symbolEffect(.replace)
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ClassicVolumeProgressBar(
                volumeState: volumeState
            )
            .padding(.bottom, 16)
        }
        .frame(width: 200, height: 200)

        if liquidGlassEnable {
            GlassEffectContainer(cornerRadius: 16, variant: glassVariant) {
                content
            }
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct ClassicVolumeProgressBar: View {
    let volumeState: VolumeState

    private static let segmentCount = 16

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0 ..< Self.segmentCount, id: \.self) { index in
                VolumeSegment(
                    fillRatio: fillRatio(for: index),
                    isActive: !volumeState.isMuted
                )
            }
        }
    }

    private func fillRatio(for index: Int) -> CGFloat {
        guard !volumeState.isMuted else { return 0 }
        return VolumeCalculation.segmentFillRatio(
            segmentIndex: index,
            volume: volumeState.volume
        )
    }
}

private struct VolumeSegment: View {
    let fillRatio: CGFloat
    let isActive: Bool

    private static let size: CGFloat = 8
    private static let cornerRadius: CGFloat = 1

    var body: some View {
        Rectangle()
            .fill(.secondary.opacity(0.3))
            .overlay(alignment: .leading) {
                if fillRatio > 0, isActive {
                    Rectangle()
                        .fill(.primary)
                        .frame(width: Self.size * fillRatio)
                        .clipped()
                }
            }
            .frame(width: Self.size, height: Self.size)
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
    }
}

#Preview {
    VStack(spacing: 30) {
        // Display precise volume adjustment capabilities
        HStack(spacing: 20) {
            ClassicVolumeHUDView(volumeState: VolumeState(volume: 0.15, isMuted: false))
            ClassicVolumeHUDView(volumeState: VolumeState(volume: 0.37, isMuted: false))
            ClassicVolumeHUDView(volumeState: VolumeState(volume: 0.68, isMuted: false))
        }

        HStack(spacing: 20) {
            ClassicVolumeHUDView(volumeState: VolumeState(volume: 0.83, isMuted: false))
            ClassicVolumeHUDView(volumeState: VolumeState(volume: 0.92, isMuted: false))
            ClassicVolumeHUDView(volumeState: VolumeState(volume: 0.45, isMuted: true))
        }
    }
    .padding(60)
    .background(.black.opacity(0.1))
}
