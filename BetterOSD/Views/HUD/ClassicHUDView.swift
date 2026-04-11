//
//  ClassicHUDView.swift
//  BetterOSD
//
//  Created by yu on 2025/9/23.
//

import SwiftUI

struct ClassicHUDView: View {
    let displayState: HUDDisplayState
    let liquidGlassEnable: Bool
    let glassVariant: Int

    var body: some View {
        let content = VStack(spacing: 0) {
            VStack {
                Image(systemName: displayState.iconName)
                    .font(.system(size: 72, weight: .regular))
                    .foregroundStyle(.primary.opacity(liquidGlassEnable ? 0.6 : 1))
                    .contentTransition(
                        .symbolEffect(.replace)
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ClassicHUDProgressBar(
                displayState: displayState
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

struct ClassicHUDProgressBar: View {
    let displayState: HUDDisplayState

    private static let segmentCount = 16

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0 ..< Self.segmentCount, id: \.self) { index in
                HUDSegment(
                    fillRatio: fillRatio(for: index),
                    isActive: !displayState.isMuted
                )
            }
        }
    }

    private func fillRatio(for index: Int) -> CGFloat {
        guard !displayState.isMuted else { return 0 }
        return HUDCalculation.segmentFillRatio(
            segmentIndex: index,
            volume: displayState.level
        )
    }
}

private struct HUDSegment: View {
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
                        .fill(Color(.secondaryLabelColor))
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
        HStack(spacing: 20) {
            ClassicHUDView(displayState: HUDDisplayState(iconName: "speaker.wave.1.fill", level: 0.15, isMuted: false), liquidGlassEnable: true, glassVariant: 0)
            ClassicHUDView(displayState: HUDDisplayState(iconName: "speaker.wave.2.fill", level: 0.37, isMuted: false), liquidGlassEnable: true, glassVariant: 0)
            ClassicHUDView(displayState: HUDDisplayState(iconName: "speaker.wave.2.fill", level: 0.68, isMuted: false), liquidGlassEnable: true, glassVariant: 0)
        }

        HStack(spacing: 20) {
            ClassicHUDView(displayState: HUDDisplayState(iconName: "speaker.wave.3.fill", level: 0.83, isMuted: false), liquidGlassEnable: true, glassVariant: 0)
            ClassicHUDView(displayState: HUDDisplayState(iconName: "speaker.wave.3.fill", level: 0.92, isMuted: false), liquidGlassEnable: true, glassVariant: 0)
            ClassicHUDView(displayState: HUDDisplayState(iconName: "speaker.slash.fill", level: 0.45, isMuted: true), liquidGlassEnable: true, glassVariant: 0)
        }
    }
    .padding(60)
    .background(.black.opacity(0.1))
}
