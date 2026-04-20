//
//  SystemAudioController.swift
//  BetterOSD
//
//  Created by yu on 2026/1/11.
//

import CoreAudio
import Foundation

protocol SystemAudioControlling: AnyObject {
    func defaultOutputDeviceID() -> AudioDeviceID?
    func isDeviceAlive(deviceID: AudioDeviceID) -> Bool
    func volumePropertyAddress(for deviceID: AudioDeviceID) -> AudioObjectPropertyAddress?
    func mutePropertyAddress(for deviceID: AudioDeviceID) -> AudioObjectPropertyAddress?
    func getVolume(deviceID: AudioDeviceID, address: AudioObjectPropertyAddress) -> Float?
    func getMute(deviceID: AudioDeviceID, address: AudioObjectPropertyAddress) -> Bool?
    func setVolume(_ volume: Float, deviceID: AudioDeviceID, address: AudioObjectPropertyAddress) -> Bool
    func setMute(_ muted: Bool, deviceID: AudioDeviceID, address: AudioObjectPropertyAddress) -> Bool
}

final class SystemAudioController {
    static let shared = SystemAudioController()

    private init() {}

    func defaultOutputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )

        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    func volumePropertyAddress(for deviceID: AudioDeviceID) -> AudioObjectPropertyAddress? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(deviceID, &address) {
            return address
        }

        address.mElement = 1
        if AudioObjectHasProperty(deviceID, &address) {
            return address
        }
        return nil
    }

    func mutePropertyAddress(for deviceID: AudioDeviceID) -> AudioObjectPropertyAddress? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(deviceID, &address) {
            return address
        }
        return nil
    }

    func getVolume(deviceID: AudioDeviceID, address: AudioObjectPropertyAddress) -> Float? {
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var mutableAddress = address

        let status = AudioObjectGetPropertyData(deviceID, &mutableAddress, 0, nil, &size, &volume)
        guard status == noErr else { return nil }
        return Float(volume)
    }

    func setVolume(_ volume: Float, deviceID: AudioDeviceID, address: AudioObjectPropertyAddress) -> Bool {
        var mutableAddress = address
        var clampedVolume = Float32(max(0, min(1, volume)))
        let size = UInt32(MemoryLayout<Float32>.size)

        let status = AudioObjectSetPropertyData(deviceID, &mutableAddress, 0, nil, size, &clampedVolume)
        return status == noErr
    }

    func getMute(deviceID: AudioDeviceID, address: AudioObjectPropertyAddress) -> Bool? {
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var mutableAddress = address

        let status = AudioObjectGetPropertyData(deviceID, &mutableAddress, 0, nil, &size, &muted)
        guard status == noErr else { return nil }
        return muted != 0
    }

    func setMute(_ muted: Bool, deviceID: AudioDeviceID, address: AudioObjectPropertyAddress) -> Bool {
        var mutableAddress = address
        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectSetPropertyData(deviceID, &mutableAddress, 0, nil, size, &value)
        return status == noErr
    }
}

extension SystemAudioController: SystemAudioControlling {
    func isDeviceAlive(deviceID: AudioDeviceID) -> Bool {
        var isAlive: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsAlive,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &isAlive)
        return status == noErr && isAlive != 0
    }
}
