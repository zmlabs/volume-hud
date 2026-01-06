//
//  VolumeMonitor.swift
//  BetterOSD
//
//  Created by yu on 2025/9/23.
//

@preconcurrency import Combine
import CoreAudio
import Foundation

/// Monitors system volume changes using Core Audio
final class VolumeMonitor {
    static let shared = VolumeMonitor()

    let volumeChangePublisher = PassthroughSubject<VolumeState, Never>()
    private(set) var currentVolumeState = VolumeState()

    private var outputDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var volumePropertyAddress: AudioObjectPropertyAddress?
    private var debounceTask: Task<Void, Never>?

    private static let debounceInterval: TimeInterval = 0.05

    // Property addresses
    private var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private let mainVolumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    private let channel1VolumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: 1
    )

    private var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    private init() {
        setupDeviceListener()
        updateOutputDevice()
        refreshState()
    }

    deinit {
        MainActor.assumeIsolated {
            debounceTask?.cancel()
            removeAllListeners()
        }
    }

    // MARK: - Listener Setup

    private func setupDeviceListener() {
        AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            Self.propertyCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    private func setupVolumeListeners() {
        guard outputDeviceID != kAudioObjectUnknown else { return }

        // Find available volume property
        var address = mainVolumeAddress
        if AudioObjectHasProperty(outputDeviceID, &address) {
            volumePropertyAddress = mainVolumeAddress
        } else {
            address = channel1VolumeAddress
            if AudioObjectHasProperty(outputDeviceID, &address) {
                volumePropertyAddress = channel1VolumeAddress
            }
        }

        // Register volume listener
        if var volAddr = volumePropertyAddress {
            AudioObjectAddPropertyListener(
                outputDeviceID, &volAddr, Self.propertyCallback,
                Unmanaged.passUnretained(self).toOpaque()
            )
        }

        // Register mute listener
        if AudioObjectHasProperty(outputDeviceID, &muteAddress) {
            AudioObjectAddPropertyListener(
                outputDeviceID, &muteAddress, Self.propertyCallback,
                Unmanaged.passUnretained(self).toOpaque()
            )
        }
    }

    private func removeVolumeListeners() {
        guard outputDeviceID != kAudioObjectUnknown else { return }

        if var volAddr = volumePropertyAddress {
            AudioObjectRemovePropertyListener(
                outputDeviceID, &volAddr, Self.propertyCallback,
                Unmanaged.passUnretained(self).toOpaque()
            )
            volumePropertyAddress = nil
        }

        AudioObjectRemovePropertyListener(
            outputDeviceID, &muteAddress, Self.propertyCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    private func removeAllListeners() {
        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            Self.propertyCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        removeVolumeListeners()
    }

    // MARK: - State Updates

    func updateOutputDevice() {
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)

        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress, 0, nil, &size, &deviceID
        ) == noErr, deviceID != kAudioObjectUnknown, deviceID != outputDeviceID else {
            return
        }

        removeVolumeListeners()
        outputDeviceID = deviceID
        setupVolumeListeners()
    }

    func scheduleStateRefresh() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.debounceInterval))
            self?.refreshState()
        }
    }

    private func refreshState() {
        let newState = VolumeState(
            volume: getVolume(),
            isMuted: getMuteState(),
            outputDeviceID: outputDeviceID
        )

        guard newState != currentVolumeState else { return }

        let hadVolumeChange = newState.hasVolumeOrMuteChange(from: currentVolumeState)
        currentVolumeState = newState

        if hadVolumeChange {
            volumeChangePublisher.send(newState)
        }
    }

    // MARK: - Property Getters

    private func getVolume() -> Float {
        guard var address = volumePropertyAddress else { return 0 }

        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)

        return AudioObjectGetPropertyData(outputDeviceID, &address, 0, nil, &size, &volume) == noErr
            ? volume : 0
    }

    private func getMuteState() -> Bool {
        guard outputDeviceID != kAudioObjectUnknown,
              AudioObjectHasProperty(outputDeviceID, &muteAddress)
        else {
            return false
        }

        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)

        return AudioObjectGetPropertyData(outputDeviceID, &muteAddress, 0, nil, &size, &muted) == noErr
            && muted != 0
    }

    // MARK: - Callback

    private static let propertyCallback: AudioObjectPropertyListenerProc = { _, numAddresses, addresses, clientData in
        guard let clientData else { return noErr }

        let monitor = Unmanaged<VolumeMonitor>.fromOpaque(clientData).takeUnretainedValue()

        var shouldUpdateDevice = false
        for i in 0 ..< numAddresses {
            if addresses[Int(i)].mSelector == kAudioHardwarePropertyDefaultOutputDevice {
                shouldUpdateDevice = true
                break
            }
        }

        Task { @MainActor in
            if shouldUpdateDevice {
                monitor.updateOutputDevice()
            }
            monitor.scheduleStateRefresh()
        }
        return noErr
    }
}
