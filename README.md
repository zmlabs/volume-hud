# Volume HUD

Bring back the classic volume feedback overlay to the center of your screen on macOS.

https://apps.apple.com/us/app/volume-hud/id6752903119

## Why This App Exists

After updating to macOS 26, the system volume feedback moved to the upper-right corner of the menu bar. This is completely unintuitive! When I'm working, my eyes are focused on the center of the screen, not looking up at the top-right corner. 

I much prefer the old macOS 10.15 style where the volume indicator appeared at the bottom center of the screen. That was so much better because:

- Your vision is naturally focused on the center of the screen
- You don't have to turn your head to see the volume level
- I like to adjust volume based on visual feedback, not just by listening

This change really disappointed me, so I spent two hours with Claude Code to write this application. I handled the code review and provided feedback, while Claude did the actual coding. The result is this app that brings back the centered volume display even on macOS 26 and later.

## What It Does

VolumeHUD shows a volume indicator in the center of your screen whenever you change the volume, just like the good old days. It has two styles:

- **macOS 10.15 Style**: The traditional volume display style
- **Liquid Glass Style**: The new macOS 26 visual design

The app runs in your menu bar and automatically shows the volume overlay whenever you adjust volume using keyboard keys, system controls, or any other method.

## Installation

**Build from Source**: Clone this repository and build with Xcode

That's it! Now when you change volume, you'll see the overlay in the center of your screen where it belongs.

## Settings

Click the menu bar icon to access settings where you can:

- Choose between macOS 10.15 and Liquid Glass display styles
- Set the app to launch automatically when you start your Mac
- Preview how each style looks

---

*Finally, volume feedback that makes sense again.*
