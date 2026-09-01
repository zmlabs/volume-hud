//
//  VolumeFeedbackSoundPlayer.swift
//  BetterOSD
//
//  Replays the classic "volume changed" click. macOS only plays it on its own
//  media-key handling path — the same path the event tap replaces when the
//  HUD consumes the key — so without this the feedback sound disappears
//  whenever BetterOSD is running.
//
//  The sound is BezelServices' own volume.aiff (the one the system OSD plays),
//  registered as a system sound so every keypress retriggers it immediately,
//  at the current output volume — just like the real thing.
//

import AppKit
import AudioToolbox
import Foundation

protocol VolumeFeedbackPlaying: AnyObject {
    /// `invert` mirrors the classic Shift-key trick: temporarily flip the
    /// system "Play feedback when volume is changed" setting for this press.
    func playVolumeFeedback(invert: Bool)
}

final class VolumeFeedbackSoundPlayer: VolumeFeedbackPlaying {
    static let shared = VolumeFeedbackSoundPlayer()

    private static let systemSoundURL = URL(
        fileURLWithPath:
            "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff"
    )

    private let preferences: UserDefaults
    private var systemSoundID: SystemSoundID?
    private let fallbackSound = NSSound(named: NSSound.Name("Pop"))

    init(preferences: UserDefaults = UserDefaults(suiteName: ".GlobalPreferences") ?? .standard) {
        self.preferences = preferences
    }

    deinit {
        if let systemSoundID {
            AudioServicesDisposeSystemSoundID(systemSoundID)
        }
    }

    func playVolumeFeedback(invert: Bool) {
        // Mirrors System Settings → Sound → "Play feedback when volume is
        // changed". Unset means on, which is the macOS default.
        let settingEnabled = preferences.object(forKey: "com.apple.sound.beep.feedback") as? Bool ?? true
        guard settingEnabled != invert else { return }
        loadSystemSound()
        if let systemSoundID {
            AudioServicesPlaySystemSound(systemSoundID)
        } else {
            fallbackSound?.play()
        }
    }

    private func loadSystemSound() {
        guard systemSoundID == nil else { return }
        var soundID = SystemSoundID(0)
        guard AudioServicesCreateSystemSoundID(Self.systemSoundURL as CFURL, &soundID) == noErr else {
            return
        }
        systemSoundID = soundID
    }
}
