//
//  FakeSystemAudioController.swift
//  BetterOSDTests
//
//  Created by yu on 2026/4/11.
//

import CoreAudio
@testable import BetterOSD

@MainActor
final class FakeSystemAudioController: SystemAudioControlling {
    var defaultDeviceID: AudioDeviceID?
    var deviceAlive = true
    var volumeAddress: AudioObjectPropertyAddress?
    var muteAddress: AudioObjectPropertyAddress?
    var volume: Float?
    var isMuted: Bool?

    func defaultOutputDeviceID() -> AudioDeviceID? { defaultDeviceID }
    func isDeviceAlive(deviceID: AudioDeviceID) -> Bool { deviceAlive }
    func volumePropertyAddress(for deviceID: AudioDeviceID) -> AudioObjectPropertyAddress? { volumeAddress }
    func mutePropertyAddress(for deviceID: AudioDeviceID) -> AudioObjectPropertyAddress? { muteAddress }
    func getVolume(deviceID: AudioDeviceID, address: AudioObjectPropertyAddress) -> Float? { volume }
    func getMute(deviceID: AudioDeviceID, address: AudioObjectPropertyAddress) -> Bool? { isMuted }
}
