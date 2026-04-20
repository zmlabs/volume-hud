//
//  VolumeMonitor.swift
//  BetterOSD
//
//  Created by yu on 2025/9/23.
//

import CoreAudio
import Foundation

final class VolumeMonitor {
    static let shared = VolumeMonitor()

    private let audioController: SystemAudioControlling
    private static let debounceInterval: TimeInterval = 0.05
    private var lastPushedDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var outputDeviceID: AudioDeviceID = kAudioObjectUnknown
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
        initialOutputDeviceID: AudioDeviceID = kAudioObjectUnknown
    ) {
        self.audioController = audioController
        outputDeviceID = initialOutputDeviceID
    }

    func start() {
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

        let hasVolumeControl = audioController.volumePropertyAddress(for: deviceID) != nil
        let decision = VolumeMonitorRefreshPlanner.probeDecision(
            isAlive: true,
            hasVolumeControl: hasVolumeControl,
            attempt: outputDeviceProbeAttempt
        )

        switch decision {
        case .apply, .acceptWithoutVolumeControl:
            applyOutputDeviceChange(deviceID: deviceID)

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

    private func applyOutputDeviceChange(deviceID: AudioDeviceID) {
        outputDeviceProbeTask?.cancel()
        outputDeviceProbeTask = nil
        outputDeviceProbeAttempt = 0
        pendingOutputDeviceID = kAudioObjectUnknown

        removeDeviceListeners()
        outputDeviceID = deviceID

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
            applyOutputDeviceChange(deviceID: deviceID)
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
        let newDeviceID = outputDeviceID
        guard newDeviceID != lastPushedDeviceID else { return }
        let previousDeviceID = lastPushedDeviceID
        lastPushedDeviceID = newDeviceID
        let isInitialDiscovery = previousDeviceID == kAudioObjectUnknown
        guard !isInitialDiscovery, newDeviceID != kAudioObjectUnknown else { return }
        let state = VolumeState.read(deviceID: newDeviceID, from: audioController)
        HUDDisplayStateStore.shared.update(state.displayState)
    }

    func refreshStateForTesting() {
        refreshState()
    }

    func seedOutputDeviceIDForTesting(_ deviceID: AudioDeviceID) {
        lastPushedDeviceID = deviceID
    }

    func switchOutputDeviceForTesting(to deviceID: AudioDeviceID) {
        outputDeviceID = deviceID
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
