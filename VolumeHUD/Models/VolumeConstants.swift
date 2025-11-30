//
//  VolumeConstants.swift
//  VolumeHUD
//
//  Created by yu on 2025/11/30.
//

import Foundation

/// Constants for volume level calculations
enum VolumeConstants {
    /// Standard macOS volume levels (0.0 to 1.0)
    /// These are the actual values returned by the system when pressing volume up from mute
    /// Measured from actual system output to ensure accuracy
    static let standardVolumeLevels: [Float] = [
        0.0,
        0.063488126,
        0.12555026,
        0.18755038,
        0.2539525,
        0.3125426,
        0.37720877,
        0.43747285,
        0.502201,
        0.5595511,
        0.6200012,
        0.68355143,
        0.7502015,
        0.8057536,
        0.8779837,
        0.9379999,
        1.0
    ]
}
