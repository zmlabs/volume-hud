//
//  VolumeMonitor.swift
//  BetterOSD
//
//  Created by yu on 2025/9/23.
//

import Combine
import CoreAudio
import Foundation

final class VolumeMonitor {
    static let shared = VolumeMonitor()

    let volumeChangePublisher = PassthroughSubject<VolumeState, Never>()
    private(set) var currentVolumeState = VolumeState()

    private let audioController = SystemAudioController.shared
    private static let debounceInterval: TimeInterval = 0.05
    private var outputDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var volumePropertyAddress: AudioObjectPropertyAddress?
    private var mutePropertyAddress: AudioObjectPropertyAddress?
    private var debounceTask: Task<Void, Never>?

    private var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private var streamConfigurationAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreamConfiguration,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    private var deviceAliveAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsAlive,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private let mainVolumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    private let channel1VolumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: 1
    )

    private var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    private init() {
        setupDeviceListener()
        updateOutputDevice()
        refreshState()
    }

    deinit {
        debounceTask?.cancel()
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

    private func removeDeviceListeners() {
        guard outputDeviceID != kAudioObjectUnknown else { return }

        if var volAddr = volumePropertyAddress {
            AudioObjectRemovePropertyListener(
                outputDeviceID, &volAddr, Self.propertyCallback,
                Unmanaged.passUnretained(self).toOpaque()
            )
            volumePropertyAddress = nil
        }

        if var muteAddr = mutePropertyAddress {
            AudioObjectRemovePropertyListener(
                outputDeviceID, &muteAddr, Self.propertyCallback,
                Unmanaged.passUnretained(self).toOpaque()
            )
            mutePropertyAddress = nil
        }

        var configAddr = streamConfigurationAddress
        AudioObjectRemovePropertyListener(
            outputDeviceID, &configAddr, Self.propertyCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )

        var aliveAddr = deviceAliveAddress
        AudioObjectRemovePropertyListener(
            outputDeviceID, &aliveAddr, Self.propertyCallback,
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
        removeDeviceListeners()
    }

    func stop() {
        debounceTask?.cancel()
        removeAllListeners()
    }

    // MARK: - State Updates

    func updateOutputDevice(force: Bool = false) {
        guard let deviceID = audioController.defaultOutputDeviceID(),
              deviceID != kAudioObjectUnknown,
              force || deviceID != outputDeviceID
        else {
            return
        }

        removeDeviceListeners()
        outputDeviceID = deviceID

        volumePropertyAddress = audioController.volumePropertyAddress(for: deviceID)
        mutePropertyAddress = audioController.mutePropertyAddress(for: deviceID)

        if var volAddr = volumePropertyAddress {
            _ = AudioObjectAddPropertyListener(
                outputDeviceID, &volAddr, Self.propertyCallback,
                Unmanaged.passUnretained(self).toOpaque()
            )
        }

        if var muteAddr = mutePropertyAddress {
            _ = AudioObjectAddPropertyListener(
                outputDeviceID, &muteAddr, Self.propertyCallback,
                Unmanaged.passUnretained(self).toOpaque()
            )
        }

        var configAddr = streamConfigurationAddress
        if AudioObjectHasProperty(outputDeviceID, &configAddr) {
            _ = AudioObjectAddPropertyListener(
                outputDeviceID, &configAddr, Self.propertyCallback,
                Unmanaged.passUnretained(self).toOpaque()
            )
        }

        var aliveAddr = deviceAliveAddress
        if AudioObjectHasProperty(outputDeviceID, &aliveAddr) {
            _ = AudioObjectAddPropertyListener(
                outputDeviceID, &aliveAddr, Self.propertyCallback,
                Unmanaged.passUnretained(self).toOpaque()
            )
        }
    }

    func scheduleStateRefresh() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
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
        guard let address = volumePropertyAddress else { return 0 }
        return audioController.getVolume(deviceID: outputDeviceID, address: address) ?? 0
    }

    private func getMuteState() -> Bool {
        guard let address = mutePropertyAddress else { return false }
        return audioController.getMute(deviceID: outputDeviceID, address: address) ?? false
    }

    // MARK: - Callback

    private static let propertyCallback: AudioObjectPropertyListenerProc = { _, numAddresses, addresses, clientData in
        guard let clientData else { return noErr }

        let monitor = Unmanaged<VolumeMonitor>.fromOpaque(clientData).takeUnretainedValue()

        var shouldUpdateDevice = false
        var shouldRefreshDevice = false
        for i in 0 ..< numAddresses {
            let selector = addresses[Int(i)].mSelector
            if selector == kAudioHardwarePropertyDefaultOutputDevice {
                shouldUpdateDevice = true
            }
            if selector == kAudioDevicePropertyStreamConfiguration || selector == kAudioDevicePropertyDeviceIsAlive {
                shouldRefreshDevice = true
            }
        }

        Task { @MainActor in
            if shouldUpdateDevice {
                monitor.updateOutputDevice()
            } else if shouldRefreshDevice {
                monitor.updateOutputDevice(force: true)
            }
            monitor.scheduleStateRefresh()
        }
        return noErr
    }
}
