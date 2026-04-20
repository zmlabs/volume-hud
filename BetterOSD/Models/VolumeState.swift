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

    /// Volume icon name based on current state
    var iconName: String {
        if isMuted { return "speaker.slash.fill" }
        if volume == 0 { return "speaker.fill" }
        if volume < 0.33 { return "speaker.wave.1.fill" }
        if volume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    var displayState: HUDDisplayState {
        HUDDisplayState(iconName: iconName, level: volume, isMuted: isMuted)
    }

    static func readCurrent(from controller: SystemAudioControlling) -> VolumeState {
        guard let deviceID = controller.defaultOutputDeviceID() else {
            return VolumeState()
        }
        return read(deviceID: deviceID, from: controller)
    }

    static func read(
        deviceID: AudioDeviceID,
        from controller: SystemAudioControlling,
        fallbackVolume: Float = 0,
        fallbackMuted: Bool = false
    ) -> VolumeState {
        let volume = controller.volumePropertyAddress(for: deviceID)
            .flatMap { controller.getVolume(deviceID: deviceID, address: $0) } ?? fallbackVolume
        let isMuted = controller.mutePropertyAddress(for: deviceID)
            .flatMap { controller.getMute(deviceID: deviceID, address: $0) } ?? fallbackMuted
        return VolumeState(volume: volume, isMuted: isMuted, outputDeviceID: deviceID)
    }
}
