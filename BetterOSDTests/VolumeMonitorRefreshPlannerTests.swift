import CoreAudio
import Testing
@testable import BetterOSD

struct VolumeMonitorRefreshPlannerTests {
    @Test
    func updatesOutputDeviceWhenDefaultOutputChanges() {
        let action = VolumeMonitorRefreshPlanner.callbackAction(
            selectors: [kAudioHardwarePropertyDefaultOutputDevice]
        )

        #expect(action == .updateOutputDevice(force: false))
    }

    @Test
    func forcesRefreshWhenDefaultOutputChangesWithDeviceSignals() {
        let action = VolumeMonitorRefreshPlanner.callbackAction(
            selectors: [kAudioHardwarePropertyDefaultOutputDevice, kAudioDevicePropertyDeviceIsAlive]
        )

        #expect(action == .updateOutputDevice(force: true))
    }

    @Test(arguments: [
        (0, VolumeMonitorProbeDecision.retry(afterMilliseconds: 250)),
        (1, VolumeMonitorProbeDecision.retry(afterMilliseconds: 500)),
        (2, VolumeMonitorProbeDecision.retry(afterMilliseconds: 1000)),
        (3, VolumeMonitorProbeDecision.acceptWithoutVolumeControl),
    ])
    func usesBackoffStrategyWhenVolumeControlIsUnavailable(
        attempt: Int,
        expected: VolumeMonitorProbeDecision
    ) {
        let decision = VolumeMonitorRefreshPlanner.probeDecision(
            isAlive: true,
            hasVolumeControl: false,
            attempt: attempt
        )

        #expect(decision == expected)
    }

    @Test
    func skipsRetriesForDeadDevices() {
        let decision = VolumeMonitorRefreshPlanner.probeDecision(
            isAlive: false,
            hasVolumeControl: false,
            attempt: 0
        )

        #expect(decision == .skipUntilNextDeviceChange)
    }
}
