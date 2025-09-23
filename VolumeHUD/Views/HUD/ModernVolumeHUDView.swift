//
//  ModernVolumeHUDView.swift
//  VolumeHUD
//
//  Created by yu on 2025/9/23.
//

import SwiftUI

struct ModernVolumeHUDView: View {
    let volumeState: VolumeState

    var body: some View {
        HStack(spacing: 16) {
            // Volume icon
            Image(systemName: volumeIconName)
                .font(.system(size: 24, weight: .medium))
                .frame(width: 28)
                .foregroundStyle(.gray)
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
        .glassEffect(in: .capsule)
    }

    private var volumeIconName: String {
        if volumeState.isMuted {
            return "speaker.slash.fill"
        } else if volumeState.volume == 0 {
            return "speaker.fill"
        } else if volumeState.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if volumeState.volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
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
                if !volumeState.isMuted && volumeState.volume > 0 {
                    Capsule()
                        .fill(.primary)
                        .frame(width: geometry.size.width * CGFloat(volumeState.volume))
                }
            }
        }
    }
}

struct ModernVolumeProgressTicks: View {
    let volumeState: VolumeState

    private let tickCount = 16

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0 ..< tickCount, id: \.self) { index in
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(tickColor(for: index))
                        .frame(width: 1, height: tickHeight(for: index))
                }
                if index < tickCount - 1 {
                    Spacer()
                }
            }
        }
    }

    private func tickColor(for index: Int) -> Color {
        let isActive = !volumeState.isMuted && volumeState.volume > Float(index) / Float(tickCount)
        return .primary.opacity(isActive ? 0.8 : 0.3)
    }

    private func tickHeight(for index: Int) -> CGFloat {
        (index + 1) % 4 == 0 ? 6 : 4
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
