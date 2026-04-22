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
    func channelVolumePropertyAddresses(for deviceID: AudioDeviceID) -> [AudioObjectPropertyAddress]
    func mutePropertyAddress(for deviceID: AudioDeviceID) -> AudioObjectPropertyAddress?
    func getVolume(deviceID: AudioDeviceID, address: AudioObjectPropertyAddress) -> Float?
    func getMute(deviceID: AudioDeviceID, address: AudioObjectPropertyAddress) -> Bool?
    func setVolume(_ volume: Float, deviceID: AudioDeviceID, address: AudioObjectPropertyAddress) -> Bool
    func setMute(_ muted: Bool, deviceID: AudioDeviceID, address: AudioObjectPropertyAddress) -> Bool
}

enum AudioDeviceVolumeControl {
    case master(AudioObjectPropertyAddress)
    case channels([AudioObjectPropertyAddress])

    var addresses: [AudioObjectPropertyAddress] {
        switch self {
        case let .master(address):
            [address]
        case let .channels(addresses):
            addresses
        }
    }
}

struct AudioDeviceVolumeSnapshot {
    let values: [Float]

    var displayVolume: Float {
        values.max() ?? 0
    }

    var hasAudibleVolume: Bool {
        values.contains(where: { $0 > 0 })
    }
}

extension SystemAudioControlling {
    func volumeControl(for deviceID: AudioDeviceID) -> AudioDeviceVolumeControl? {
        if let address = volumePropertyAddress(for: deviceID) {
            return .master(address)
        }

        let addresses = channelVolumePropertyAddresses(for: deviceID)
        guard addresses.isEmpty == false else { return nil }
        return .channels(addresses)
    }

    func readVolumeSnapshot(
        deviceID: AudioDeviceID,
        control: AudioDeviceVolumeControl
    ) -> AudioDeviceVolumeSnapshot? {
        let addresses = control.addresses
        let values = addresses.compactMap { getVolume(deviceID: deviceID, address: $0) }
        guard values.count == addresses.count else { return nil }
        return AudioDeviceVolumeSnapshot(values: values)
    }

    func projectedVolumeSnapshot(
        control: AudioDeviceVolumeControl,
        targetVolume: Float,
        from snapshot: AudioDeviceVolumeSnapshot?
    ) -> AudioDeviceVolumeSnapshot {
        let clampedVolume = max(0, min(1, targetVolume))

        switch control {
        case .master:
            return AudioDeviceVolumeSnapshot(values: [clampedVolume])

        case let .channels(addresses):
            guard addresses.isEmpty == false else {
                return AudioDeviceVolumeSnapshot(values: [])
            }

            if let snapshot, snapshot.values.count == addresses.count, snapshot.displayVolume > 0 {
                let scale = clampedVolume / snapshot.displayVolume
                return AudioDeviceVolumeSnapshot(
                    values: snapshot.values.map { max(0, min(1, $0 * scale)) }
                )
            }

            return AudioDeviceVolumeSnapshot(values: Array(repeating: clampedVolume, count: addresses.count))
        }
    }

    func setVolume(
        _ volume: Float,
        deviceID: AudioDeviceID,
        control: AudioDeviceVolumeControl,
        snapshot: AudioDeviceVolumeSnapshot?
    ) -> Bool {
        let projectedSnapshot = projectedVolumeSnapshot(
            control: control,
            targetVolume: volume,
            from: snapshot
        )
        return applyVolumeSnapshot(projectedSnapshot, deviceID: deviceID, control: control)
    }

    func restoreVolume(
        _ snapshot: AudioDeviceVolumeSnapshot,
        deviceID: AudioDeviceID,
        control: AudioDeviceVolumeControl
    ) -> Bool {
        applyVolumeSnapshot(snapshot, deviceID: deviceID, control: control)
    }

    func applyVolumeSnapshot(
        _ snapshot: AudioDeviceVolumeSnapshot,
        deviceID: AudioDeviceID,
        control: AudioDeviceVolumeControl
    ) -> Bool {
        switch control {
        case let .master(address):
            guard let value = snapshot.values.first else { return false }
            return setVolume(value, deviceID: deviceID, address: address)

        case let .channels(addresses):
            guard addresses.isEmpty == false else { return false }

            let values: [Float]
            if snapshot.values.count == addresses.count {
                values = snapshot.values
            } else {
                values = Array(repeating: snapshot.displayVolume, count: addresses.count)
            }

            let currentValues = addresses.compactMap { getVolume(deviceID: deviceID, address: $0) }
            guard currentValues.count == addresses.count else { return false }

            var appliedWrites: [(AudioObjectPropertyAddress, Float)] = []
            for ((address, value), previousValue) in zip(zip(addresses, values), currentValues) {
                guard setVolume(value, deviceID: deviceID, address: address) else {
                    for (writtenAddress, writtenValue) in appliedWrites.reversed() {
                        _ = setVolume(writtenValue, deviceID: deviceID, address: writtenAddress)
                    }
                    return false
                }
                appliedWrites.append((address, previousValue))
            }
            return true
        }
    }
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
        return nil
    }

    func channelVolumePropertyAddresses(for deviceID: AudioDeviceID) -> [AudioObjectPropertyAddress] {
        guard let outputChannelCount = outputChannelCount(for: deviceID), outputChannelCount > 0 else {
            return []
        }

        return (1 ... outputChannelCount).compactMap { element in
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: AudioObjectPropertyElement(element)
            )
            return AudioObjectHasProperty(deviceID, &address) ? address : nil
        }
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

    private func outputChannelCount(for deviceID: AudioDeviceID) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0

        let sizeStatus = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
        guard sizeStatus == noErr, size > 0 else { return nil }

        let rawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawPointer.deallocate() }

        let bufferListPointer = rawPointer.assumingMemoryBound(to: AudioBufferList.self)
        let dataStatus = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &size,
            bufferListPointer
        )
        guard dataStatus == noErr else { return nil }

        let buffers = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        return buffers.reduce(UInt32(0)) { partialResult, buffer in
            partialResult + buffer.mNumberChannels
        }
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
