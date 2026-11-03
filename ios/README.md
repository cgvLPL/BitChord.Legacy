# BitChord for iOS 15+

This directory contains the native Apple-platform implementation. The Android application at the repository root is intentionally unchanged.

## Compatibility target

- Minimum deployment target: iOS 15.0
- UI: SwiftUI APIs available on iOS 15
- Audio: AVFoundation
- Lock Screen / Control Centre metadata and transport: MediaPlayer

## Generate and open the Xcode project

Install Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen), then run:

```sh
cd ios
xcodegen generate
open BitChord.xcodeproj
```

Select the BitChord scheme and an iOS 15.0+ simulator or device.

## Current implementation status

The initial foundation includes:
- A native SwiftUI app shell with Library, Search, and Settings tabs.
- A reusable track model and sample library for UI development.
- An AVPlayer-backed playback manager.
- Background audio session configuration and Now Playing / remote transport command integration.
- A compact player and expanded now-playing screen.

This is a foundation, not a feature-complete port. YouTube Music catalog access, authentication, provider/module integration, lyrics synchronization, downloads, playlist persistence, and advanced audio processing still need to be implemented and tested independently. The supplied iOS 17+ IPA is a behavioral and visual reference; compiled IPA contents do not provide editable Swift source.

## Licensing

BitChord is GPL-3.0. Keep the upstream license and attribution notices with this project, and ensure any redistributed binaries are accompanied by the corresponding source as required by the license.
