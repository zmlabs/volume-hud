//
//  VolumeCalculation.swift
//  BetterOSD
//
//  Created by yu on 2025/12/26.
//

import Foundation

/// Utilities for volume level calculations
/// macOS uses 64 fine steps (Shift+Option+Volume) and 16 standard steps
enum VolumeCalculation {
    /// Total fine steps macOS uses (1/64 = 0.015625 each)
    static let fineSteps = 64
    /// Total standard steps (16 segments, 17 tick marks)
    static let standardSteps = 16
    /// Fine steps per standard step (64 / 16 = 4)
    static let fineStepsPerStandardStep = fineSteps / standardSteps

    /// Convert volume (0.0-1.0) to 64-step index
    /// Handles floating point precision issues by rounding
    static func volumeToFineStep(_ volume: Float) -> Int {
        Int(round(volume * Float(fineSteps)))
    }

    /// Check if a tick (0-16) should be active for the given volume
    static func isTickActive(tickIndex: Int, volume: Float) -> Bool {
        let volumeStep = volumeToFineStep(volume)
        let tickStep = tickIndex * fineStepsPerStandardStep
        return volumeStep >= tickStep
    }

    /// Calculate fill ratio (0.0-1.0) for a segment (0-15) given the volume
    /// Returns 1.0 if fully filled, 0.0-1.0 if partially filled, 0.0 if empty
    static func segmentFillRatio(segmentIndex: Int, volume: Float) -> CGFloat {
        let volumeStep = volumeToFineStep(volume)
        let segmentStartStep = segmentIndex * fineStepsPerStandardStep
        let segmentEndStep = (segmentIndex + 1) * fineStepsPerStandardStep

        if volumeStep >= segmentEndStep {
            return 1.0
        } else if volumeStep > segmentStartStep {
            let stepsInSegment = volumeStep - segmentStartStep
            return CGFloat(stepsInSegment) / CGFloat(fineStepsPerStandardStep)
        } else {
            return 0.0
        }
    }
}
