//
//  FakeVolumeFeedbackPlayer.swift
//  BetterOSDTests
//

@testable import BetterOSD

@MainActor
final class FakeVolumeFeedbackPlayer: VolumeFeedbackPlaying {
    private(set) var playCount = 0
    private(set) var lastInvert: Bool?

    func playVolumeFeedback(invert: Bool) {
        playCount += 1
        lastInvert = invert
    }
}
