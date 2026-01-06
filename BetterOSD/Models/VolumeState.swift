//
//  VolumeState.swift
//  BetterOSD
//
//  Created by yu on 2025/9/23.
//

import CoreAudio
import Foundation

/// Represents the current system volume state
struct VolumeState: Equatable {
    let volume: Float // 0.0-1.0 from Core Audio
    let isMuted: Bool
    let outputDeviceID: AudioDeviceID

    init(volume: Float = 0.0, isMuted: Bool = false, outputDeviceID: AudioDeviceID = kAudioObjectUnknown) {
        self.volume = max(0.0, min(1.0, volume))
        self.isMuted = isMuted
        self.outputDeviceID = outputDeviceID
    }

    /// Check if this state represents a volume/mute change that should trigger UI updates
    func hasVolumeOrMuteChange(from previousState: VolumeState) -> Bool {
        isMuted != previousState.isMuted || volume != previousState.volume
    }

    /// Check if the device changed
    func hasDeviceChange(from previousState: VolumeState) -> Bool {
        outputDeviceID != previousState.outputDeviceID
    }

    /// Volume icon name based on current state
    var iconName: String {
        if isMuted { return "speaker.slash.fill" }
        if volume == 0 { return "speaker.fill" }
        if volume < 0.33 { return "speaker.wave.1.fill" }
        if volume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}
