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
    var channelVolumeAddresses: [AudioObjectPropertyAddress] = []
    var muteAddress: AudioObjectPropertyAddress?
    var volume: Float?
    var channelVolumes: [UInt32: Float] = [:]
    var isMuted: Bool?
    var setVolumeSucceeds = true
    var failingVolumeElements: Set<UInt32> = []
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

    func channelVolumePropertyAddresses(for _: AudioDeviceID) -> [AudioObjectPropertyAddress] {
        channelVolumeAddresses
    }

    func mutePropertyAddress(for _: AudioDeviceID) -> AudioObjectPropertyAddress? {
        muteAddress
    }

    func getVolume(deviceID _: AudioDeviceID, address: AudioObjectPropertyAddress) -> Float? {
        getVolumeCallCount += 1
        if getVolumeFailsOnCall == getVolumeCallCount {
            return nil
        }
        if address.mElement == kAudioObjectPropertyElementMain {
            return volume
        }
        return channelVolumes[address.mElement]
    }

    func getMute(deviceID _: AudioDeviceID, address _: AudioObjectPropertyAddress) -> Bool? {
        isMuted
    }

    func setVolume(_ newVolume: Float, deviceID _: AudioDeviceID, address: AudioObjectPropertyAddress) -> Bool {
        guard setVolumeSucceeds else { return false }
        guard failingVolumeElements.contains(address.mElement) == false else { return false }
        let clampedVolume = max(0, min(1, newVolume))
        if address.mElement == kAudioObjectPropertyElementMain {
            volume = clampedVolume
        } else {
            channelVolumes[address.mElement] = clampedVolume
        }
        return true
    }

    func setMute(_ muted: Bool, deviceID _: AudioDeviceID, address _: AudioObjectPropertyAddress) -> Bool {
        guard setMuteSucceeds else { return false }
        isMuted = muted
        return true
    }
}
