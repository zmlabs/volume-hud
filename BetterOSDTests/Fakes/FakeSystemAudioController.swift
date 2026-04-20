//
//  FakeSystemAudioController.swift
//  BetterOSDTests
//
//  Created by yu on 2026/4/11.
//

@testable import BetterOSD
import CoreAudio

@MainActor
final class FakeSystemAudioController: SystemAudioControlling {
    var defaultDeviceID: AudioDeviceID?
    var deviceAlive = true
    var volumeAddress: AudioObjectPropertyAddress?
    var muteAddress: AudioObjectPropertyAddress?
    var volume: Float?
    var isMuted: Bool?
    var setVolumeSucceeds = true
    var setMuteSucceeds = true
    var getVolumeCallCount = 0
    var getVolumeFailsOnCall: Int?

    func defaultOutputDeviceID() -> AudioDeviceID? {
        defaultDeviceID
    }

    func isDeviceAlive(deviceID _: AudioDeviceID) -> Bool {
        deviceAlive
    }

    func volumePropertyAddress(for _: AudioDeviceID) -> AudioObjectPropertyAddress? {
        volumeAddress
    }

    func mutePropertyAddress(for _: AudioDeviceID) -> AudioObjectPropertyAddress? {
        muteAddress
    }

    func getVolume(deviceID _: AudioDeviceID, address _: AudioObjectPropertyAddress) -> Float? {
        getVolumeCallCount += 1
        if getVolumeFailsOnCall == getVolumeCallCount {
            return nil
        }
        return volume
    }

    func getMute(deviceID _: AudioDeviceID, address _: AudioObjectPropertyAddress) -> Bool? {
        isMuted
    }

    func setVolume(_ newVolume: Float, deviceID _: AudioDeviceID, address _: AudioObjectPropertyAddress) -> Bool {
        guard setVolumeSucceeds else { return false }
        volume = max(0, min(1, newVolume))
        return true
    }

    func setMute(_ muted: Bool, deviceID _: AudioDeviceID, address _: AudioObjectPropertyAddress) -> Bool {
        guard setMuteSucceeds else { return false }
        isMuted = muted
        return true
    }
}
