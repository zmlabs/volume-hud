//
//  FakeVolumeFeedbackPlayer.swift
//  BetterOSDTests
//

@testable import BetterOSD

@MainActor
final class FakeVolumeFeedbackPlayer: VolumeFeedbackPlaying {
    private(set) var playCount = 0

    func playVolumeFeedback() {
        playCount += 1
    }
}
