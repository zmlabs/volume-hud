//
//  VolumeState.swift
//  VolumeHUD
//
//  Created by yu on 2025/9/23.
//

import CoreAudio
import Foundation

/// Represents the current system volume state
struct VolumeState {
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
        isMuted != previousState.isMuted || abs(volume - previousState.volume) > 0.001
    }

    /// Check if the device changed
    func hasDeviceChange(from previousState: VolumeState) -> Bool {
        outputDeviceID != previousState.outputDeviceID
    }
}

extension VolumeState: Equatable {
    static func == (lhs: VolumeState, rhs: VolumeState) -> Bool {
        abs(lhs.volume - rhs.volume) < 0.0001 &&
            lhs.isMuted == rhs.isMuted &&
            lhs.outputDeviceID == rhs.outputDeviceID
    }
}
