//
//  VolumeKeyController.swift
//  BetterOSD
//
//  Created by yu on 2026/1/7.
//

import CoreAudio
import Foundation

enum MediaKeyHandlingResult: Equatable {
    case passThrough
    case consumed(didChange: Bool)
}

protocol VolumeKeyHandling: AnyObject {
    func handle(_ key: MediaKeyMonitor.MediaKey, fineStep: Bool) -> MediaKeyHandlingResult
}

final class VolumeKeyController: VolumeKeyHandling {
    private let audioController: SystemAudioControlling
    private let hudStore: HUDDisplayStateStore
    private var lastNonZeroVolumeByDevice: [AudioDeviceID: AudioDeviceVolumeSnapshot] = [:]

    init(
        audioController: SystemAudioControlling = SystemAudioController.shared,
        hudStore: HUDDisplayStateStore = .shared
    ) {
        self.audioController = audioController
        self.hudStore = hudStore
    }

    func handle(_ key: MediaKeyMonitor.MediaKey, fineStep: Bool) -> MediaKeyHandlingResult {
        guard key.isIntercepted else { return .passThrough }
        guard let deviceID = audioController.defaultOutputDeviceID(),
              let volumeControl = audioController.volumeControl(for: deviceID)
        else {
            return .passThrough
        }

        let currentSnapshot = audioController.readVolumeSnapshot(deviceID: deviceID, control: volumeControl)
        let currentVolume = currentSnapshot?.displayVolume ?? 0
        let muteAddress = audioController.mutePropertyAddress(for: deviceID)
        let isMuted = muteAddress.flatMap { audioController.getMute(deviceID: deviceID, address: $0) } ?? false

        if let currentSnapshot, currentSnapshot.hasAudibleVolume {
            lastNonZeroVolumeByDevice[deviceID] = currentSnapshot
        }

        let result: MediaKeyHandlingResult
        switch key {
        case .mute:
            if let muteAddress {
                result = handleMuteToggle(
                    deviceID: deviceID,
                    volumeControl: volumeControl,
                    muteAddress: muteAddress,
                    currentSnapshot: currentSnapshot,
                    currentVolume: currentVolume,
                    isMuted: isMuted
                )
            } else {
                result = handleMuteFallback(
                    deviceID: deviceID,
                    volumeControl: volumeControl,
                    currentSnapshot: currentSnapshot,
                    currentVolume: currentVolume
                )
            }
        case .soundUp, .soundDown:
            result = handleVolumeStep(
                key: key,
                deviceID: deviceID,
                volumeControl: volumeControl,
                muteAddress: muteAddress,
                currentSnapshot: currentSnapshot,
                currentVolume: currentVolume,
                isMuted: isMuted,
                fineStep: fineStep
            )
        case .brightnessUp, .brightnessDown:
            return .passThrough
        }

        if case .consumed = result {
            pushHUDState(deviceID: deviceID, fallbackVolume: currentVolume, fallbackMuted: isMuted)
        }
        return result
    }

    private func pushHUDState(
        deviceID: AudioDeviceID,
        fallbackVolume: Float,
        fallbackMuted: Bool
    ) {
        let state = VolumeState.read(
            deviceID: deviceID,
            from: audioController,
            fallbackVolume: fallbackVolume,
            fallbackMuted: fallbackMuted
        )
        hudStore.update(state.displayState)
    }

    private func handleMuteToggle(
        deviceID: AudioDeviceID,
        volumeControl: AudioDeviceVolumeControl,
        muteAddress: AudioObjectPropertyAddress,
        currentSnapshot: AudioDeviceVolumeSnapshot?,
        currentVolume: Float,
        isMuted: Bool
    ) -> MediaKeyHandlingResult {
        let targetMute = !isMuted
        var handled = false
        var didChange = false

        if targetMute, let currentSnapshot, currentSnapshot.hasAudibleVolume {
            lastNonZeroVolumeByDevice[deviceID] = currentSnapshot
        }

        let muteSuccess = audioController.setMute(targetMute, deviceID: deviceID, address: muteAddress)
        handled = handled || muteSuccess
        didChange = didChange || (muteSuccess && targetMute != isMuted)

        if muteSuccess, !targetMute, currentVolume <= 0 {
            let restoredSnapshot = lastNonZeroVolumeByDevice[deviceID]
                ?? audioController.projectedVolumeSnapshot(control: volumeControl, targetVolume: 0.25, from: nil)
            let volumeSuccess = audioController.restoreVolume(
                restoredSnapshot,
                deviceID: deviceID,
                control: volumeControl
            )
            handled = handled || volumeSuccess
            didChange = didChange || (volumeSuccess && restoredSnapshot.displayVolume != currentVolume)
            if volumeSuccess {
                lastNonZeroVolumeByDevice[deviceID] = restoredSnapshot
            }
        }

        return handled ? .consumed(didChange: didChange) : .passThrough
    }

    private func handleVolumeStep(
        key: MediaKeyMonitor.MediaKey,
        deviceID: AudioDeviceID,
        volumeControl: AudioDeviceVolumeControl,
        muteAddress: AudioObjectPropertyAddress?,
        currentSnapshot: AudioDeviceVolumeSnapshot?,
        currentVolume: Float,
        isMuted: Bool,
        fineStep: Bool
    ) -> MediaKeyHandlingResult {
        let stepsPerUnit = fineStep ? HUDCalculation.fineSteps : HUDCalculation.standardSteps
        let currentStep = Int(round(currentVolume * Float(stepsPerUnit)))
        let targetStep = max(0, min(stepsPerUnit, currentStep + (key == .soundUp ? 1 : -1)))
        let targetVolume = Float(targetStep) / Float(stepsPerUnit)

        var handled = false
        var didChange = false

        if let muteAddress, isMuted, targetVolume > 0 {
            let unmuteSuccess = audioController.setMute(false, deviceID: deviceID, address: muteAddress)
            handled = handled || unmuteSuccess
            didChange = didChange || (unmuteSuccess && isMuted)
        }

        let volumeSuccess = audioController.setVolume(
            targetVolume,
            deviceID: deviceID,
            control: volumeControl,
            snapshot: currentSnapshot
        )
        handled = handled || volumeSuccess
        didChange = didChange || (volumeSuccess && targetVolume != currentVolume)

        if volumeSuccess, targetVolume > 0 {
            lastNonZeroVolumeByDevice[deviceID] = audioController.projectedVolumeSnapshot(
                control: volumeControl,
                targetVolume: targetVolume,
                from: currentSnapshot
            )
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
        volumeControl: AudioDeviceVolumeControl,
        currentSnapshot: AudioDeviceVolumeSnapshot?,
        currentVolume: Float
    ) -> MediaKeyHandlingResult {
        if let currentSnapshot, currentSnapshot.hasAudibleVolume {
            lastNonZeroVolumeByDevice[deviceID] = currentSnapshot
            let success = audioController.setVolume(
                0,
                deviceID: deviceID,
                control: volumeControl,
                snapshot: currentSnapshot
            )
            return success ? .consumed(didChange: true) : .passThrough
        }

        let restoredSnapshot = lastNonZeroVolumeByDevice[deviceID]
            ?? audioController.projectedVolumeSnapshot(control: volumeControl, targetVolume: 0.25, from: nil)
        let success = audioController.restoreVolume(
            restoredSnapshot,
            deviceID: deviceID,
            control: volumeControl
        )
        if success {
            lastNonZeroVolumeByDevice[deviceID] = restoredSnapshot
        }
        return success ? .consumed(didChange: restoredSnapshot.displayVolume != currentVolume) : .passThrough
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
