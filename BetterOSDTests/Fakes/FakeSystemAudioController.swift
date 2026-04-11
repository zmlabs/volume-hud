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
        volume
    }

    func getMute(deviceID _: AudioDeviceID, address _: AudioObjectPropertyAddress) -> Bool? {
        isMuted
    }
}
