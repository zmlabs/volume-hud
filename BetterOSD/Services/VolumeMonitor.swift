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

    private let audioController: SystemAudioControlling
    private static let debounceInterval: TimeInterval = 0.05
    private var outputDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var volumePropertyAddress: AudioObjectPropertyAddress?
    private var mutePropertyAddress: AudioObjectPropertyAddress?
    private var debounceTask: Task<Void, Never>?
    private var outputDeviceProbeTask: Task<Void, Never>?
    private var outputDeviceProbeAttempt = 0
    private var pendingOutputDeviceID = AudioDeviceID(kAudioObjectUnknown)

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

    init(
        audioController: SystemAudioControlling = SystemAudioController.shared,
        autoStart: Bool = true,
        initialOutputDeviceID: AudioDeviceID = kAudioObjectUnknown,
        initialVolumePropertyAddress: AudioObjectPropertyAddress? = nil,
        initialMutePropertyAddress: AudioObjectPropertyAddress? = nil
    ) {
        self.audioController = audioController
        outputDeviceID = initialOutputDeviceID
        volumePropertyAddress = initialVolumePropertyAddress
        mutePropertyAddress = initialMutePropertyAddress

        guard autoStart else { return }

        setupDeviceListener()
        updateOutputDevice()
        refreshState()
    }

    deinit {
        debounceTask?.cancel()
        outputDeviceProbeTask?.cancel()
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
        outputDeviceProbeTask?.cancel()
        removeAllListeners()
    }

    // MARK: - State Updates

    func updateOutputDevice(force: Bool = false) {
        guard let deviceID = audioController.defaultOutputDeviceID(),
              deviceID != kAudioObjectUnknown
        else {
            return
        }

        prepareProbe(for: deviceID)

        guard force || deviceID != outputDeviceID else {
            return
        }

        guard audioController.isDeviceAlive(deviceID: deviceID) else {
            scheduleOutputDeviceProbeRetryIfNeeded(for: deviceID)
            return
        }

        let volumeAddress = audioController.volumePropertyAddress(for: deviceID)
        let muteAddress = audioController.mutePropertyAddress(for: deviceID)
        let decision = VolumeMonitorRefreshPlanner.probeDecision(
            isAlive: true,
            hasVolumeControl: volumeAddress != nil,
            attempt: outputDeviceProbeAttempt
        )

        switch decision {
        case .apply, .acceptWithoutVolumeControl:
            applyOutputDeviceChange(
                deviceID: deviceID,
                volumeAddress: volumeAddress,
                muteAddress: muteAddress
            )

        case let .retry(delay):
            scheduleOutputDeviceProbeRetry(for: deviceID, delayMilliseconds: delay)

        case .skipUntilNextDeviceChange:
            return
        }
    }

    private func prepareProbe(for deviceID: AudioDeviceID) {
        guard pendingOutputDeviceID != deviceID else { return }
        outputDeviceProbeTask?.cancel()
        outputDeviceProbeTask = nil
        outputDeviceProbeAttempt = 0
        pendingOutputDeviceID = deviceID
    }

    private func applyOutputDeviceChange(
        deviceID: AudioDeviceID,
        volumeAddress: AudioObjectPropertyAddress?,
        muteAddress: AudioObjectPropertyAddress?
    ) {
        outputDeviceProbeTask?.cancel()
        outputDeviceProbeTask = nil
        outputDeviceProbeAttempt = 0
        pendingOutputDeviceID = kAudioObjectUnknown

        removeDeviceListeners()
        outputDeviceID = deviceID
        volumePropertyAddress = volumeAddress
        mutePropertyAddress = muteAddress

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

    private func scheduleOutputDeviceProbeRetryIfNeeded(for deviceID: AudioDeviceID) {
        guard let delay = VolumeMonitorRefreshPlanner.retryDelay(attempt: outputDeviceProbeAttempt) else {
            applyOutputDeviceChange(
                deviceID: deviceID,
                volumeAddress: audioController.volumePropertyAddress(for: deviceID),
                muteAddress: audioController.mutePropertyAddress(for: deviceID)
            )
            scheduleStateRefresh()
            return
        }

        scheduleOutputDeviceProbeRetry(for: deviceID, delayMilliseconds: delay)
    }

    private func scheduleOutputDeviceProbeRetry(for deviceID: AudioDeviceID, delayMilliseconds: Int) {
        outputDeviceProbeTask?.cancel()
        pendingOutputDeviceID = deviceID
        outputDeviceProbeAttempt += 1
        outputDeviceProbeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(delayMilliseconds))
            guard Task.isCancelled == false else { return }

            await MainActor.run {
                guard let self, self.pendingOutputDeviceID == deviceID else { return }
                self.updateOutputDevice(force: true)
                self.scheduleStateRefresh()
            }
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

    func refreshStateForTesting() {
        refreshState()
    }

    func seedStateForTesting(_ state: VolumeState) {
        currentVolumeState = state
    }

    // MARK: - Property Getters

    private func getVolume() -> Float {
        guard let address = volumePropertyAddress else { return currentVolumeState.volume }
        return audioController.getVolume(deviceID: outputDeviceID, address: address) ?? currentVolumeState.volume
    }

    private func getMuteState() -> Bool {
        guard let address = mutePropertyAddress else { return currentVolumeState.isMuted }
        return audioController.getMute(deviceID: outputDeviceID, address: address) ?? currentVolumeState.isMuted
    }

    // MARK: - Callback

    private static let propertyCallback: AudioObjectPropertyListenerProc = { _, numAddresses, addresses, clientData in
        guard let clientData else { return noErr }

        let monitor = Unmanaged<VolumeMonitor>.fromOpaque(clientData).takeUnretainedValue()
        let selectors = (0 ..< Int(numAddresses)).map { addresses[$0].mSelector }
        let action = VolumeMonitorRefreshPlanner.callbackAction(selectors: selectors)

        Task { @MainActor in
            switch action {
            case .none:
                break

            case let .updateOutputDevice(force):
                monitor.updateOutputDevice(force: force)
            }

            monitor.scheduleStateRefresh()
        }
        return noErr
    }
}
