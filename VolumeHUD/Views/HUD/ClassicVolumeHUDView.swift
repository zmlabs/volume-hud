//
//  ClassicVolumeHUDView.swift
//  VolumeHUD
//
//  Created by yu on 2025/9/23.
//

import SwiftUI

struct ClassicVolumeHUDView: View {
    let volumeState: VolumeState

    @AppStorage(AppStorageKeys.liquidGlassEnable) private var liquidGlassEnable: Bool = true

    var body: some View {
        let content = VStack(spacing: 0) {
            // Upper section: Volume icon
            VStack {
                Image(systemName: volumeIconName)
                    .font(.system(size: 72, weight: .regular))
                    .foregroundStyle(.primary.opacity(liquidGlassEnable ? 0.6 : 1))
                    .contentTransition(
                        .symbolEffect(.replace)
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Lower section: Volume progress bar
            ClassicVolumeProgressBar(
                volumeState: volumeState
            )
            .padding(.bottom, 16)
        }
        .frame(width: 200, height: 200)

        if liquidGlassEnable {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 16.0))
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
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

struct ClassicVolumeProgressBar: View {
    let volumeState: VolumeState

    private static let segmentCount = 16
    private static let segmentSpacing: CGFloat = 1

    var body: some View {
        HStack(spacing: Self.segmentSpacing) {
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

        let volume = volumeState.volume
        
        // Get the threshold values for this segment
        let segmentStart = VolumeConstants.standardVolumeLevels[index]
        let segmentEnd = VolumeConstants.standardVolumeLevels[index + 1]
        
        if volume >= segmentEnd {
            // Segment is fully filled
            return 1.0
        } else if volume > segmentStart {
            // Segment is partially filled
            let segmentRange = segmentEnd - segmentStart
            let progressInSegment = volume - segmentStart
            return CGFloat(progressInSegment / segmentRange)
        } else {
            // Segment is empty
            return 0.0
        }
    }
}

private struct VolumeSegment: View {
    let fillRatio: CGFloat // 0.0 to 1.0
    let isActive: Bool

    private static let size: CGFloat = 8
    private static let cornerRadius: CGFloat = 1

    var body: some View {
        Rectangle()
            .fill(.secondary.opacity(0.3))
            .overlay(alignment: .leading) {
                if fillRatio > 0 && isActive {
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
