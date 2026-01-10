//
//  VolumeKeyController.swift
//  BetterOSD
//
//  Created by yu on 2026/1/7.
//

import CoreAudio
import Foundation

enum MediaKeyHandlingResult {
    case passThrough
    case consumed(didChange: Bool)
}

final class VolumeKeyController {
    private static let coarseStep: Float = 1.0 / 16.0
    private static let fineStep: Float = 1.0 / 64.0
    private static let fallbackUnmuteVolume: Float = 0.25

    private let audioController = SystemAudioController()
    private var lastNonZeroVolumeByDevice: [AudioDeviceID: Float] = [:]

    func handle(_ key: MediaKeyMonitor.MediaKey, fineStep: Bool) -> MediaKeyHandlingResult {
        guard key.isIntercepted else { return .passThrough }
        guard let deviceID = audioController.defaultOutputDeviceID(),
              let volumeAddress = audioController.volumePropertyAddress(for: deviceID)
        else {
            return .passThrough
        }

        let currentVolume = audioController.getVolume(deviceID: deviceID, address: volumeAddress) ?? 0
        let muteAddress = audioController.mutePropertyAddress(for: deviceID)
        let isMuted = muteAddress.flatMap { audioController.getMute(deviceID: deviceID, address: $0) } ?? false

        if currentVolume > 0 {
            lastNonZeroVolumeByDevice[deviceID] = currentVolume
        }

        switch key {
        case .mute:
            if let muteAddress {
                return handleMuteToggle(
                    deviceID: deviceID,
                    volumeAddress: volumeAddress,
                    muteAddress: muteAddress,
                    currentVolume: currentVolume,
                    isMuted: isMuted
                )
            }
            return handleMuteFallback(deviceID: deviceID, volumeAddress: volumeAddress, currentVolume: currentVolume)
        case .soundUp, .soundDown:
            return handleVolumeStep(
                key: key,
                deviceID: deviceID,
                volumeAddress: volumeAddress,
                muteAddress: muteAddress,
                currentVolume: currentVolume,
                isMuted: isMuted,
                fineStep: fineStep
            )
        case .brightnessUp, .brightnessDown:
            return .passThrough
        }
    }

    private func handleMuteToggle(
        deviceID: AudioDeviceID,
        volumeAddress: AudioObjectPropertyAddress,
        muteAddress: AudioObjectPropertyAddress,
        currentVolume: Float,
        isMuted: Bool
    ) -> MediaKeyHandlingResult {
        let targetMute = !isMuted
        var handled = false
        var didChange = false

        if targetMute, currentVolume > 0 {
            lastNonZeroVolumeByDevice[deviceID] = currentVolume
        }

        let muteSuccess = audioController.setMute(targetMute, deviceID: deviceID, address: muteAddress)
        handled = handled || muteSuccess
        didChange = didChange || (muteSuccess && targetMute != isMuted)

        if muteSuccess, !targetMute, currentVolume <= 0 {
            let restoreVolume = lastNonZeroVolumeByDevice[deviceID] ?? Self.fallbackUnmuteVolume
            let volumeSuccess = audioController.setVolume(restoreVolume, deviceID: deviceID, address: volumeAddress)
            handled = handled || volumeSuccess
            didChange = didChange || (volumeSuccess && restoreVolume != currentVolume)
            if volumeSuccess {
                lastNonZeroVolumeByDevice[deviceID] = restoreVolume
            }
        }

        return handled ? .consumed(didChange: didChange) : .passThrough
    }

    private func handleVolumeStep(
        key: MediaKeyMonitor.MediaKey,
        deviceID: AudioDeviceID,
        volumeAddress: AudioObjectPropertyAddress,
        muteAddress: AudioObjectPropertyAddress?,
        currentVolume: Float,
        isMuted: Bool,
        fineStep: Bool
    ) -> MediaKeyHandlingResult {
        let step = fineStep ? Self.fineStep : Self.coarseStep
        let delta = (key == .soundUp) ? step : -step
        let targetVolume = max(0, min(1, currentVolume + delta))

        var handled = false
        var didChange = false

        if let muteAddress, isMuted, targetVolume > 0 {
            let unmuteSuccess = audioController.setMute(false, deviceID: deviceID, address: muteAddress)
            handled = handled || unmuteSuccess
            didChange = didChange || (unmuteSuccess && isMuted)
        }

        let volumeSuccess = audioController.setVolume(targetVolume, deviceID: deviceID, address: volumeAddress)
        handled = handled || volumeSuccess
        didChange = didChange || (volumeSuccess && targetVolume != currentVolume)

        if volumeSuccess, targetVolume > 0 {
            lastNonZeroVolumeByDevice[deviceID] = targetVolume
        }

        if let muteAddress, !isMuted, targetVolume == 0 {
            let muteSuccess = audioController.setMute(true, deviceID: deviceID, address: muteAddress)
            handled = handled || muteSuccess
            didChange = didChange || (muteSuccess && !isMuted)
        }

        return handled ? .consumed(didChange: didChange) : .passThrough
    }

    private func handleMuteFallback(
        deviceID: AudioDeviceID,
        volumeAddress: AudioObjectPropertyAddress,
        currentVolume: Float
    ) -> MediaKeyHandlingResult {
        if currentVolume > 0 {
            lastNonZeroVolumeByDevice[deviceID] = currentVolume
            let success = audioController.setVolume(0, deviceID: deviceID, address: volumeAddress)
            return success ? .consumed(didChange: true) : .passThrough
        }

        let restoreVolume = lastNonZeroVolumeByDevice[deviceID] ?? Self.fallbackUnmuteVolume
        let success = audioController.setVolume(restoreVolume, deviceID: deviceID, address: volumeAddress)
        return success ? .consumed(didChange: restoreVolume != currentVolume) : .passThrough
    }
}

extension MediaKeyMonitor.MediaKey {
    var isIntercepted: Bool {
        switch self {
        case .soundUp, .soundDown, .mute:
            true
        case .brightnessUp, .brightnessDown:
            false
        }
    }
}

private struct SystemAudioController {
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
        return AudioObjectHasProperty(deviceID, &address) ? address : nil
    }

    func mutePropertyAddress(for deviceID: AudioDeviceID) -> AudioObjectPropertyAddress? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        return AudioObjectHasProperty(deviceID, &address) ? address : nil
    }

    func getVolume(deviceID: AudioDeviceID, address: AudioObjectPropertyAddress) -> Float? {
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var mutableAddress = address

        let status = AudioObjectGetPropertyData(deviceID, &mutableAddress, 0, nil, &size, &volume)
        return status == noErr ? Float(volume) : nil
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
        return status == noErr ? (muted != 0) : nil
    }

    func setMute(_ muted: Bool, deviceID: AudioDeviceID, address: AudioObjectPropertyAddress) -> Bool {
        var mutableAddress = address
        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectSetPropertyData(deviceID, &mutableAddress, 0, nil, size, &value)
        return status == noErr
    }
}
