//
//  VolumeMonitor.swift
//  VolumeHUD
//
//  Created by yu on 2025/9/23.
//

import AudioToolbox
import Combine
import CoreAudio
import Foundation

/// A class that monitors system volume changes using Core Audio
class VolumeMonitor {
    static let shared = VolumeMonitor()

    /// Publisher that emits only when volume/mute changes (not device changes)
    let volumeChangePublisher = PassthroughSubject<VolumeState, Never>()

    /// Current volume state (includes all changes)
    private(set) var currentVolumeState = VolumeState() {
        didSet {
            // Always update state, but only publish for volume/mute changes
            if currentVolumeState.hasVolumeOrMuteChange(from: oldValue) {
                volumeChangePublisher.send(currentVolumeState)
            }
        }
    }

    private var defaultOutputDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private var activeVolumePropertyAddress: AudioObjectPropertyAddress?

    private var mainVolumePropertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    private var channel1VolumePropertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: 1
    )

    private var mutePropertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    private var isMonitoring = false

    init() {
        startMonitoring()
    }

    deinit {
        if isMonitoring {
            stopMonitoring()
        }
    }

    /// Start monitoring system volume changes
    private func startMonitoring() {
        guard !isMonitoring else { return }

        // Register for device changes
        registerForDeviceChanges()

        // Get the default output device
        updateDefaultOutputDevice()

        // Get initial volume state
        updateVolumeState()

        isMonitoring = true
    }

    /// Stop monitoring system volume changes
    private func stopMonitoring() {
        guard isMonitoring else { return }

        // Unregister all property listeners
        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            volumeChangeCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )

        removeVolumeAndMuteListeners()

        isMonitoring = false
    }

    /// Update the current default output device
    func updateDefaultOutputDevice() {
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let result = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )

        if result == noErr, deviceID != kAudioObjectUnknown {
            if defaultOutputDeviceID != deviceID {
                // Device changed, need to re-register for volume changes
                removeVolumeAndMuteListeners()

                defaultOutputDeviceID = deviceID
                registerForVolumeChanges()
            }
        }
    }

    /// Unregisters the active volume and mute property listeners from the current device.
    private func removeVolumeAndMuteListeners() {
        guard defaultOutputDeviceID != kAudioObjectUnknown else { return }
        print("Remove volume and mute listeners")

        if var activeAddress = activeVolumePropertyAddress {
            AudioObjectRemovePropertyListener(
                defaultOutputDeviceID,
                &activeAddress,
                volumeChangeCallback,
                Unmanaged.passUnretained(self).toOpaque()
            )
            activeVolumePropertyAddress = nil
        }

        AudioObjectRemovePropertyListener(
            defaultOutputDeviceID,
            &mutePropertyAddress,
            volumeChangeCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    /// Register for system audio device changes
    private func registerForDeviceChanges() {
        AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            volumeChangeCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    /// Register for volume and mute changes on the current device
    private func registerForVolumeChanges() {
        guard defaultOutputDeviceID != kAudioObjectUnknown else { return }

        if AudioObjectHasProperty(defaultOutputDeviceID, &mainVolumePropertyAddress) {
            print("✅ Using Main volume control")
            activeVolumePropertyAddress = mainVolumePropertyAddress
        } else if AudioObjectHasProperty(defaultOutputDeviceID, &channel1VolumePropertyAddress) {
            print("✅ Using Channel 1 volume control")
            activeVolumePropertyAddress = channel1VolumePropertyAddress
        } else {
            print("❌ No volume control available for this device.")
            activeVolumePropertyAddress = nil
        }

        // Check if the device supports volume control
        if hasVolumeControl(),
           var activeAddress = activeVolumePropertyAddress
        {
            AudioObjectAddPropertyListener(
                defaultOutputDeviceID,
                &activeAddress,
                volumeChangeCallback,
                Unmanaged.passUnretained(self).toOpaque()
            )
        }

        // Check if the device supports mute control
        if hasMuteControl() {
            AudioObjectAddPropertyListener(
                defaultOutputDeviceID,
                &mutePropertyAddress,
                volumeChangeCallback,
                Unmanaged.passUnretained(self).toOpaque()
            )
        }
    }

    /// Check if the current device has volume control
    private func hasVolumeControl() -> Bool {
        guard defaultOutputDeviceID != kAudioObjectUnknown else { return false }

        let mainHasVolumeControl = AudioObjectHasProperty(defaultOutputDeviceID, &mainVolumePropertyAddress)
        let channel1HasVolumeControl = AudioObjectHasProperty(defaultOutputDeviceID, &channel1VolumePropertyAddress)

        return mainHasVolumeControl || channel1HasVolumeControl
    }

    /// Check if the current device has mute control
    private func hasMuteControl() -> Bool {
        guard defaultOutputDeviceID != kAudioObjectUnknown else { return false }

        return AudioObjectHasProperty(defaultOutputDeviceID, &mutePropertyAddress)
    }

    /// Get the current system volume (0.0 to 1.0)
    private func getCurrentVolume() -> Float {
        guard var activeAddress = activeVolumePropertyAddress else { return 0.0 }

        var volume: Float32 = 0.0
        var dataSize = UInt32(MemoryLayout<Float32>.size)

        let result = AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &activeAddress,
            0,
            nil,
            &dataSize,
            &volume
        )

        return result == noErr ? Float(volume) : 0.0
    }

    /// Get the current mute state
    private func getCurrentMuteState() -> Bool {
        guard defaultOutputDeviceID != kAudioObjectUnknown, hasMuteControl() else { return false }

        var isMuted: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)

        let result = AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &mutePropertyAddress,
            0,
            nil,
            &dataSize,
            &isMuted
        )

        return result == noErr ? (isMuted != 0) : false
    }

    /// Update the volume state with current system values
    func updateVolumeState() {
        let newState = VolumeState(
            volume: getCurrentVolume(),
            isMuted: getCurrentMuteState(),
            outputDeviceID: defaultOutputDeviceID
        )

        // Only update if the state actually changed
        guard newState != currentVolumeState else { return }

        let isDeviceChange = newState.hasDeviceChange(from: currentVolumeState)
        currentVolumeState = newState

        // Simple logging
        if isDeviceChange {
            print("🔄 Device: \(defaultOutputDeviceID)")
        } else if newState.isMuted {
            print("🔇 Muted")
        } else {
            // Print exact float value for debugging
            print("🔊 Volume: \(newState.volume) (raw float)")
        }
    }
}

// MARK: - Core Audio Callback

/// Core Audio property change callback function
private func volumeChangeCallback(
    _: AudioObjectID,
    _ inNumberAddresses: UInt32,
    _ inAddresses: UnsafePointer<AudioObjectPropertyAddress>,
    _ inClientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData = inClientData else { return noErr }

    let volumeMonitor = Unmanaged<VolumeMonitor>.fromOpaque(clientData).takeUnretainedValue()

    // Check if it's a device change
    for i in 0 ..< inNumberAddresses {
        let address = inAddresses[Int(i)]

        if address.mSelector == kAudioHardwarePropertyDefaultOutputDevice {
            volumeMonitor.updateDefaultOutputDevice()
        }
    }

    // Update volume state regardless of which property changed
    volumeMonitor.updateVolumeState()

    return noErr
}
