import CoreAudio
import Testing
@testable import BetterOSD

@MainActor
struct VolumeMonitorStateFallbackTests {
    @Test
    func retainsPreviousVolumeAndMuteWhenAudioReadsFail() {
        let fakeController = FakeSystemAudioController()
        let monitor = VolumeMonitor(
            audioController: fakeController,
            autoStart: false,
            initialOutputDeviceID: 42,
            initialVolumePropertyAddress: makeVolumeAddress(),
            initialMutePropertyAddress: makeMuteAddress()
        )

        fakeController.volume = 0.6
        fakeController.isMuted = true
        monitor.refreshStateForTesting()

        #expect(monitor.currentVolumeState == VolumeState(volume: 0.6, isMuted: true, outputDeviceID: 42))

        fakeController.volume = nil
        fakeController.isMuted = nil
        monitor.refreshStateForTesting()

        #expect(monitor.currentVolumeState == VolumeState(volume: 0.6, isMuted: true, outputDeviceID: 42))
    }

    @Test
    func retainsPreviousStateWhenPropertyAddressesAreMissing() {
        let fakeController = FakeSystemAudioController()
        let monitor = VolumeMonitor(
            audioController: fakeController,
            autoStart: false,
            initialOutputDeviceID: 42
        )

        let previousState = VolumeState(volume: 0.3, isMuted: false, outputDeviceID: 42)
        monitor.seedStateForTesting(previousState)
        monitor.refreshStateForTesting()

        #expect(monitor.currentVolumeState == previousState)
    }

    @Test
    func appliesPendingDeviceAfterProbeRetriesAreExhausted() async {
        let fakeController = FakeSystemAudioController()
        fakeController.defaultDeviceID = 84
        fakeController.deviceAlive = false

        let monitor = VolumeMonitor(
            audioController: fakeController,
            autoStart: false,
            initialOutputDeviceID: 42
        )

        let previousState = VolumeState(volume: 0.3, isMuted: false, outputDeviceID: 42)
        monitor.seedStateForTesting(previousState)

        monitor.updateOutputDevice()
        await waitUntil {
            monitor.currentVolumeState.outputDeviceID == 84
        }

        #expect(monitor.currentVolumeState == VolumeState(volume: 0.3, isMuted: false, outputDeviceID: 84))
    }

    private func makeVolumeAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func makeMuteAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func waitUntil(
        timeout: Duration = .seconds(3),
        pollingInterval: Duration = .milliseconds(50),
        condition: @escaping () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout

        while condition() == false, clock.now < deadline {
            try? await Task.sleep(for: pollingInterval)
        }
    }
}
