//
//  ModernHUDView.swift
//  BetterOSD
//
//  Created by yu on 2025/9/23.
//

import SwiftUI

struct ModernHUDView: View {
    let displayState: HUDDisplayState
    let liquidGlassEnable: Bool
    let glassVariant: Int

    var body: some View {
        let content = HStack(spacing: 16) {
            Image(systemName: displayState.iconName)
                .font(.system(size: 24, weight: .medium))
                .frame(width: 28)
                .foregroundStyle(.primary.opacity(liquidGlassEnable ? 0.6 : 1))
                .contentTransition(.symbolEffect(.replace))

            VStack(spacing: 4) {
                ModernHUDProgressBar(
                    displayState: displayState
                )
                .frame(height: 4)

                ModernHUDProgressTicks(
                    displayState: displayState
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

struct ModernHUDProgressBar: View {
    let displayState: HUDDisplayState

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.primary.opacity(0.2))

                if !displayState.isMuted, displayState.level > 0 {
                    Capsule()
                        .fill(Color(.secondaryLabelColor))
                        .frame(width: geometry.size.width * CGFloat(displayState.level))
                }
            }
        }
    }
}

struct ModernHUDProgressTicks: View {
    let displayState: HUDDisplayState

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0 ... HUDCalculation.standardSteps, id: \.self) { index in
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(tickColor(for: index))
                        .frame(width: 1, height: tickHeight(for: index))
                }
                if index < HUDCalculation.standardSteps {
                    Spacer()
                }
            }
        }
    }

    private func tickColor(for index: Int) -> Color {
        let isActive = !displayState.isMuted && HUDCalculation.isTickActive(
            tickIndex: index,
            volume: displayState.level
        )
        return .primary.opacity(isActive ? 0.8 : 0.3)
    }

    private func tickHeight(for index: Int) -> CGFloat {
        index % 4 == 0 ? 6 : 4
    }
}

#Preview {
    VStack(spacing: 30) {
        ModernHUDView(displayState: HUDDisplayState(iconName: "speaker.fill", level: 0.06, isMuted: false), liquidGlassEnable: true, glassVariant: 0)
        ModernHUDView(displayState: HUDDisplayState(iconName: "speaker.wave.2.fill", level: 0.5, isMuted: false), liquidGlassEnable: true, glassVariant: 0)
        ModernHUDView(displayState: HUDDisplayState(iconName: "speaker.wave.3.fill", level: 0.9, isMuted: false), liquidGlassEnable: true, glassVariant: 0)
        ModernHUDView(displayState: HUDDisplayState(iconName: "speaker.slash.fill", level: 0.3, isMuted: true), liquidGlassEnable: true, glassVariant: 0)
    }
    .padding(40)
    .background(.black.opacity(0.1))
}
