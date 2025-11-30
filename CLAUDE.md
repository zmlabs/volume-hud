# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

**Building the Project:**
```bash
# Build from command line
xcodebuild -project VolumeHUD.xcodeproj -scheme VolumeHUD -configuration Debug build
xcodebuild -project VolumeHUD.xcodeproj -scheme VolumeHUD -configuration Release build

# Alternative: Use -target instead of -scheme
xcodebuild -project VolumeHUD.xcodeproj -target VolumeHUD -configuration Release build
```

**Opening in Xcode:**
```bash
open VolumeHUD.xcodeproj
```

**Running the App:**
- Build and run through Xcode (⌘R)
- The app will appear in your menu bar and show volume overlay when you adjust system volume

## Architecture Overview

VolumeHUD is a macOS menu bar application that displays a centered volume overlay when system volume changes. The app uses a classic MVC pattern with Core Audio integration.

### Core Components

**Application Structure:**
- `VolumeHUDApp.swift`: Entry point using custom `@main` struct
- `AppDelegate.swift`: Manages menu bar, settings window, and app lifecycle
- Menu bar integration with optional visibility (controlled via `showInMenuBar` setting)

**Volume Monitoring:**
- `VolumeMonitor.swift`: Singleton service that monitors Core Audio system volume changes
- Uses Core Audio framework's property listeners for real-time volume/mute detection
- Handles device switching and automatically re-registers listeners
- Publishes volume changes via Combine publishers

**Window Management:**
- `VolumeHUDWindowManager.swift`: Coordinates HUD display timing and lifecycle
- `VolumeHUDWindow.swift`: Custom `NSPanel` that displays overlay at bottom-center of screen
- Auto-hides after 2.5 seconds with smooth fade animations
- Floating panel that doesn't steal focus or respond to mouse events

**UI System:**
- `VolumeHUDFactoryView.swift`: SwiftUI factory that switches between styles based on user preference
- `ClassicVolumeHUDView.swift`: macOS 10.15-style volume display
- `ModernVolumeHUDView.swift`: Modern "Liquid Glass" style display
- `SettingsView.swift`: SwiftUI settings interface accessible via menu bar

**Data Models:**
- `VolumeState.swift`: Represents current volume state (0.0-1.0, mute status, device ID)
- `HUDStyle.swift`: Enum defining available display styles (Classic/Modern)
- Uses `@AppStorage` for persisting user preferences

### Key Technical Details

**Core Audio Integration:**
- Monitors `kAudioHardwarePropertyDefaultOutputDevice` for device changes
- Listens to `kAudioDevicePropertyVolumeScalar` for volume changes
- Supports both main channel and channel 1 volume controls
- Handles `kAudioDevicePropertyMute` for mute state

**Window Behavior:**
- `NSPanel` with `.nonactivatingPanel` style mask
- `.statusBar` window level to appear above most apps
- Positioned at bottom-center of main screen (120px from bottom)
- 280x200 point window size with transparent background

**State Management:**
- Combine-based reactive architecture
- `VolumeMonitor` publishes changes only for volume/mute, not device switches
- Automatic cleanup of Core Audio listeners on device changes
- Debounced display logic prevents flickering

**Settings Storage:**
- UserDefaults via `@AppStorage` properties:
  - `hudStyle`: "classic" or "modern"
  - `launchAtLogin`: Auto-start preference
  - `showInMenuBar`: Menu bar icon visibility

### File Organization

```
VolumeHUD/
├── Models/
│   ├── VolumeState.swift      # Volume state data model
│   └── HUDStyle.swift          # Style enum and app storage keys
├── Services/
│   └── VolumeMonitor.swift     # Core Audio integration
├── Windows/
│   ├── VolumeHUDWindowManager.swift  # HUD display coordination
│   └── VolumeHUDWindow.swift          # Custom window implementation
├── Views/
│   ├── HUD/
│   │   ├── ClassicVolumeHUDView.swift    # Classic style UI
│   │   ├── ModernVolumeHUDView.swift     # Modern style UI
│   │   └── VolumeHUDFactoryView.swift   # Style switching logic
│   └── SettingsView.swift               # Settings interface
├── VolumeHUDApp.swift               # App entry point
└── AppDelegate.swift                # App lifecycle and menu bar
```

### Development Notes

- The app uses manual memory management for Core Audio callbacks (Unmanaged.passUnretained)
- All volume monitoring happens on background threads, UI updates are dispatched to main thread
- The app is designed to be lightweight and only shows the HUD when volume actually changes
- No test suite is currently present in the project