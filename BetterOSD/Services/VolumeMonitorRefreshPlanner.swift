import CoreAudio
import Foundation

nonisolated enum VolumeMonitorCallbackAction: Equatable {
    case none
    case updateOutputDevice(force: Bool)
}

nonisolated enum VolumeMonitorProbeDecision: Equatable {
    case apply
    case retry(afterMilliseconds: Int)
    case acceptWithoutVolumeControl
    case skipUntilNextDeviceChange
}

nonisolated enum VolumeMonitorRefreshPlanner {
    private static let retryDelays = [250, 500, 1000]

    static func retryDelay(attempt: Int) -> Int? {
        guard retryDelays.indices.contains(attempt) else { return nil }
        return retryDelays[attempt]
    }

    static func callbackAction(selectors: [AudioObjectPropertySelector]) -> VolumeMonitorCallbackAction {
        let shouldUpdateDevice = selectors.contains(kAudioHardwarePropertyDefaultOutputDevice)
        let shouldRefreshDevice = selectors.contains(kAudioDevicePropertyStreamConfiguration)
            || selectors.contains(kAudioDevicePropertyDeviceIsAlive)

        guard shouldUpdateDevice || shouldRefreshDevice else {
            return .none
        }

        return .updateOutputDevice(force: shouldRefreshDevice)
    }

    static func probeDecision(
        isAlive: Bool,
        hasVolumeControl: Bool,
        attempt: Int
    ) -> VolumeMonitorProbeDecision {
        guard isAlive else {
            return .skipUntilNextDeviceChange
        }

        guard hasVolumeControl == false else {
            return .apply
        }

        guard let delay = retryDelay(attempt: attempt) else {
            return .acceptWithoutVolumeControl
        }

        return .retry(afterMilliseconds: delay)
    }
}
